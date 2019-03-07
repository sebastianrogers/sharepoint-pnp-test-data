<#
.SYNOPSIS
Installs explicit list items from a CSV file

.EXAMPLE
Install to a demo site.

.\Install-Data.ps1 -URL:https://simpleinnovation.sharepoint.com/sites/Demo -Path:.\data\demo

#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # The URL of the site collection to install the Correspondence Mangement App into
    [Parameter(Mandatory)][string]$URL,

    # The folder containing the data to import
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

Write-Host -Object:@"
In order to update the application data you require the following:

1. An existing Site Collection
2. Any lists that will have items imported into them.
2. An account with Contributor permissions.

This installation package uses the PnP Provisioning library and is designed to be run from a client workstation.

If running from a SharePoint server then the Loopback Check must be disabled.
"@

function Import-Data() {
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

    Write-Information -MessageData:"Importing data from the $Path file."

    @($(Import-Csv -Path:$Path)).ForEach( {
            if ($Count % 100 -eq 0) {
                Write-Verbose -Message:"Reconnecting to SharePoint"
                Connect-PnPOnline -Url:$Url
            }

            $Count++
        
            $ContentType = $null
            $ListName = $null
            $Key = "Title"
            $IDName = [string]::Empty

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
                            if ($Value) {
                                switch ($Value) {
                                    "[ID]" {
                                        $IDName = $Name    
                                    }
                                    default {
                                        $Values[$Name] = $Value 
                                    }
                                }
                            }
                        }
                    }

                    $Field = $Fields[$Name]
                    if (-not $Field) {
                        Write-Verbose -Message:"Getting the $Name field definition for the $ListName list."

                        $Field = Get-PnPField `
                            -Identity:$Name
                        $Fields[$Name] = $Field
                    }

                    switch ($Field.TypeAsString) {
                        "Lookup" {
                            if ($Value) {
                                $LookupItem = Get-PnPListItem `
                                    -List:$Field.LookupList `
                                    -Query:"<View><Query><Where><Eq><FieldRef Name='$($Field.LookupField)'/><Value Type='Text'>$Value</Value></Eq></Where></Query></View>" `
        
                                $Values[$Name] = $LookupItem.ID
                            }
                        }
                    }
                })

            $KeyValue = $Values[$Key]

            # $Values.Keys | ForEach-Object {
            #     Write-Verbose $Values[$PSItem]
            # }

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

Connect-PnPOnline -Url:$URL

Write-Host "Started importing data at $(Get-Date)."

Write-Host -Object:'Importing the data'
Get-ChildItem -Path:"$Path\*.csv" |
    Where-Object { $PSItem } |
    ForEach-Object {
    $File = $PSItem

    Write-Host "Importing data from the $($File.FullName) file."

    Import-Data -Path:$File.FullName -Url:$URL
}

Write-Host "Finished importing data at $(Get-Date)."