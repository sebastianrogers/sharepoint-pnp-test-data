<#
.SYNOPSIS
Adds test data to a SharePoint System

.EXAMPLE
Add test data to a SharePoint site based on an example JSON file

.\Add-SharePointTestData.ps1 -Url:'http://server/sites/site' -Path:'./examples/example.json'

#>

param(
    # The URL of the site collection to generate test data in.
    [Parameter(Mandatory)][string]$URL,

    # The JSON file containing the definition of the test data to generate
    [Parameter(Mandatory)][string]$Path
)

# Always stop on an error rather than failing to do part of the script
$ErrorActionPreference = 'stop'

# Show basic information
$InformationPreference = 'continue'

Write-Information -MessageData:"$(Get-Date) Started populating the $URL SharePoint site with test data based on the $Path configuration file."

$Content = Get-Content -Path:$Path -Raw
$JSON =  ConvertFrom-Json -InputObject:$Content

$JSON | ForEach-Object {
    $List = $PSItem
    $Title = $List.title
    $Rows = $List.rows
    $Fields = $List.fields

    for ($i = 0; $i -lt $Rows; $i++) {
        $Values = @{}
        $Fields | ForEach-Object {
            $Values[$PSItem.title] = $PSItem.pattern
        }
        
        $Item = Add-PnPListItem -List:$Title -Values:$Values
        Write-Verbose "Added the $($Item.Id) item."
    }
}

Write-Information -MessageData:"$(Get-Date) Finished populating the $URL SharePoint site with test data based on the $Path configuration file."