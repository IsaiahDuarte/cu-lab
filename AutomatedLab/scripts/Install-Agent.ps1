param(
    [string] $Token,
    [string] $FolderPath,
    [string] $Site
)
Import-Module ControlUp.Automation
Install-CUAgent -Token $Token -FolderPath $FolderPath -Site $Site -AddFirewallRule $true