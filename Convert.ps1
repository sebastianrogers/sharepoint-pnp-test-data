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

function Get-StringHash([String] $String, $HashName = "MD5") {
    $StringBuilder = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String)) | % {
        [Void]$StringBuilder.Append($_.ToString("x2"))
    }
    $StringBuilder.ToString()
}

Get-StringHash "Brian Weston"
exit
function Convert-Data() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $Source,

        [Parameter(Mandatory)]
        [object]
        $Mapping,

        [object]
        $Transform
    )

    $Source |
    ForEach-Object {
        $Row = $PSItem

        $Row.PSObject.Properties |
        ForEach-Object {
            $Property = $PSItem
            $Name = $Property.Name
            $SourceValue = $Property.Value
            $ItemMapping = $Mapping.$Name
            $Row.$Name = switch ($ItemMapping.type) {
                "md5" {
                    Get-StringHash -String:$SourceValue     
                }
                "transform" {
                    $Transform.$($ItemMapping.transform).$SourceValue
                }
                default {
                    $SourceValue
                }
            }
        }

        Write-Output $Row
    }
}

$(Convert-Data `
        -Source:$(Import-Csv -Path:$SourcePath) `
        -Mapping:$(Get-Content -Path:$TransformPath | ConvertFrom-Json).mapping `
        -Transform:$(Get-Content -Path:$TransformPath | ConvertFrom-Json).transform) |
Export-Csv `
    -Path:$TargetPath `
    -NoTypeInformation


