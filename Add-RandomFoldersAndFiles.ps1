﻿
<#
.SYNOPSIS
Adds Random number of documents in a random number of folders, at random folder depth.
You need to connect using Connect-pnponline.

.EXAMPLE
Imports a Maximum of 40 documents per folder. 
There will be a maximum of 20 folder per folder depth
There will be a maximum of 10 folder depth per root folder of the library

./Add-RandomFoldersAndFiles.ps1 -ExampleFilePath:.\ExampleFiles -ListName:'Import Library' -MaxFolderDepth:10 -MaxFoldersInEachDepth:20 -MaxDocumentsPerFolder:40

.EXAMPLE
Imports a Maximum of 40 documents per folder. 
There will be a maximum of 20 folder per folder depth
There will be a maximum of 10 folder depth per root folder of the library
There will be a maxmium of 5 versions per document
./Add-RandomFoldersAndFiles.ps1 -ExampleFilePath:.\ExampleFiles -ListName:'Import Library' -MaxFolderDepth:10 -MaxFoldersInEachDepth:20 -MaxDocumentsPerFolder:40 -MaxVersionsPerDocument:5
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    #Folder path to example Documents to be used to upload
    [Parameter(Mandatory)]
    [string]
    $ExampleFilePath,
    #SharePoint List Name
    [Parameter(Mandatory)]
    [string]
    $ListName,
    #Maximum Folder Depth Number (D)
    [Parameter(Mandatory)]
    [int]
    $MaxFolderDepth,
    #Maximum No. of Folders in each Folder Depth  (W) = (W + ... + W^D)
    [Parameter(Mandatory)]
    [int]
    $MaxFoldersInEachDepth,
    #Maximum No. of Documents in each Folder.
    [Parameter(Mandatory)]
    [int]
    $MaxDocumentsPerFolder,
    #Maximum No. of Versions for each file.
    [Parameter(Mandatory = $false)]
    [int]
    $MaxVersionsPerDocument = 1
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

if ($VerbosePreference) {
    Set-PnPTraceLog -On -Level:Debug
}
else {
    Set-PnPTraceLog -Off
}

#Required otherwise you get lots of disconnects.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RandomFiles = Get-ChildItem $ExampleFilePath
$conjunction = "for", "and", "nor", "but", "or", "yet", "so", "the", "my", "we", "our"
#Dictionary list of words.
$words = Import-Csv $PSScriptRoot\DataFiles\DictionaryOfWords.csv

$global:FolderCount = 0
$global:ItemCount = 0
$global:VersionCount = 0

function Get-RandomFileFromSystem() {
    return (Get-Random $RandomFiles).FullName
}

function Get-RandomFolderName() {
    return (Get-Random $words.Word.Trim())
}

function Get-RandomFileName() {
    $word1 = (Get-Random $words.Word.Trim())
    $con = (Get-Random $conjunction)
    $word2 = (Get-Random $words.Word.Trim())
    return $word1 + " " + $con + " " + $word2
}

function CreateFoldersAndFiles() {
    param(
        [Parameter(Mandatory)]
        $CurrentDepth,
        [Parameter(Mandatory)]
        $FolderPath
    )

    $webServerRelativeUrl = (Get-PnPWeb).ServerRelativeUrl
    $CurrentDepth--
    if ($CurrentDepth -gt 0) {
        if ($false) {
            $CurrentDepth = Get-Random -Minimum 0 -Maximum ($CurrentDepth + 1)
            Write-Verbose -Message "The folder $FolderPath will only go $CurrentDepth Deep"
            $foldersCount = Get-Random -Minimum 1 -Maximum ($MaxFoldersInEachDepth + 1)
            Write-Verbose -Message "The folder $FolderPath will have $foldersCount folders inside"
        }

        $foldersCount = $MaxFoldersInEachDepth

        for ($i = 0; $i -lt $foldersCount; $i++) {
            #Create Folder
            $FolderName = Get-RandomFolderName
            $ReturnedFolder = Resolve-PnPFolder -SiteRelativePath $FolderPath\$FolderName
            Write-Information -MessageData:"Created folder called: $($ReturnedFolder.Name)"
            $global:FolderCount++
            CreateFoldersAndFiles -CurrentDepth $CurrentDepth -FolderPath ($FolderPath + "\" + $FolderName)
        }
    }

    
    $documents = $MaxDocumentsPerFolder
    Write-Information -MessageData:"Adding $documents documents to folder path $($FolderPath)"
    for ($j = 0; $j -lt $documents; $j++) {
        #Add Documents
        $file = Get-RandomFileFromSystem
        $fileName = Get-RandomFileName
        
        $extension = $file.Substring($file.LastIndexOf('.'))
        $newName = $fileName + $extension

        for ($k = 0; $k -lt $MaxVersionsPerDocument; $k++) {
                $item = Add-PnPFile -Path $file -Folder $FolderPath -NewFileName $newName -Values @{Title = "Version ($k)" } 
                if ($item.MinorVersion -eq 511) {
                    $item.Publish("Publishing to Major Version")
                    Invoke-PnPQuery   
                }
                $global:VersionCount++
        }

        $global:ItemCount++
        Write-Information -MessageData:"Created file called: $newName"
    }
}  


$depth++;
$list = Get-PnPList -Identity:$ListName
Write-Verbose $list.RootFolder.ServerRelativeUrl
$rootFolder = $list.RootFolder.ServerRelativeUrl
$siteRelativePath = $rootFolder.Substring($rootFolder.LastIndexOf('/') + 1)
$Folder = Get-PnPFolder -Url ($siteRelativePath)
CreateFoldersAndFiles -CurrentDepth $MaxFolderDepth -FolderPath $siteRelativePath
Write-Information -MessageData:"Completed adding files to: $ListName"
Write-Information -MessageData:"Number of New Folder: $global:FolderCount"
Write-Information -MessageData:"Number of New Files: $global:ItemCount"
Write-Information -MessageData:"Number of Versions created: $global:VersionCount"
$total = $global:FolderCount + $global:ItemCount
Write-Information -MessageData:"Total Number of Items: $total"