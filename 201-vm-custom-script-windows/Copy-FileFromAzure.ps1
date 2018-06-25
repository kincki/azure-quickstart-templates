<# Custom Script for Windows to install a file from Azure Storage using the staging folder created by the deployment script #>
param (
    [string]$artifactsLocation,
    [string]$artifactsLocationSasToken,
    [string]$folderName,
    [string]$fileToInstall
)


$LogFile = "c:\apps\logs\$(gc env:computername).log"

#The log file may already exist
try {
	New-Item -ItemType file -Path $LogFile -ErrorAction Stop
} catch [System.IO.IoException] {
	WriteLog "$LogFile already exists..Continue!.."
}

Function WriteLog
{
	Param ([string] $logString)

	Add-content $LogFile -value $logString
}

WriteLog "~~~~~ DEEPNETWORK custom script running!!! ~~~~~" 


$source = $artifactsLocation + "\$folderName\$fileToInstall" + $artifactsLocationSasToken
$dest = "C:\WindowsAzure\$folderName"

try{
	New-Item -Path $dest -ItemType directory -ErrorAction Stop
} catch {
	$ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName

	WriteLog "ErrorMessage: $ErrorMessage"
	WriteLog "FailedItem: $FailedItem"
}

Invoke-WebRequest $source -OutFile "$dest\$fileToInstall"
