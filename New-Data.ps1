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

function Get-RandomDate() {
    $Minimum = $(Get-Date "1900-01-01").Ticks
    $Maximum = $(Get-Date "2000-12-31").Ticks
    $Ticks = Get-Random -Maximum:$Maximum -Minimum:$Minimum
    return Get-Date $Ticks -format "o"
}

$Append = $false

$DefinitionFolder = $(Get-ChildItem -Path:$DefinitionPath).Directory
$Definition = Get-Content -Path:$DefinitionPath -Raw |
    ConvertFrom-Json

$Definition.lookups.PSObject.Properties |
    ForEach-Object {
        $Key = $PSItem.Name

        Write-Verbose -Message:"Preparing the $Key lookup..."
        
        $Lookup = $Definition.lookups.$Key

        if ($Lookup.file) {
            Get-Content -Path:"$DefinitionFolder\$($Lookup.file)" | ConvertFrom-Csv |
                ForEach-Object {
                    $Definition.lookups.$Key.values += $PSItem
                }
        }
    }

$Definition.lists |
    ForEach-Object {

    $List = $PSItem
    $Rows = $List.rows
    $Fields = $List.fields

    1..$Rows | ForEach-Object {
        $Row = $PSItem

        Write-Verbose "Generating row $Row..."

        $Object = New-Object PSObject

        $Lookups = @{}

        $Definition.lookups.PSObject.Properties |
            ForEach-Object {
                $Key = $PSItem.Name
                $Lookup = $Definition.lookups.$Key.values

                if ($Lookup.length -eq 0) {
                    $Lookups.$Key = ""
                } else {
                    $Lookups.$Key = $Lookup[$(Get-Random -Minimum:0 -Maximum:$Lookup.length)]
                }
            }

        $Fields | ForEach-Object {
            $Field = $PSItem
            $Value = $Field.Pattern

            $Value = $Value -replace "{telephone}", $("{0:d5} {1:d6}" -f $(Get-Random -Maximum:9999 -Minimum:0), $(Get-Random -Maximum:999999 -Minimum:0))

            $Value = $Value -replace "{date}", $(Get-RandomDate)

            $Lookups.Keys | ForEach-Object {
                $Key = $PSItem
                $Lookup = $Lookups.$Key
                if ($Value -match "{lookup:$Key\.(?<field>.*)}") {
                    $Value = $Value -replace "{lookup:$Key\.(?<field>.*)}", $Lookup.$($Matches.field)
                }
            }

            $Fields | ForEach-Object {
                $FieldTitle = $PSItem.title
                $FieldValue = $Object.$FieldTitle

                $Value = $Value -replace "{field:$FieldTitle}", $FieldValue
            }

            $Object | Add-Member -MemberType:NoteProperty -Name:$Field.title -Value:$Value
        }

        if ($Object) {
            Export-Csv -Path:$OutputPath -InputObject:$Object -NoTypeInformation -Append:$Append
    
            $Append = $true
        }
    }
}
