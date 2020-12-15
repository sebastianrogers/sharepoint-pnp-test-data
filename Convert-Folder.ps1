<#
.SYNOPSIS
This script allows you to convert the data in a set of csv files by transforming it.

The transformed files are copied to a folder so that the original files are not updated.

The transform definition is a json file

```json
{
    "mapping": {
        "field-name": {
            "type": "lookup|md5",
            "lookup" "lookup-name"
        },
    "lookup": {
        "lookup-name": {
            "source-value": "target-value"
        }
    }
```

```md
| Transform | Effect                                                                                                 |
| --------- | ------------------------------------------------------------------------------------------------------ |
| lookup    | Replaces the field value with the matching value from the lookup if there is a match                   |
| md5       | Replaces the field value with its md5 hash, this in effect anonymises it but preerves its distinctness |
| remove    | Removes the field from the output                                                                      |
```
#>

param(
    # The source path
    [Parameter(Mandatory)]
    [string]
    $SourcePath,

    # The target path
    [Parameter(Mandatory)]
    [string]
    $TargetPath,

    # The transform definitions
    [Parameter(Mandatory)]
    [string]
    $TransformPath
)

Import-Module -Name:$PSScriptRoot/SharePointPnPTestData.psm1 -Force

$Mapping = $(Get-Content -Path:$TransformPath | ConvertFrom-Json).mapping
$Lookup = $(Get-Content -Path:$TransformPath | ConvertFrom-Json).lookup

Get-ChildItem -Path:$SourcePath |
ForEach-Object {
    $Source = $(Import-Csv -Path:$PSItem.FullName)
    if (-not $Source) {
        return
    }

    $Target = "$TargetPath\$($PSItem.Name)"
    Write-Verbose "Transforming the $($PSItem.FullName) file to the $Target file..."

    $(Convert-Data `
            -Source:$Source `
            -Mapping:$Mapping `
            -Lookup:$Lookup) |
    Export-Csv `
        -Path:$Target `
        -NoTypeInformation
}