function Install-MonitorService {
    param(
        [Parameter(Mandatory = $true)]
        [CUConfig] $Config
    )

    Install-Module -Name ControlUp.Automation -SkipPublisherCheck -Scope AllUsers
    
    foreach($domain in $Config.Domains) {
        Set-LabInstallationCredential -Username $domain.Username -Password $domain.Password
        
        # ControlUp modules seem to only work with Invoke-LabCommand if the script is ran by through psexec.
        $Monitors = $Config.GetMonitors($domain.Name)
        if($Monitors.Count -eq 0) {
            continue
        } 

        Copy-LabFileItem -Path $LabSources\Tools\SysInternals\psexec.exe -ComputerName $Monitors.Name -DestinationFolderPath "C:\"
        Copy-LabFileItem -Path .\scripts\Monitor -ComputerName $Monitors.Name -DestinationFolderPath "C:\"
        Copy-LabFileItem -Path $LabSources\SoftwarePackages\ControlUpConsole.exe -DestinationFolderPath "C:\users\public\desktop\" -ComputerName $Config.GetMonitors().Name
        
        foreach($monitor in $Monitors) {
            Send-ModuleToPSSession -Module (Get-Module -Name ControlUp.Automation -ListAvailable) -Session (New-LabPSSession -ComputerName $Monitor.Name)
            Invoke-LabCommand -ComputerName $Monitor.Name -Variable @((Get-Variable -Name Monitor), (Get-Variable -Name Config)) -ActivityName 'ControlUp Monitor Service' -ScriptBlock {
                Start-Process -FilePath "C:\psexec.exe" -ArgumentList "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Setup-Monitor.ps1 -DEXAPIKey $($Config.DEXKey) -MonitorName $($Monitor.Name) -DomainName $($Monitor.DomainName)" -Wait -RedirectStandardOutput 'C:\scripts\psexec-standard-setup-monitor.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-monitor.log'
            }    
        }
    }
}
