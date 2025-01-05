$DriveLetter = 'E'
$LabName = 'culab'
$DomainName = 'lab.internal'
$OrgName = 'OnlyAdmins'
$DEXAPIKey = Get-Content -Path .\key
$TENANT = Get-Content -Path .\tenant
$DEVREGCODE = Get-Content -Path .\devregcode


$MonitorName = 'monitor-1'
$AgentName = 'rtagent-1'
$Agent2Name = 'rtagent-2'
$HiveName = 'sbhive-1'
$EdgeDXName = 'edgedx-1'
$Edge2DXName = 'edgedx-2'

$RTDevices = @($MonitorName, $AgentName, $Agent2Name)
$Hives = @($HiveName)
$EdgeDXDevices = @($EdgeDXName, $Edge2DXName)
#$AllDevices = @($MonitorName, $AgentName, $HiveName, $EdgeDXName, $Agent2Name)


if(-not(Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V')) {
    Write-Host "Hyper-V is not installed. Installing Hyper-V now."
    Enable-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V' -Online -All
    Restart-Computer -Force
}

if(-not(Get-Module -Name AutomatedLab -ListAvailable)) {
    Write-Host "AutomatedLab module is not installed. Installing AutomatedLab now."
    Install-Module AutomatedLab -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
}
Import-Module AutomatedLab

if((Get-LabSourcesLocation -Local) -notlike "${DriveLetter}:\*") {
    New-LabSourcesFolder -DriveLetter $DriveLetter -Force
}
$LabLocation = Get-LabSourcesLocation -Local | Where-Object { $_ -like "${DriveLetter}:\*" }
Write-Host "Lab location is $LabLocation"

if((Get-LabDefinition).Name -contains $LabName) {
    Write-Host "Lab $LabName already exists. Removing it now."
    Remove-Lab -Name $LabName
}

Write-Host "Creating lab $LabName"
New-LabDefinition -Name $LabName -DefaultVirtualizationEngine HyperV

Add-LabVirtualNetworkDefinition -Name 'Lab'
Add-LabVirtualNetworkDefinition -Name 'Default Switch' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }

# Monitor
$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'Lab'
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp
Add-LabMachineDefinition -Name $MonitorName -OperatingSystem 'Windows Server 2022 Standard Evaluation (Desktop Experience)' -Memory 4GB -Processors 2 -Roles RootDC,Routing -DomainName $DomainName -NetworkAdapter $netAdapter

# Agent 1
Add-LabMachineDefinition -Name $AgentName -OperatingSystem 'Windows 11 Pro' -Memory 2GB -IsDomainJoined -DomainName $DomainName -Network 'Lab'

# Agent 2
Add-LabMachineDefinition -Name $Agent2Name -OperatingSystem 'Windows 10 Pro' -Memory 2GB -IsDomainJoined -DomainName $DomainName -Network 'Lab'

# Scoutbees 1
Add-LabMachineDefinition -Name $HiveName -OperatingSystem 'Windows 11 Pro' -Memory 2GB -IsDomainJoined -DomainName $DomainName -Network 'Lab'

# EdgeDX 1
Add-LabMachineDefinition -Name $EdgeDXName -OperatingSystem 'Windows 11 Pro' -Memory 2GB -IsDomainJoined -DomainName $DomainName -Network 'Lab'

# EdgeDX 2
Add-LabMachineDefinition -Name $Edge2DXName -OperatingSystem 'Windows 10 Pro' -Memory 2GB -IsDomainJoined -DomainName $DomainName -Network 'Lab'

Install-Lab

Send-ALNotification -Activity 'Base Install' -Message "Installing ControlUp Configuration" -Provider 'Toast'

# Seems to only work with Invoke-LabCommand if the script is ran by through psexec.
Copy-LabFileItem -Path $LabSources\Tools\SysInternals\psexec.exe -ComputerName $RTDevices -DestinationFolderPath "C:\"
Copy-LabFileItem -Path .\scripts -ComputerName $RTDevices -DestinationFolderPath "C:\"
Copy-LabFileItem -Path $LabSources\SoftwarePackages\ControlUpConsole.exe -DestinationFolderPath "C:\users\public\desktop\" -ComputerName $RTDevices

Install-Module -Name ControlUp.Automation -SkipPublisherCheck -Scope AllUsers -Verbose
Send-ModuleToPSSession -Module (Get-Module -Name ControlUp.Automation -ListAvailable) -Session (New-LabPSSession -ComputerName $MonitorName)

# Install Service
Invoke-LabCommand -ComputerName $MonitorName -Variable @((Get-Variable -Name DEXAPIKey), (Get-Variable -Name MonitorName), (Get-Variable -Name DomainName)) -ActivityName 'ControlUp Monitor Service' -ScriptBlock {
    Start-Process -FilePath "C:\psexec.exe" -ArgumentList "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Setup-Monitor.ps1 -DEXAPIKey $DEXAPIKey -MonitorName $MonitorName -DomainName $DomainName" -Wait -RedirectStandardOutput 'C:\scripts\psexec-standard-setup-monitor.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-monitor.log'
} 

# Setup Tree
Invoke-LabCommand -ComputerName $MonitorName -ActivityName 'Moving ControlUp Monitor Object' -ScriptBlock {
    Start-Process -FilePath "C:\psexec.exe" -ArgumentList "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Setup-Tree.ps1 -LabName $LabName -OrgName $OrgName" -Wait -RedirectStandardOutput 'C:\scripts.\psexec-setup-tree.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-tree.log'
} -Variable (Get-Variable -Name LabName), (Get-Variable -Name OrgName)

# Install Agent Service
foreach($Agent in $RTDevices) {
    if($Agent -eq $MonitorName) { Continue }
    Send-ModuleToPSSession -Module (Get-Module -Name ControlUp.Automation -ListAvailable) -Session (New-LabPSSession -ComputerName $Agent)
    $Params = "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Install-Agent.ps1 -Token $DEXAPIKey -FolderPath $OrgName\$LabName\Agents -Site Default"
    Invoke-LabCommand -ComputerName $Agent -ActivityName 'Installing CUAgent' -ScriptBlock {
        Start-Process -FilePath "C:\psexec.exe" -ArgumentList $Params -Wait -RedirectStandardOutput 'C:\scripts.\psexec-setup-tree.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-tree.log'
    } -Variable (Get-Variable -Name Params)
}

# Install Hive
# Once we can silenty install with a key, we can add scouts automatically.
Install-LabSoftwarePackage -Path $LabSources\SoftwarePackages\hive110_1223x64.exe -ComputerName $Hives -CommandLine '/VERYSILENT /SUPPRESSMSGBOXES' 

# Install EdgeDX
$Params = "/qn DEVREGCODE=$DEVREGCODE TENANT=$TENANT ALLUSERS=1"
Install-LabSoftwarePackage -Path $LabSources\SoftwarePackages\agentmanagersetup.msi -ComputerName $EdgeDXDevices -CommandLine $Params

Read-Host "Press any key once the hives have their key installed."