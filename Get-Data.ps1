<#
.SYNOPSIS
Gets data from a SharePoint list

.EXAMPLE
Export the Action Definitions from a demo site.

-Url:http://simpleinnovation.sharepoint.com/sites/demo -List:'Action Definitions' -Fields:'Title', 'ID' -Path:'.\temp\Action Definitions.csv'

#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # The URL of the site collection to get the lists data from
    [Parameter(Mandatory)][string]$URL,

    # The title of the list to get the data from
    [Parameter(Mandatory)][string]$List,

    # The fields in the list to get the data from
    [Parameter(Mandatory)][array]$Field,

    # The CSV file to write the data to
    [Parameter(Mandatory)][string]$Path
)

$ErrorActionPreference = 'stop'
$InformationPreference = 'Continue'

if ($VerbosePreference -eq 'Continue') {
    Set-PnPTraceLog -On -Level:Debug
}
else {
    Set-PnPTraceLog -Off
}

Connect-PnPOnline -Url:$URL -UseWebLogin

$Context = Get-PnPContext

$ListItems = Get-PnPListItem `
    -List:$List

$Append = $false

$ListItems |
    ForEach-Object {
        $Item = $PSItem

        $Context.Load($Item.ContentType)
        $Context.Load($Item.FieldValuesAsText)
        Execute-PnPQuery

        $Object = New-Object PSObject
        $Object | Add-Member -MemberType:NoteProperty -Name:"List" -Value:$List
        $Object | Add-Member -MemberType:NoteProperty -Name:"ContentType" -Value:$Item.ContentType.Name

        $Field |
            ForEach-Object {
                $Key = $PSItem
                $Object | Add-Member -MemberType:NoteProperty -Name:$Key -Value:$Item.FieldValuesAsText[$Key]
            }

        Export-Csv -Path:$Path -InputObject:$Object -NoTypeInformation -Append:$Append

        $Append = $true
    }

