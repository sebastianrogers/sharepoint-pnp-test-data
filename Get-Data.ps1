<#
.SYNOPSIS
Gets data from a SharePoint list
Connect to the SharePoint Site first.

.EXAMPLE
Export the Action Definitions from a demo site.

-Url:http://simpleinnovation.sharepoint.com/sites/demo -List:'Action Definitions' -Fields:'Title', 'ID' -Path:'.\temp\Action Definitions.csv'

#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # The URL of the site collection to get the lists data from
    [Parameter(Mandatory)][string]$URL,

    # The title of the list to get the data from
    [Parameter(Mandatory)][string]$List,

    # The fields in the list to get the data from
    [Parameter(Mandatory)][array]$Fields,

    # The CSV file to write the data to
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

Import-Module -Name:./TestData.psm1

Get-Data `
    -URL:$URL `
    -List:$List `
    -Fields:$Fields `
    -Path:$Path
