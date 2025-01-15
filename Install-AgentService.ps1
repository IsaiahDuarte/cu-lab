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
    foreach($domiain in $Config.Domains) {
        Set-LabInstallationCredential -Username $domiain.Username -Password $domiain.Password
        foreach($Agent in $Config.GetRTDX($domiain.Name)) {
            if($Agent.name -in $Config.GetMonitors().Name) { Continue }
            Copy-LabFileItem -Path $LabSources\Tools\SysInternals\psexec.exe -ComputerName $Agent.Name -DestinationFolderPath "C:\"
            Copy-LabFileItem -Path .\scripts\Agent -ComputerName $Agent.Name -DestinationFolderPath "C:\"    
            Send-ModuleToPSSession -Module (Get-Module -Name ControlUp.Automation -ListAvailable) -Session (New-LabPSSession -ComputerName $Agent.Name)
            $Params = "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\Agent\Install-Agent.ps1 -Token $($Config.DEXKey) -FolderPath $($Config.OrgName)\$($Config.LabName)\$($Agent.DomainName)\Agent -Site Default"
            Invoke-LabCommand -ComputerName $Agent.Name -ActivityName 'Installing CUAgent' -ScriptBlock {
                Start-Process -FilePath "C:\psexec.exe" -ArgumentList $Params -Wait -RedirectStandardOutput 'C:\Agent\Install-Agent.log' -RedirectStandardError 'C:\Agent\psexec-error-Install-Agent.log'
            } -Variable (Get-Variable -Name Params)
        }
        }
}