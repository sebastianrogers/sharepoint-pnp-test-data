<#
.SYNOPSIS
Installs the list items from a csv file
Connect to the Site First.

.EXAMPLE
Install to the demo site.

.\Set-Data.ps1 -Path:.\examples\example.csv

#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # The path expression containing the data files import
    [Parameter(Mandatory)][string]$Path
)

$ErrorActionPreference = 'stop'
$InformationPreference = 'Continue'

if ($VerbosePreference -eq 'Continue') {
    Set-PnPTraceLog -On -Level:Debug
}
else {
    Set-PnPTraceLog -Off
}

function Convert-SPClientField() {

    <# 
    .SYNOPSIS 
      Casts a specified field to its derived type. 
    .PARAMETER ClientContext 
      Indicates the client context. 
      If not specified, uses the default context. 
    .PARAMETER ClientObject 
      Indicates the field. 
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [Microsoft.SharePoint.Client.ClientContext]
        $ClientContext,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Microsoft.SharePoint.Client.Field]
        $ClientObject
    )
    
    process {
        Write-Host $ClientContext
        if ($ClientContext -eq $null) {
            throw "Cannot bind argument to parameter 'ClientContext' because it is null."
        }
        $Table = @{
            Text        = 'Microsoft.SharePoint.Client.FieldText'
            Note        = 'Microsoft.SharePoint.Client.FieldMultilineText'
            Choice      = 'Microsoft.SharePoint.Client.FieldChoice'
            MultiChoice = 'Microsoft.SharePoint.Client.FieldMultiChoice'
            Number      = 'Microsoft.SharePoint.Client.FieldNumber'
            Currency    = 'Microsoft.SharePoint.Client.FieldCurrency'
            DateTime    = 'Microsoft.SharePoint.Client.FieldDateTime'
            Lookup      = 'Microsoft.SharePoint.Client.FieldLookup'
            LookupMulti = 'Microsoft.SharePoint.Client.FieldLookup'
            Boolean     = 'Microsoft.SharePoint.Client.FieldNumber'
            User        = 'Microsoft.SharePoint.Client.FieldUser'
            UserMulti   = 'Microsoft.SharePoint.Client.FieldUser'
            Url         = 'Microsoft.SharePoint.Client.FieldUrl'
            Calculated  = 'Microsoft.SharePoint.Client.FieldCalculated'
        }
        $Method = $ClientContext.GetType().GetMethod('CastTo')
        $Method = $Method.MakeGenericMethod([type[]]$Table[$ClientObject.TypeAsString])
        return $Method.Invoke($ClientContext, @($ClientObject))
    }
    
}

