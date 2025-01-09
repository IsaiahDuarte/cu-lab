if($Config.Domains.Count -gt 0) {
    Set-LabInstallationCredential -Username $Config.Domains[0].Username -Password $Config.Domains[0].Password
}

# ControlUp modules seem to only work with Invoke-LabCommand if the script is ran by through psexec.
if($Config.GetRTDX().Count -gt 0) {
    Copy-LabFileItem -Path $LabSources\Tools\SysInternals\psexec.exe -ComputerName $Config.GetRTDX().Name -DestinationFolderPath "C:\"
    Copy-LabFileItem -Path .\scripts -ComputerName $Config.GetRTDX().Name -DestinationFolderPath "C:\"
} 

if($Config.GetMonitors().Count -gt 0) {
    Copy-LabFileItem -Path $LabSources\SoftwarePackages\ControlUpConsole.exe -DestinationFolderPath "C:\users\public\desktop\" -ComputerName $Config.GetMonitors().Name
}

# Install Monitor Service
Install-Module -Name ControlUp.Automation -SkipPublisherCheck -Scope AllUsers -Verbose
foreach($Monitor in $Config.GetMonitors()) {
    Send-ModuleToPSSession -Module (Get-Module -Name ControlUp.Automation -ListAvailable) -Session (New-LabPSSession -ComputerName $Monitor.Name)
    Invoke-LabCommand -ComputerName $Monitor.Name -Variable @((Get-Variable -Name Monitor), (Get-Variable -Name Config)) -ActivityName 'ControlUp Monitor Service' -ScriptBlock {
        Start-Process -FilePath "C:\psexec.exe" -ArgumentList "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Setup-Monitor.ps1 -DEXAPIKey $($Config.DEXKey) -MonitorName $($Monitor.Name) -DomainName $($Monitor.DomainName)" -Wait -RedirectStandardOutput 'C:\scripts\psexec-standard-setup-monitor.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-monitor.log'
    } 
}