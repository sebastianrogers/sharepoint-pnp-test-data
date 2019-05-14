
<#
.SYNOPSIS
Adds Random number of documents in a random number of folders, at random folder depth.
You need to connect using Connect-pnponline.

.EXAMPLE
Imports a Maximum of 40 documents per folder. 
There will be a maximum of 20 folder per folder depth
There will be a maximum of 10 folder depth per root folder of the library

./Add-RandomFoldersAndFiles.ps1 -ExampleFilePath:.\ExampleFiles -List:'Import Library' -MaxFolderDepth:10 -MaxFoldersInEachDepth:20 -MaxDocumentsPerFolder:40

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
    #Maximum Folder Depth Number
    [Parameter(Mandatory)]
    [int]
    $MaxFolderDepth,
    #Maximum No. of Folders in each Folder Depth
    [Parameter(Mandatory)]
    [int]
    $MaxFoldersInEachDepth,
    #Maximum No. of Documents in each Folder.
    [Parameter(Mandatory)]
    [int]
    $MaxDocumentsPerFolder

)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

if ($VerbosePreference) {
    Set-PnPTraceLog -On -Level:Debug
}
else {
    Set-PnPTraceLog -Off
}

$RandomFiles = get-childitem $ExampleFilePath
$conjunction = "for", "and", "nor", "but", "or", "yet", "so", "the", "my", "we", "our"
#Dictionary list of words.
$words = import-csv $PSScriptRoot\DataFiles\DictionaryOfWords.csv

$global:FolderCount = 0
$global:ItemCount = 0

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

    $CurrentDepth--
    if ($CurrentDepth -gt 0) {
        $CurrentDepth = Get-Random -Minimum 0 -Maximum ($CurrentDepth + 1)
        Write-Verbose -Message "The folder $FolderPath will only go $CurrentDepth Deep"
        $foldersCount = Get-Random -Minimum 1 -Maximum ($MaxFoldersInEachDepth + 1)
        Write-Verbose -Message "The folder $FolderPath will have $foldersCount folders inside"
        for ($i = 0; $i -lt $foldersCount; $i++) {
            #Create Folder
            $FolderName = Get-RandomFolderName
            $ReturnedFolder = Resolve-PnPFolder -SiteRelativePath $FolderPath\$FolderName
            Write-Information -MessageData:"Created folder called: $($ReturnedFolder.Name)"
            $global:FolderCount++
            CreateFoldersAndFiles -CurrentDepth $CurrentDepth -FolderPath ($FolderPath + "\" + $FolderName)
        }
    }

    
    $documents = Get-Random -Minimum 1 -Maximum ($MaxDocumentsPerFolder + 1)
    Write-Information -MessageData:"Adding $documents documents to folder path $($FolderPath)"
    for ($j = 0; $j -lt $documents; $j++) {
        #Add Documents
        $file = Get-RandomFileFromSystem
        $fileName = Get-RandomFileName
        
        $extension = $file.Substring($file.LastIndexOf('.'))
        $newName = $fileName + $extension
        Add-PnPFile -Path $file -Folder $FolderPath -NewFileName $newName | Out-Null
        $global:ItemCount++
        Write-Information -MessageData:"Created file called: $newName"
    }
    
}    

$depth++;
$list = Get-PnpList -Identity:$ListName
Write-Verbose $list.RootFolder.ServerRelativeUrl
$rootFolder = $list.RootFolder.ServerRelativeUrl
$siteRelativePath = $rootFolder.Substring($rootFolder.LastIndexOf('/')+1)
$Folder = Get-PnPFolder -Url ($siteRelativePath)
CreateFoldersAndFiles -CurrentDepth $MaxFolderDepth -FolderPath $siteRelativePath
Write-Information -MessageData:"Completed adding files to: $ListName"
Write-Information -MessageData:"Number of New Folder: $global:FolderCount"
Write-Information -MessageData:"Number of New Files: $global:ItemCount"
$total = $global:FolderCount + $global:ItemCount
Write-Information -MessageData:"Total Number of Items: $total"