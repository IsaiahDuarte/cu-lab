function Confirm-RequiredModules {
    <#
    .SYNOPSIS
    Checks the AutomatedLab and ControlUp.Automation module is installed and imported.
    #>
    [CmdletBinding()]
    param ()

    $Modules = @('AutomatedLab', 'ControlUp.Automation')
    foreach ($Module in $Modules) {
        Write-Host "Checking if $Module is installed"
        if (-not (Get-Module -Name $Module -ListAvailable)) {
            Write-Host "$Module module is not installed. Installing $Module now."
            Install-Module $Module -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
        }
        Import-Module $Module
    }
}