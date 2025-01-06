$configPath = '.\config.json'
class VirtualMachine {
    [string] $Name
    [string] $OS
    [string] $RAM
    [string] $CPU
    [string] $DomainName
    [string[]] $Roles
    [bool] $RTDX
    [bool] $EdgeDX
    [bool] $Hive
    [bool] $Monitor
}

class CUConfig {
    [string] $LabName
    [string] $OrgName
    [string] $DriveLetter
    [string] $DEXKey
    [string] $DEVREGCODE
    [string] $TENANT
    [VirtualMachine[]] $VirtualMachines

    [VirtualMachine[]] GetRTDX() {
        return $this.VirtualMachines | Where-Object { $_.RTDX -eq $true }
    }

    [VirtualMachine[]] GetEdgeDX() {
        return $this.VirtualMachines | Where-Object { $_.EdgeDX -eq $true }
    }

    [VirtualMachine[]] GetHives() {
        return $this.VirtualMachines | Where-Object { $_.Hive -eq $true }
    }

    [VirtualMachine[]] GetMonitors() {
        return $this.VirtualMachines | Where-Object { $_.Monitor -eq $true }
    }

    [VirtualMachine[]] GetDomainControllers() {
        return $this.VirtualMachines | Where-Object { $_.Roles -contains 'DC' }
    }

    [VirtualMachine[]] GetRootDomainControllers() {
        return $this.VirtualMachines | Where-Object { $_.Roles -contains 'RootDC' }
    }

    [VirtualMachine[]] GetRouting() {
        return $this.VirtualMachines | Where-Object { $_.Roles -contains 'Routing' }
    }
    
}

$jsonObj = Get-Content -Path $configPath | ConvertFrom-Json
$Config = [CUConfig]::new()
$Config.LabName = $jsonObj.LabName
$Config.OrgName = $jsonObj.OrgName
$Config.DriveLetter = $jsonObj.DriveLetter
$Config.DEXKey = $jsonObj.DEXKey
$Config.DEVREGCODE = $jsonObj.DEVREGCODE
$Config.TENANT = $jsonObj.TENANT
$Config.VirtualMachines = foreach ($vm in $jsonObj.VirtualMachines) {
    $obj = [VirtualMachine]::new()
    $obj.Name = $vm.Name
    $obj.OS = $vm.OS
    $obj.RAM = $vm.RAM
    $obj.CPU = $vm.CPU
    $obj.Roles = $vm.Roles
    $obj.RTDX = $vm.RTDX
    $obj.EdgeDX = $vm.EdgeDX
    $obj.Hive = $vm.Hive
    $obj.Monitor = $vm.Monitor
    $obj
}

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

if((Get-LabSourcesLocation -Local) -notcontains "$($Config.DriveLetter):\*") {
    New-LabSourcesFolder -DriveLetter $Config.DriveLetter -Force
}
$LabLocation = Get-LabSourcesLocation -Local | Where-Object { $_ -like "$($Config.DriveLetter):\*" }
Write-Host "Lab location is $LabLocation"

if((Get-LabDefinition).Name -contains $Config.LabName) {
    Write-Host "Lab $($Config.LabName) already exists. Removing it now."
    Remove-Lab -Name $Config.LabName -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Host "Creating lab $($Config.LabName)"
New-LabDefinition -Name $Config.LabName -DefaultVirtualizationEngine HyperV

Add-LabVirtualNetworkDefinition -Name $Config.LabName
Add-LabVirtualNetworkDefinition -Name 'Default Switch' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }

$LabMachines = New-Object System.Collections.Generic.List[VirtualMachine]
$RoutingAdapters = @((New-LabNetworkAdapterDefinition -VirtualSwitch $Config.LabName), (New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp))

foreach($vm in $Config.VirtualMachines) {
    try{
        $splat = @{
            Name = $vm.Name
            OperatingSystem = $vm.OS
            Memory = $vm.RAM
            Processors = $vm.CPU
            DomainName = $vm.DomainName
            Roles = $vm.Roles
            Network = $null
            NetworkAdapter = $null
        }
        if($vm.Roles -contains 'Routing') {
            $splat.NetworkAdapter = $RoutingAdapters
            $Splat.Remove('Network')
        } else {
            $splat.Network = $Config.LabName
            $splat.Remove('NetworkAdapter')
        }
    
        if($vm -in $LabMachines) { Continue }
        Add-LabMachineDefinition @splat
        $LabMachines.Add($vm)
    } catch {
        Write-Host "Error: $($_.Exception.Message)"
    }
}

Install-Lab

Send-ALNotification -Activity 'Base Install' -Message "Installing ControlUp Configuration" -Provider 'Toast'

# Seems to only work with Invoke-LabCommand if the script is ran by through psexec.
if($Config.GetRTDX().Count -gt 0) {
    Copy-LabFileItem -Path $LabSources\Tools\SysInternals\psexec.exe -ComputerName $Config.GetRTDX().Name -DestinationFolderPath "C:\"
} 
if($Config.GetMonitors().Count -gt 0) {
    Copy-LabFileItem -Path .\scripts -ComputerName $Config.GetMonitors().Name -DestinationFolderPath "C:\"
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

# Setup Tree
$Monitors = $Config.GetMonitors().Name -join ','
Invoke-LabCommand -ComputerName $Config.GetMonitors()[0].Name -ActivityName 'Moving ControlUp Monitor Object' -ScriptBlock {
    Start-Process -FilePath "C:\psexec.exe" -ArgumentList "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Setup-Tree.ps1 -LabName $($Config.LabName) -OrgName $($Config.OrgName) -Monitors $Monitors" -Wait -RedirectStandardOutput 'C:\scripts.\psexec-setup-tree.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-tree.log'
} -Variable (Get-Variable -Name Config), (Get-Variable -Name Monitors)

# Install Agent Service
foreach($Agent in $Config.GetRTDX().Name) {
    if($Agent -in $Config.GetMonitors().Name) { Continue }
    Send-ModuleToPSSession -Module (Get-Module -Name ControlUp.Automation -ListAvailable) -Session (New-LabPSSession -ComputerName $Agent)
    $Params = "/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Install-Agent.ps1 -Token $($Config.DEXKey) -FolderPath $($Config.OrgName)\$($Config.LabName)\Agents -Site Default"
    Invoke-LabCommand -ComputerName $Agent -ActivityName 'Installing CUAgent' -ScriptBlock {
        Start-Process -FilePath "C:\psexec.exe" -ArgumentList $Params -Wait -RedirectStandardOutput 'C:\scripts.\psexec-setup-tree.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-tree.log'
    } -Variable (Get-Variable -Name Params)
}

# Install Hive
# Once we can silenty install with a key, we can add scouts automatically.
Install-LabSoftwarePackage -Path $LabSources\SoftwarePackages\hive110_1223x64.exe -ComputerName $Config.GetHives().Name -CommandLine '/VERYSILENT /SUPPRESSMSGBOXES' 

# Install EdgeDX
$Params = "/qn DEVREGCODE=$($Config.DEVREGCODE) TENANT=$($Config.TENANT) ALLUSERS=1"
Install-LabSoftwarePackage -Path $LabSources\SoftwarePackages\agentmanagersetup.msi -ComputerName $Config.GetEdgeDX().Name -CommandLine $Params