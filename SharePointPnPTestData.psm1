function Export-List() {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The title of the list to get the data from
        [Parameter(Mandatory)][string]$List,

        # The fields in the list to get the data from
        [Parameter(Mandatory)][AllowNull()][array]$Fields
    )

    $Context = Get-PnPContext

    if (-not $Fields) {
        Get-PnPField -List:$List
    }

    $ListItems = Get-PnPListItem `
        -List:$List

    $ListItems |
    ForEach-Object {
        $Item = $PSItem

        $Context.Load($Item.ContentType)
        $Context.Load($Item.FieldValuesAsText)
        Invoke-PnPQuery

        $Object = New-Object PSObject
        $Object | Add-Member -MemberType:NoteProperty -Name:"List" -Value:$List

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