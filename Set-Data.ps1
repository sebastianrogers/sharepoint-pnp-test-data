<#
.SYNOPSIS
Installs the list items from a csv file

.EXAMPLE
Install to the demo site.

.\set-Data.ps1 -URL:https://<tenant>.sharepoint.com/sites/Demo -Path:.\data\demo

#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # The URL of the site collection to install the Correspondence Mangement App into
    [Parameter(Mandatory)][string]$URL,

    # The folder containing the data to import
    [Parameter(Mandatory)][string]$Path,

    [Parameter()][string]$File
)

$ErrorActionPreference = 'stop'
$InformationPreference = 'Continue'

if ($VerbosePreference -eq 'Continue') {
    Set-PnPTraceLog -On -Level:Debug
}
else {
    Set-PnPTraceLog -Off
}

Write-Host -Object:@"
In order to update the application data you require the following:

1. An existing Site Collection
2. The list need to exist
3. An account with contributor permissions.

This installation package uses the PnP Provisioning library and is designed to be run from a client workstation.

If running from a SharePoint server then the Loopback Check must be disabled.
"@



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
            $ClientContext = $SPClient.ClientContext,
            [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
            [Microsoft.SharePoint.Client.Field]
            $ClientObject
        )
    
        process {
            if ($ClientContext -eq $null) {
                throw "Cannot bind argument to parameter 'ClientContext' because it is null."
            }
            $Table = @{
                Text = 'Microsoft.SharePoint.Client.FieldText'
                Note = 'Microsoft.SharePoint.Client.FieldMultilineText'
                Choice = 'Microsoft.SharePoint.Client.FieldChoice'
                MultiChoice = 'Microsoft.SharePoint.Client.FieldMultiChoice'
                Number = 'Microsoft.SharePoint.Client.FieldNumber'
                Currency = 'Microsoft.SharePoint.Client.FieldCurrency'
                DateTime = 'Microsoft.SharePoint.Client.FieldDateTime'
                Lookup = 'Microsoft.SharePoint.Client.FieldLookup'
                LookupMulti = 'Microsoft.SharePoint.Client.FieldLookup'
                Boolean = 'Microsoft.SharePoint.Client.FieldNumber'
                User = 'Microsoft.SharePoint.Client.FieldUser'
                UserMulti = 'Microsoft.SharePoint.Client.FieldUser'
                Url = 'Microsoft.SharePoint.Client.FieldUrl'
                Calculated = 'Microsoft.SharePoint.Client.FieldCalculated'
            }
            $Method = $ClientContext.GetType().GetMethod('CastTo')
            $Method = $Method.MakeGenericMethod([type[]]$Table[$ClientObject.TypeAsString])
            return $Method.Invoke($ClientContext, @($ClientObject))
        }
    
    }

function set-Data() {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The path to the CSV file containing the data
        [Parameter(Mandatory)][string]$Path,

        [Parameter(Mandatory)]
        [string]
        $Url       
    )

    [int]$Count = 0
    $Fields = @{}

    @($(Import-Csv -Path:$Path)).ForEach( {
            if ($Count % 100 -eq 0) {
                Write-Verbose -Message:"Reconnecting to SharePoint"
                Connect-PnPOnline -Url:$Url -UseWebLogin
            }

            $Count++
        
            $ContentType = $null
            $ListName = $null
            $Key = "Title"
            $IDName = [string]::Empty
            $Context = Get-PnPContext

            $Values = @{}
            $PSItem.PSObject.Properties.ForEach( {

                    $Name = $PSItem.Name
                    $Value = $PSItem.Value

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
                                
                                $Context.Load($Field)
                                Execute-PnPQuery    
                                
                                $Fields[$Name] = $Field
                            }

                            switch ($Field.TypeAsString) {
                                "DateTime"{
                                    #Date has to be in US format for this to work.
                                    $Values[$Name] = $Value
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
                                        return;
                                    }
                                }
                                "LookupMulti"{
                                    if ($Value) {
                                        $LookupField = Convert-SPClientField -ClientContext:$Context -ClientObject:$Field
                                        $ids = $Value.Split(",") | 
                                        ForEach-Object {
                                            return Get-PnPListItem `
                                            -List:$LookupField.LookupList `
                                            -Query:"<View><Query><Where><Eq><FieldRef Name='$($LookupField.LookupField)'/><Value Type='Text'>$PSItem</Value></Eq></Where></Query></View>" `
                                        }.join(",")

                                        $Values[$Name] = $ids
                                        return;
                                    }
                                }
                                default{
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

            $KeyValue = $Values[$Key]

          
             $Values.Keys | ForEach-Object {
                 Write-Verbose $Values[$PSItem]
             }

            if ($PSCmdlet.ShouldProcess($ListName, 'Add')) {
                $ListItem = Get-PnPListItem `
                    -List:$ListName `
                    -Query:"<View><Query><Where><Eq><FieldRef Name='$Key'/><Value Type='Text'>$KeyValue</Value></Eq></Where></Query></View>"

                if ($ListItem) {
                    Write-Verbose "Updating the $KeyValue item to the $ListName list."
                    Set-PnPListItem -List:$ListName -Identity:$ListItem -ContentType:$ContentType -Values:$Values | Out-Null
                }
                else {
                    Write-Verbose "Adding the $KeyValue item to the $ListName list."
                    $ListItem = Add-PnPListItem -List:$ListName -ContentType:$ContentType -Values:$Values
                }

                if ($IDName) {
                    $IDValue = $ListItem.ID
                    Write-Verbose "Updating the $IDName column with $IDValue the list item's ID."
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

Connect-PnPOnline -Url:$URL -UseWebLogin

Write-Host "Started updating data."

Write-Host -Object:'Importing the data'
Get-ChildItem -Path:"$Path\*.csv" |
    Where-Object { $PSItem } |
    ForEach-Object {
    $FolderFile = $PSItem

    if(![string]::IsNullOrEmpty($File)){
        if($File -eq $FolderFile.Name){
             Write-Host "Importing data from the $($FolderFile.FullName) file."

            set-Data -Path:$FolderFile.FullName -Url:$URL
        }
    }
    else
    {
         Write-Host "Importing data from the $($FolderFile.FullName) file."

         set-Data -Path:$FolderFile.FullName -Url:$URL
    }   
}

Write-Host "Finished uploading Data at $(Get-Date)."
