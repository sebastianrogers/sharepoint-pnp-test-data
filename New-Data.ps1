<#
.SYNOPSIS

Creates a new CSV file suitable for importing into SharePoint via Set-Data.ps1

.EXAMPLE
Add test data to a SharePoint site based on an example JSON file

.\New-Data.ps1 -Path:'./examples/people.json'

#>

param(
    # The JSON file containing the definition of the test data to generate
    [Parameter(Mandatory)][string]$DefinitionPath,

    # The JSON file containing the definition of the test data to generate
    [Parameter(Mandatory)][string]$OutputPath
)

# Always stop on an error rather than failing to do part of the script
$ErrorActionPreference = 'stop'

# Show basic information
$InformationPreference = 'continue'

$Append = $false

$Definition = Get-Content -Path:$DefinitionPath -Raw |
    ConvertFrom-Json

$Definition.lists |
    ForEach-Object {

    $List = $PSItem
    $Rows = $List.rows
    $Fields = $List.fields

    for ($i = 0; $i -lt $Rows; $i++) {
        $Object = New-Object PSObject

        $Fields | ForEach-Object {
            $Field = $PSItem
            $Object | Add-Member -MemberType:NoteProperty -Name:$Field.title -Value:$Field.pattern
        }
    }

    if ($Object) {
        Export-Csv -Path:$OutputPath -InputObject:$Object -NoTypeInformation -Append:$Append

        $Append = $true
    }
}
