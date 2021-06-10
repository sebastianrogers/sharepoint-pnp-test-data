<#
.SYNOPSIS
Exports from specified lists all items modified after a specified date and places them in a folder

.EXAMPLE
Export the Action Definitions from a demo site.

./Export-SiteByDay.ps1 `
    -Path:temp `
    -ListCollection:'CMS Users', 'Correspondents', 'Cases', 'Timeline' `
    -StartDate:$(Get-Date -Date:'2021-06-01') `
    -EndDate:$(Get-Date -Date:'2021-06-10')
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]
    $Path,

    # The lists to export
    [Parameter(Mandatory)]
    [string[]]
    $ListCollection,

    # The modified date to export after
    [Parameter(Mandatory)][DateTime]$StartDate,

    # The modified date to export to
    [Parameter(Mandatory)][DateTime]$EndDate
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

$Date = $StartDate

while ($Date -le $EndDate) {
    Write-Information "Processing the $Date date..."
    
    $ModifiedStartValue = $Date.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $ModifiedEndValue = $Date.AddDays(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $ModifiedPath = "$Path\$($Date.ToString("yyyyMMdd"))"

    if (-not (Test-Path -Path:$ModifiedPath)) {
        New-Item -Path:$ModifiedPath -ItemType:Directory | Out-Null
    }

    $ListCollection |
    ForEach-Object {
        $Identity = $PSItem
        Write-Information "Processing the $Identity list..."

        $Fields = Get-ListFieldInternalNameCollection -List:$Identity

        Export-QueriedList `
            -Identity:$Identity `
            -Fields:$Fields `
            -Query:@"
<View>
    <Query>
        <Where>
            <And>
                <Geq>
                    <FieldRef Name='Modified'/>
                    <Value Type='DateTime'>$ModifiedStartValue</Value>
                </Geq>
                <Leq>
                    <FieldRef Name='Modified'/>
                    <Value Type='DateTime'>$ModifiedEndValue</Value>
                </Leq>
            </And>
        </Where>
        <OrderBy>
            <FieldRef Name='Modified' Ascending = 'true' />
        </OrderBy>
    </Query>
</View>
"@ | Export-Csv -Path:"$ModifiedPath\$Identity.csv" -NoTypeInformation
    }

    $Date = $Date.AddDays(1)
}
