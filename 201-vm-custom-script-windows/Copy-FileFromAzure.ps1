<# Custom Script for Windows to install a file from Azure Storage using the staging folder created by the deployment script #>
param (
    [string]$artifactsLocation,
    [string]$artifactsLocationSasToken,
    [string]$folderName,
    [string]$fileToInstall
)

Function WriteLog
{
	Param ([string] $logString)

	Add-content $LogFile -value $logString
}

$LogFile = "c:\apps\logs\$(Get-Content env:computername).log"

#The log file may already exist
try {
	New-Item -ItemType file -Path $LogFile -ErrorAction Stop
} catch [System.IO.IoException] {
	Write-Verbose "$LogFile already exists..Continue!.." -verbose
}

Write-verbose "~~~~~ DEEPNETWORK custom script running!!! ~~~~~" -verbose


$source = $artifactsLocation + "\$folderName\$fileToInstall" + $artifactsLocationSasToken
$dest = "C:\WindowsAzure\$folderName"

try{
	New-Item -Path $dest -ItemType directory -ErrorAction Stop
} catch {
	$ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName

	Write-Verbose "ErrorMessage: $ErrorMessage" -Verbose
	Write-verbose "FailedItem: $FailedItem" -verbose
}

Invoke-WebRequest $source -OutFile "$dest\$fileToInstall"
