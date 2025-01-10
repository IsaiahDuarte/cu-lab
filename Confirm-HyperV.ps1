function Confirm-HyperV {
    <#
    .SYNOPSIS
    Checks if Hyper-V is installed and installs it if missing. This function will force a restart.
    #>
    [CmdletBinding()]
    param ()

    Write-ScreenInfo "Checking if Hyper-V is installed"
    if(-not(Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V')) {
        Write-ScreenInfo "Hyper-V is not installed. Installing Hyper-V now."
        Enable-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V' -Online -All
        Restart-Computer -Force
    }
}