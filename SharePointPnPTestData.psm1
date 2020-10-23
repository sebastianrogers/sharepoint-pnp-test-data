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
        $Lookup
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
                "lookup" {
                    $Transform.$($ItemMapping.lookup).$SourceValue
                }
                "md5" {
                    Get-StringHash -String:$SourceValue     
                }
                default {
                    $SourceValue
                }
            }
        }

        Write-Output $Row
    }
}

function Export-List() {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The title of the list to get the data from
        [Parameter(Mandatory)][string]$Identity,

        # The fields in the list to get the data from
        [Parameter(Mandatory)][AllowNull()][array]$Fields
    )

    $Context = Get-PnPContext

    if (-not $Fields) {
        Get-PnPField -List:$Identity
    }

    $ListItems = Get-PnPListItem `
        -List:$Identity `
        -PageSize:5000

    $ListItems |
    ForEach-Object {
        $Item = $PSItem

        $Context.Load($Item.ContentType)
        $Context.Load($Item.FieldValuesAsText)
        Invoke-PnPQuery

        $Object = New-Object PSObject
        $Object | Add-Member -MemberType:NoteProperty -Name:"List" -Value:$Identity

        $Fields |
        ForEach-Object {
            $Key = $PSItem
            $Value = $null        

            if ($null -ne $Item.FieldValues[$Key]) {
                $Value = switch ($Item.FieldValues[$Key].GetType().Name) {
                    "DateTime" {
                        $Item.FieldValues[$Key].ToString("o")
                        break
                    }
                    "Boolean" {
                        if ($Item.FieldValuesAsText[$Key] -eq "Yes") { $true } else { $false }
                        break
                    }
                    default { $Item.FieldValuesAsText[$Key] }
                }
            }
            
            $Object | Add-Member -MemberType:NoteProperty -Name:$Key -Value:$Value
        }

        Write-Output -InputObject:$Object
    }
}

function Get-ListFieldInternalNameCollection() {
    param(
        # The title of the list to get the data from
        [Parameter(Mandatory)][string]$List
    )

    Get-PnPField -List:$List | 
    Where-Object Hidden -ne $true | 
    ForEach-Object { Write-Output $PSItem.InternalName } | 
    Write-Output
}

function Get-StringHash([String] $String, $HashName = "MD5") {
    $StringBuilder = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String)) | % {
        [Void]$StringBuilder.Append($_.ToString("x2"))
    }
    $StringBuilder.ToString()
}
