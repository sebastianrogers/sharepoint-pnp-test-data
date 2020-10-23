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
    # The title of the list to get the data from
    [Parameter(Mandatory)][string]$Identity,

    # The fields in the list to get the data from
    [string[]]$Fields = @(),

    # The maximum number of results to process as a batch
    [int]$PageSize
)

$ErrorActionPreference = 'stop'
$InformationPreference = 'Continue'

if ($VerbosePreference -eq 'Continue') {
    Set-PnPTraceLog -On -Level:Debug
}
else {
    Set-PnPTraceLog -Off
}

Import-Module -Name:./SharePointPnPTestData.psm1 -Force

if ($Fields.Length -eq 0) {
    $Fields = Get-ListFieldInternalNameCollection -List:$Identity
}

Export-List `
    -Identity:$Identity `
    -Fields:$Fields `
    -PageSize:$PageSize |
    Write-Output
