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
    $Path
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

Get-PnPList |
Where-Object -Property:Hidden -ne $true |
Select-Object -Property:"Title" |
ForEach-Object {
    $List = $PSItem.Title

    Export-List `
        -List:$List `
        -Fields:$(Get-ListFieldInternalNameCollection -List:$List) |
    Export-Csv -Path:"$Path\$List.csv" -NoTypeInformation
}
