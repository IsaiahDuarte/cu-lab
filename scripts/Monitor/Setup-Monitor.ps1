param(
    [string] $DEXAPIKey,
    [string] $MonitorName,
    [string] $DomainName
)
Start-Transcript -Path C:\scripts\AutomatedLab-Setup-Monitor.log -Append
Write-ScreenInfo "Importing Module"
Import-Module ControlUp.Automation -Force
Write-ScreenInfo "Installing Monitor"
Install-CUMonitor -Token $DEXAPIKey -InternalDNSName "$MonitorName.$DomainName" -SiteName "Default"
Stop-Transcript