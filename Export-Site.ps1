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
    [Parameter(Mandatory)]
    [string]
    $Path,

    # The maximum number of results to process as a batch
    [int]$PageSize = 5000,

    # If supplied a URL to use to reconnect after each page
    [string]$URL,

    # If supplied use the Web Login when reconnecting
    [switch]$UseWebLogin
)

$ErrorActionPreference = 'stop'
$InformationPreference = 'Continue'

if ($VerbosePreference -eq 'Continue') {
    Set-PnPTraceLog -On -Level:Debug
}
else {
    Set-PnPTraceLog -Off
}

Import-Module -Name:./SharePointPnPTestData.psm1 -ArgumentList:@($ErrorActionPreference, $InformationPreference, $VerbosePreference) -Force

Get-PnPList |
Where-Object -Property:Hidden -ne $true |
Select-Object -Property:"Title" |
ForEach-Object {
    $ListTitle = $PSItem.Title

    Write-Verbose "Exporting the $ListTitle list..."

    $Fields = Get-ListFieldInternalNameCollection -List:$ListTitle
    Export-List `
        -Identity:$ListTitle `
        -Fields:$Fields `
        -PageSize:$PageSize `
        -URL:$URL `
        -UseWebLogin:$UseWebLogin |
    Export-Csv -Path:"$Path\$ListTitle.csv" -NoTypeInformation
}
