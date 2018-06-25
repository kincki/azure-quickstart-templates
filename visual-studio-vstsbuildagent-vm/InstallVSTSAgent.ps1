# Downloads the Visual Studio Team Services Build Agent and installs on the new machine
# and registers with the Visual Studio Team Services account and build agent pool

# Enable -Verbose option
[CmdletBinding()]
Param(
[Parameter(Mandatory=$true)]$VSTSAccount,
[Parameter(Mandatory=$true)]$PersonalAccessToken,
[Parameter(Mandatory=$true)]$AgentName,
[Parameter(Mandatory=$true)]$PoolName,
[Parameter(Mandatory=$true)]$runAsAutoLogon,
[Parameter(Mandatory=$true)]$vmAdminUserName,
[Parameter(Mandatory=$true)]$vmAdminPassword,
[Parameter(Mandatory=$true)]$vmDnsName
)

$Logfile = "c:\Apps\Logs\$(gc env:computername).log"

Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}

function PrepMachineForAutologon () {
    # Create a PS session for the user to trigger the creation of the registry entries required for autologon
    #$computerName = "vm4buildagent.westeurope.cloudapp.azure.com"
	$computerName = "localhost"

    $password = ConvertTo-SecureString $vmAdminPassword -AsPlainText -Force
    if ($vmAdminUserName.Split("\").Count -eq 2)
    {
      $domain = $vmAdminUserName.Split("\")[0]
      $userName = $vmAdminUserName.Split('\')[1]

  	  LogWrite "User name and domain are retrievedas : $userName, $domain"

    }
    else
    {
      $domain = $Env:ComputerName
	  LogWrite "Domain to Connect to: $domain"
      $userName = $vmAdminUserName
      LogWrite "Username constructed to use for creating a PSSession: $domain\\$userName"
    }
   
    $credentials = New-Object System.Management.Automation.PSCredential("$domain\\$userName", $password)
    Enter-PSSession -ComputerName $computerName -Credential $credentials
    Exit-PSSession
  
    $ErrorActionPreference = "stop"
  
    try
    {
      # Check if the HKU drive already exists
      Get-PSDrive -PSProvider Registry -Name HKU | Out-Null
      $canCheckRegistry = $true
    }
    catch [System.Management.Automation.DriveNotFoundException]
    {
      try 
      {
        # Create the HKU drive
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
        $canCheckRegistry = $true
      }
      catch 
      {
        # Ignore the failure to create the drive and go ahead with trying to set the agent up
        LogWrite "Moving ahead with agent setup as the script failed to create HKU drive necessary for checking if the registry entry for the user's SId exists.\n$_"
      }
    }
  
    # 120 seconds timeout
    $timeout = 120 
  
    # Check if the registry key required for enabling autologon is present on the machine, if not wait for 120 seconds in case the user profile is still getting created
    while ($timeout -ge 0 -and $canCheckRegistry)
    {
      $objUser = New-Object System.Security.Principal.NTAccount($vmAdminUserName)
      $securityId = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
      $securityId = $securityId.Value
  
      if (Test-Path "HKU:\\$securityId")
      {
        if (!(Test-Path "HKU:\\$securityId\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run"))
        {
          New-Item -Path "HKU:\\$securityId\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run" -Force
          LogWrite "Created the registry entry path required to enable autologon."
        }
        
        break
      }
      else
      {
        $timeout -= 10
        Start-Sleep(10)
      }
    }
  
    if ($timeout -lt 0)
    {
      Write-Warning "Failed to find the registry entry for the SId of the user, this is required to enable autologon. Trying to start the agent anyway."
    }
}

LogWrite "Entering InstallVSOAgent.ps1" 

$currentLocation = Split-Path -parent $MyInvocation.MyCommand.Definition
LogWrite "Current folder: $currentLocation" 

#Create a temporary directory where to download from VSTS the agent package (vsts-agent.zip) and then launch the configuration.
$agentTempFolderName = Join-Path "D:" ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $agentTempFolderName
LogWrite "Temporary Agent download folder: $agentTempFolderName" 

$serverUrl = "https://$VSTSAccount.visualstudio.com"
LogWrite "Server URL: $serverUrl" 

$retryCount = 3
$retries = 1
LogWrite "Downloading Agent install files" 
do
{
  try
  {
    LogWrite "Trying to get download URL for latest VSTS agent release..."
    $latestReleaseDownloadUrl = "https://vstsagentpackage.azureedge.net/agent/2.126.0/vsts-agent-win-x64-2.126.0.zip"
    Invoke-WebRequest -Uri $latestReleaseDownloadUrl -Method Get -OutFile "$agentTempFolderName\agent.zip"
    LogWrite "Downloaded agent successfully on attempt $retries" 
    break
  }
  catch
  {
    $exceptionText = ($_ | Out-String).Trim()
    LogWrite "Exception occured downloading agent: $exceptionText in try number $retries" 
    $retries++
    Start-Sleep -Seconds 30 
  }
} 
while ($retries -le $retryCount)

# Construct the agent folder under the main (hardcoded) C: drive.
$agentInstallationPath = Join-Path "d:" $AgentName 
# Create the directory for this agent.
New-Item -ItemType Directory -Force -Path $agentInstallationPath 

# Create a folder for the build work
New-Item -ItemType Directory -Force -Path (Join-Path $agentInstallationPath $WorkFolder)

LogWrite "Extracting the zip file for the agent" 
$destShellFolder = (new-object -com shell.application).namespace("$agentInstallationPath")
$destShellFolder.CopyHere((new-object -com shell.application).namespace("$agentTempFolderName\agent.zip").Items(),16)

# Removing the ZoneIdentifier from files downloaded from the internet so the plugins can be loaded
# Don't recurse down _work or _diag, those files are not blocked and cause the process to take much longer
LogWrite "Unblocking files" 
Get-ChildItem -Recurse -Path $agentInstallationPath | Unblock-File | out-null

# Retrieve the path to the config.cmd file.
$agentConfigPath = [System.IO.Path]::Combine($agentInstallationPath, 'config.cmd')
LogWrite "Agent Location = $agentConfigPath" 
if (![System.IO.File]::Exists($agentConfigPath))
{
    Write-Error "File not found: $agentConfigPath" 
    return
}

# Call the agent with the configure command and all the options (this creates the settings file) without prompting
# the user or blocking the cmd execution

LogWrite "Configuring agent" 

# Set the current directory to the agent dedicated one previously created.
Push-Location -Path $agentInstallationPath

LogWrite "url: $serverUrl"
LogWrite "PAT : $PersonalAccessToken; poolname $PoolName --agent $AgentName --runAsAutoLogon --overwriteAutoLogon --windowslogonaccount $vmAdminUserName --windowslogonpassword $vmAdminPassword"

try
{


	if ($runAsAutoLogon -ieq "true")
	{
	  PrepMachineForAutologon

	  # Setup the agent with autologon enabled
	  .\config.cmd --unattended --url $serverUrl --auth PAT --token $PersonalAccessToken --pool $PoolName --agent $AgentName --runAsAutoLogon --overwriteAutoLogon --windowslogonaccount $vmAdminUserName --windowslogonpassword $vmAdminPassword
	}
	else 
	{
	  # Setup the agent as a service
	  .\config.cmd --unattended --url $serverUrl --auth PAT --token $PersonalAccessToken --pool $PoolName --agent $AgentName --runasservice
	}

}
catch
{
	$ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName

	LogWrite "ErrorMessage: $ErrorMessage"
	LogWrite "FailedItem: $FailedItem"

}

Pop-Location

LogWrite "Agent install output: $LASTEXITCODE" 

LogWrite "Exiting InstallVSTSAgent.ps1" 

