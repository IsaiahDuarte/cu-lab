function Install-AgentService {
    <#
    .SYNOPSIS
    Installs the ControlUp Agent Service on specified machines.

    .DESCRIPTION
    Copies necessary files and runs installation scripts for the Agent Service.

    .PARAMETER Config
    The CUConfig object containing lab configuration.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [CUConfig] $Config
    )

    Write-ScreenInfo "Installing ControlUp Agent Service"
    # Install Agent Service
    foreach($Agent in $Config.GetRTDX()) {
        if($Agent.name -in $Config.GetMonitors().Name) { Continue }
        Send-ModuleToPSSession -Module (Get-Module -Name ControlUp.Automation -ListAvailable) -Session (New-LabPSSession -ComputerName $Agent.Name)
        $Params = "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Install-Agent.ps1 -Token $($Config.DEXKey) -FolderPath $($Config.OrgName)\$($Config.LabName)\$($Agent.DomainName)\Agent -Site Default"
        Invoke-LabCommand -ComputerName $Agent.Name -ActivityName 'Installing CUAgent' -ScriptBlock {
            Start-Process -FilePath "C:\psexec.exe" -ArgumentList $Params -Wait -RedirectStandardOutput 'C:\scripts\Install-Agent.log' -RedirectStandardError 'C:\scripts\psexec-error-Install-Agent.log'
        } -Variable (Get-Variable -Name Params)
    }
}