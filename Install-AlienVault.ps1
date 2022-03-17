#make a log of the installation
$logdir = "c:\HolisticIT\AlienVault"
$logfile = (Get-date -Format "yyyy-MM-dd_HHmmss") + " AlienVaultInstall.log"
$fullLogfile = $logdir +"\"+ $logfile

if(!test-path $logdir){
    New-Item -Path $logdir -ItemType Directory
}

Start-Transcript -Path $fullLogfile

Write-Host "Downloading Installer and Installing"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
(new-object Net.WebClient).DownloadString('https://api.agent.alienvault.cloud/osquery-api/eu-west-2/bootstrap?flavor=powershell') | Invoke-Expression; install_agent -controlnodeid 3d241e23-edc0-44ae-8191-306870474ea5
#Wait 5 mins for script to execute

Write-Host "Waiting 5 mins..."
Start-Sleep -Seconds 300

#define update script
$UpdateScript = "C:\Program Files\osquery\alienvault-agent.ps1"

#check to see if file exists, if not wait 10 seconds
while (!(Test-Path $UpdateScript)) {
    Write-host (Get-date -Format "dd/MM/yyyy - HH:mm:ss") " - Update file not found. Waiting 10 Seconds..." 
    Start-Sleep -Seconds 10 
    }

Write-Host (Get-date -Format "dd/MM/yyyy - HH:mm:ss") " - File found! Enabling Auto Update"

$PowershellArgs = "-ex bypass -file `"$UpdateScript`" enable-auto-update "

try {
    Write-Host (Get-date -Format "dd/MM/yyyy - HH:mm:ss") " - Running Update Script"
    Start-Process powershell -Verb RunAs -ArgumentList $PowershellArgs -PassThru -Wait -ErrorAction Ignore
    Write-Host (Get-date -Format "dd/MM/yyyy - HH:mm:ss") " - Update Script executed"
    $appIsInstalled = $true
    Write-Host (Get-date -Format "dd/MM/yyyy - HH:mm:ss") " - App is installed Status " $appIsInstalled
} 
catch {
    Write-Host (Get-date -Format "dd/MM/yyyy - HH:mm:ss") " - An error occoured" 
    write-host "########"
    $Error

}

Stop-Transcript

if ($appIsInstalled -eq $true) { exit -1 }

else { exit 0 }