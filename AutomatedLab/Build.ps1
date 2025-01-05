$Config = Get-Content -Path .\config.json | ConvertFrom-Json

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

if((Get-LabSourcesLocation -Local) -notlike "$($Config.DriveLetter):\*") {
    New-LabSourcesFolder -DriveLetter $Config.DriveLetter -Force
}
$LabLocation = Get-LabSourcesLocation -Local | Where-Object { $_ -like "$($Config.DriveLetter):\*" }
Write-Host "Lab location is $LabLocation"

if((Get-LabDefinition).Name -contains $Config.LabName) {
    Write-Host "Lab $($Config.LabName) already exists. Removing it now."
    Remove-Lab -Name $Config.LabName -Confirm:$false
}

Write-Host "Creating lab $($Config.LabName)"
New-LabDefinition -Name $Config.LabName -DefaultVirtualizationEngine HyperV

Add-LabVirtualNetworkDefinition -Name $Config.LabName
Add-LabVirtualNetworkDefinition -Name 'Default Switch' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }

$LabMachines = New-Object System.Collections.Generic.List[System.String]

$RoutingAdapters = @((New-LabNetworkAdapterDefinition -VirtualSwitch $Config.LabName), (New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp))

# Domain Controllers
foreach($DC in $Config.DomainControllers) {
    $Roles = New-Object System.Collections.Generic.List[System.String]
    if($DC.RootDC) { $Roles.Add('RootDC') } else { $Roles.Add('DC') }
    if($DC.Routing) { $Roles.Add('Routing') }
    if($DC.Routing) {
        $LabMachines.Add($DC.Name)
        Add-LabMachineDefinition -Name $DC.Name -OperatingSystem $DC.OS -Memory $DC.RAM -Processors $DC.CPU -Roles $Roles -DomainName $DC.DomainName -NetworkAdapter $RoutingAdapters
        $LabMachines.Add($DC.Name)
    } else {
        Add-LabMachineDefinition -Name $DC.Name -OperatingSystem $DC.OS -Memory $DC.RAM -Processors $DC.CPU -Roles $Roles -DomainName $DC.DomainName -Network $Config.LabName
        $LabMachines.Add($DC.Name)
    }
}

# Monitors
foreach($Monitor in $Config.Monitors) {
    if($Monitor.Name -in $LabMachines) { Continue }
    Add-LabMachineDefinition -Name $Monitor.Name -OperatingSystem $Monitor.OS -Memory $Monitor.RAM -Processors $Monitor.CPU -DomainName $Monitor.DomainName -Network $Config.LabName
    $LabMachines.Add($Monitor.Name)
}

 # EdgeDX - Windows
foreach($Agent in $Config.EdgeDX) {
    if($Agent.Name -in $LabMachines) { Continue }
    Add-LabMachineDefinition -Name $Agent.Name -OperatingSystem $Agent.OS -Memory $Agent.RAM -Processors $Agent.CPU -DomainName $Agent.DomainName -Network $Config.LabName
    $LabMachines.Add($Agent.Name)
}

# Hives
foreach($Hive in $Config.Hives) {
    if($Hive.Name -in $LabMachines) { Continue }
    Add-LabMachineDefinition -Name $Hive.Name -OperatingSystem $Hive.OS -Memory $Hive.RAM -Processors $Hive.CPU -DomainName $Hive.DomainName -Network $Config.LabName
    $LabMachines.Add($Hive.Name)
}

# RT Devices
foreach($RTDevice in $Config.RTDevices) {
    if($RTDevice.Name -in $LabMachines) { Continue }
    Add-LabMachineDefinition -Name $RTDevice.Name -OperatingSystem $RTDevice.OS -Memory $RTDevice.RAM -Processors $RTDevice.CPU -DomainName $RTDevice.DomainName -Network $Config.LabName
    $LabMachines.Add($RTDevice.Name)
}


Install-Lab

Send-ALNotification -Activity 'Base Install' -Message "Installing ControlUp Configuration" -Provider 'Toast'

# Seems to only work with Invoke-LabCommand if the script is ran by through psexec.
Copy-LabFileItem -Path $LabSources\Tools\SysInternals\psexec.exe -ComputerName $Config.RTDevices.Name-DestinationFolderPath "C:\"
Copy-LabFileItem -Path .\scripts -ComputerName $Config.RTDevices.Name -DestinationFolderPath "C:\"
Copy-LabFileItem -Path $LabSources\SoftwarePackages\ControlUpConsole.exe -DestinationFolderPath "C:\users\public\desktop\" -ComputerName $Config.Monitors.Name

# Install Monitor Service
Install-Module -Name ControlUp.Automation -SkipPublisherCheck -Scope AllUsers -Verbose
foreach($Monitor in $Config.Monitors) {
    Send-ModuleToPSSession -Module (Get-Module -Name ControlUp.Automation -ListAvailable) -Session (New-LabPSSession -ComputerName $Monitor.Name)
    Invoke-LabCommand -ComputerName $Monitor.Name -Variable @((Get-Variable -Name Monitor), (Get-Variable -Name Config)) -ActivityName 'ControlUp Monitor Service' -ScriptBlock {
        Start-Process -FilePath "C:\psexec.exe" -ArgumentList "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Setup-Monitor.ps1 -DEXAPIKey $($Config.DEXKey) -MonitorName $($Monitor.Name) -DomainName $($Monitor.DomainName)" -Wait -RedirectStandardOutput 'C:\scripts\psexec-standard-setup-monitor.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-monitor.log'
    } 
}

# Setup Tree
Invoke-LabCommand -ComputerName $Config.Monitors[0].Name -ActivityName 'Moving ControlUp Monitor Object' -ScriptBlock {
    Start-Process -FilePath "C:\psexec.exe" -ArgumentList "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Setup-Tree.ps1 -LabName $($Config.LabName) -OrgName $($Config.OrgName)" -Wait -RedirectStandardOutput 'C:\scripts.\psexec-setup-tree.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-tree.log'
} -Variable (Get-Variable -Name Config)

# Install Agent Service
foreach($Agent in $Config.RTDevices.Name) {
    if($Agent -in $Config.Monitors.Name) { Continue }
    Send-ModuleToPSSession -Module (Get-Module -Name ControlUp.Automation -ListAvailable) -Session (New-LabPSSession -ComputerName $Agent)
    $Params = "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Install-Agent.ps1 -Token $($Config.DEXKey) -FolderPath $($Config.OrgName)\$($Config.LabName)\Agents -Site Default"
    Invoke-LabCommand -ComputerName $Agent -ActivityName 'Installing CUAgent' -ScriptBlock {
        Start-Process -FilePath "C:\psexec.exe" -ArgumentList $Params -Wait -RedirectStandardOutput 'C:\scripts.\psexec-setup-tree.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-tree.log'
    } -Variable (Get-Variable -Name Params)
}

# Install Hive
# Once we can silenty install with a key, we can add scouts automatically.
Install-LabSoftwarePackage -Path $LabSources\SoftwarePackages\hive110_1223x64.exe -ComputerName $($Config.Hives.Name) -CommandLine '/VERYSILENT /SUPPRESSMSGBOXES' 

# Install EdgeDX
$Params = "/qn DEVREGCODE=$DEVREGCODE TENANT=$TENANT ALLUSERS=1"
Install-LabSoftwarePackage -Path $LabSources\SoftwarePackages\agentmanagersetup.msi -ComputerName $Config.EdgeDX.Name -CommandLine $Params

Read-Host "Press any key once the hives have their key installed."