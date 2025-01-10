function Install-EdgeDX {
    <#
    .SYNOPSIS
    Installs the EdgeDX software on specified machines.

    .DESCRIPTION
    Installs EdgeDX using the provided registration code and tenant information.

    .PARAMETER Config
    The CUConfig object containing lab configuration.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [CUConfig] $Config
    )

    Write-ScreenInfo "Installing EdgeDX"

    # Install EdgeDX
    $Params = "/qn DEVREGCODE=$($Config.DEVREGCODE) TENANT=$($Config.TENANT) ALLUSERS=1"
    Install-LabSoftwarePackage -Path $LabSources\SoftwarePackages\agentmanagersetup.msi -ComputerName $Config.GetEdgeDX().Name -CommandLine $Params    
}