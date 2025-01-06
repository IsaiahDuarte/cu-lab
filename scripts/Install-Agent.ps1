param(
    [string] $Token,
    [string] $FolderPath,
    [string] $Site
)
Start-Transcript -Path C:\scripts\AutomatedLab-Install-Agent.log -Append
Import-Module ControlUp.Automation
Install-CUAgent -Token $Token -FolderPath $FolderPath -Site $Site -AddFirewallRule $true
Stop-Transcript