param(
    [string]$DEXAPIKey,
    [string]$MonitorName,
    [string]$DomainName
)
Start-Transcript -Path C:\scripts\AutomatedLab-Setup-Monitor.log -Append
Write-Host "Importing Module"
Import-Module ControlUp.Automation -Force
Write-Host "Installing Monitor"
Install-CUMonitor -Token $DEXAPIKey -InternalDNSName "$MonitorName.$DomainName" -SiteName "Default"
Stop-Transcript