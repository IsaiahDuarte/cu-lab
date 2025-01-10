param(
    [string] $Token,
    [string] $FolderPath,
    [string] $Site
)
Start-Transcript -Path C:\scripts\AutomatedLab-Install-Agent.log -Append
Import-Module ControlUp.Automation
Write-ScreenInfo "Installing agent"
Install-CUAgent -Token $Token -FolderPath $FolderPath -Site $Site -AddFirewallRule $true
Wriet-Host "Done"
Stop-Transcript
