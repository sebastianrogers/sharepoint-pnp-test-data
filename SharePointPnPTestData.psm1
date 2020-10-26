param(
    [Parameter(Position = 0)]
    [string]
    $ErrorAction,

    [Parameter(Position = 1)]
    [string]
    $Information,

    [Parameter(Position = 2)]
    [string]
    $Verbose
)

if ($ErrorAction) {
    $ErrorActionPreference = $ErrorAction
}

if ($Verbose) {
    $InformationPreference = $Information
}

if ($ErrorAction) {
    $VerbosePreference = $Verbose
}

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
        [Parameter(Mandatory)][AllowNull()][array]$Fields,

        # The page size to use for exporting
        # the default is 5,000
        [int]$PageSize = 5000,

        # If supplied a URL to use to reconnect after each page
        [string]$URL,

        # If supplied use the Web Login when reconnecting
        [switch]$UseWebLogin
    )

    if (-not $Fields) {
        Get-PnPField -List:$Identity
    }

    Write-Verbose "Getting $Identity list details..."
    $List = Get-PnPList -Identity:$Identity

    $ItemCount = $List.ItemCount
    Write-Verbose "The $Identity list has $ItemCount items."

    $ItemTotal = $ItemCount
    $ItemID = 0

    while ($ItemID -lt $ItemTotal) {
        $PageID = ($ItemID) % $PageSize

        if ($URL -and ($PageID -eq 0)) {
            Write-Verbose "Connecting to $URL..."
            Connect-PnPOnline -Url:$URL -UseWebLogin:$UseWebLogin
        }

        $ItemID = $ItemID + 1
        Write-Verbose "Exporting the $ItemID item..."

        $Item = Get-PnPListItem `
            -List:$Identity `
            -Id:$ItemID

        if (-not $Item) {
            Write-Warning "Cannot find the item with a $ItemID list ID."
            $ItemTotal = $ItemTotal+1
            continue
        }

        $Item.Context.Load($Item.ContentType)
        $Item.Context.Load($Item.FieldValuesAsText)
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
    # Get-PnPListItem `
    #     -List:$Identity `
    #     -PageSize:$PageSize `
    #     -ScriptBlock {
    #     Param($ItemCollection)
    #     $ItemCollection.Context.ExecuteQuery()
    # } |
    # ForEach-Object {
    #     $Item = $PSItem
    #     $Item.Context.Load($Item.ContentType)
    #     $Item.Context.Load($Item.FieldValuesAsText)
    #     Invoke-PnPQuery

    #     $Object = New-Object PSObject
    #     $Object | Add-Member -MemberType:NoteProperty -Name:"List" -Value:$Identity

    #     $Fields |
    #     ForEach-Object {
    #         $Key = $PSItem
    #         $Value = $null        

    #         if ($null -ne $Item.FieldValues[$Key]) {
    #             $Value = switch ($Item.FieldValues[$Key].GetType().Name) {
    #                 "DateTime" {
    #                     $Item.FieldValues[$Key].ToString("o")
    #                     break
    #                 }
    #                 "Boolean" {
    #                     if ($Item.FieldValuesAsText[$Key] -eq "Yes") { $true } else { $false }
    #                     break
    #                 }
    #                 default { $Item.FieldValuesAsText[$Key] }
    #             }
    #         }
            
    #         $Object | Add-Member -MemberType:NoteProperty -Name:$Key -Value:$Value
    #     }

    #     Write-Output -InputObject:$Object
    # }
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
