<# Custom Script for Windows to install a file from Azure Storage using the staging folder created by the deployment script #>
param (
    [string]$artifactsLocation,
    [string]$artifactsLocationSasToken,
    [string]$folderName,
    [string]$fileToInstall
)

<#
$LogFile = "c:\apps\logs\$(gc env:computername).log"
New-Item -ItemType file -Path $LogFile

Function WriteLog
{
	Param ([string] $logString)

	Add-content $LogFile -value $logString
}
#>

Write-Verbose "DEEPNETWORK new folder name has been created " -verbose


$source = $artifactsLocation + "\$folderName\$fileToInstall" + $artifactsLocationSasToken
$dest = "C:\WindowsAzure\$folderName"
New-Item -Path $dest -ItemType directory
Invoke-WebRequest $source -OutFile "$dest\$fileToInstall"

<#
try{
	New-Item -Path $dest -ItemType directory -ea stop
} catch {
	$ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName

	WriteLog "ErrorMessage: $ErrorMessage"
	WriteLog "FailedItem: $FailedItem"

}
#>