function Set-Data() {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The path to the CSV file containing the data
        [Parameter(Mandatory)][string]$Path
    )

    $Url = (Get-PnPWeb).Url
    [int]$Count = 0
    $Fields = @{ }

    @($(Import-Csv -Path:$Path)).ForEach( {
            if ($Count % 1000 -eq 0) {
                Write-Verbose -Message:"Reconnecting to SharePoint"
                Connect-PnPOnline -Url:$Url -UseWebLogin
            }

            $Count++
        
            $ContentType = $null
            $ListName = $null
            $Key = $null
            $IDName = [string]::Empty
            $Context = Get-PnPContext

            $Values = @{ }
            $PSItem.PSObject.Properties.ForEach( {

                    $Name = $PSItem.Name
                    $Value = $PSItem.Value

                    Write-Verbose "$Name : $Value"

                    switch ($Name) {
                        "ContentType" {
                            $ContentType = $Value
                        }
                        "Key" {
                            $Key = $Value
                        }
                        "List" {
                            $ListName = $Value
                        }
                        "Listname" {
                            $Name = "List"
                            $ListName = $Value
                        }
                        default {
                            $Field = $Fields[$Name]
                            if (-not $Field) {
                                Write-Verbose -Message:"Getting the $Name field definition for the $ListName list."

                                $Field = Get-PnPField `
                                    -List:$ListName `
                                    -Identity:$Name
                                
                                if (-not $Field) {
                                    Write-Error "Cannot get the $Name field in the $ListName list."
                                }
                                
                                $Context.Load($Field)
                                Invoke-PnPQuery    
                                
                                $Fields[$Name] = $Field
                            }

                            switch ($Field.TypeAsString) {
                                "DateTime" {
                                    if ([String]::IsNullOrEmpty($Value)) {
                                        return
                                    }

                                    # Date has to be in US format or ISO for this to work. Cannot be null
                                    $Values[$Name] = Get-Date -Date:$Value -Format:O
                                }
                                "Lookup" {
                                    if ($Value) {
                                        $LookupField = Convert-SPClientField -ClientContext:$Context -ClientObject:$Field
                                        #Convert to Microsoft.SharePoint.Client.FieldLookup
                                        Write-Host $LookupField.LookupList "-" $Value "-" $LookupField.LookupField
                                       
                                        $LookupItem = Get-PnPListItem `
                                            -List:$LookupField.LookupList `
                                            -Query:"<View><Query><Where><Eq><FieldRef Name='$($LookupField.LookupField)'/><Value Type='Text'>$Value</Value></Eq></Where></Query></View>" `
        
                                        $Values[$Name] = $LookupItem.ID
                                       
                                    }
                                }
                                "LookupMulti" {
                                    if ($Value) {
                                        $LookupField = Convert-SPClientField -ClientContext:$Context -ClientObject:$Field
                                        $ids = $Value.Split(";") | 
                                        ForEach-Object {
                                            (Get-PnPListItem `
                                                    -List:$LookupField.LookupList `
                                                    -Query:"<View><Query><Where><Eq><FieldRef Name='$($LookupField.LookupField)'/><Value Type='Text'>$($_.Trim())</Value></Eq></Where></Query></View>").ID
                                        }

                                        $Values[$Name] = $ids -join ','
                                       
                                    }
                                }
                                default {
                                    if ($Value) {
                                        switch ($Value) {
                                            "[ID]" {
                                                $IDName = $Name    
                                            }
                                            default {
                                                $Values[$Name] = $Value -replace '{site}', $URL
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                })

            $KeyValue = if ($Key) { $Values[$Key] } else { $null }

            $Values.Keys | ForEach-Object {
                Write-Verbose "$PSItem = $($Values[$PSItem])"
            }

            if ($PSCmdlet.ShouldProcess($ListName, 'Add')) {
                $ListItem = $null
               
                if ($KeyValue) {
                    $ListItem = Get-PnPListItem `
                        -List:$ListName `
                        -Query:"<View><Query><Where><Eq><FieldRef Name='$Key'/><Value Type='Text'>$KeyValue</Value></Eq></Where></Query></View>"
                }
               
                if ($ListItem) {
                    Write-Information "Updating the $KeyValue item to the $ListName list."
                    Set-PnPListItem -List:$ListName -Identity:$ListItem -ContentType:$ContentType -Values:$Values | Out-Null
                }
                else {
                    Write-Verbose "Adding the $KeyValue item to the $ListName list."
                    $ListItem = Add-PnPListItem -List:$ListName -ContentType:$ContentType -Values:$Values
                }

                if ($IDName) {
                    $IDValue = $ListItem.ID
                    Write-Information "Updating the $IDName column with $IDValue the list item's ID."
                    Set-PnPListItem `
                        -List:$ListName `
                        -Identity:$ListItem `
                        -ContentType:$ContentType `
                        -Values:@{
                        $IDName = $IDValue
                    }
                }
            }
        })
}

Write-Host "Started updating data."

Write-Host -Object:'Importing the data'
Get-ChildItem -Path:$Path |
Where-Object { $PSItem } |
ForEach-Object {
    $FolderFile = $PSItem

    Write-Host "Importing data from the $($FolderFile.FullName) file."
    Set-Data -Path:$FolderFile.FullName
}

Write-Host "Finished uploading Data at $(Get-Date)."
