$DriveLetter = 'E'
$LabName = 'culab'
$DomainName = 'lab.internal'
$LabPassword = (Read-Host -Prompt "Enter the password for the local administrator account")

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

Add-LabMachineDefinition -Name Monitor -OperatingSystem 'Windows Server 2022 Standard Evaluation (Desktop Experience)' -Memory 4GB -Processors 2 -Roles RootDC -DomainName $DomainName -AutoLogonPassword $LabPassword -Network 'Lab'

$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'Lab'
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp
Add-LabMachineDefinition -Name Router -Memory 1GB -OperatingSystem 'Windows Server 2022 Standard Evaluation' -Roles Routing -NetworkAdapter $netAdapter -DomainName $DomainName

Add-LabMachineDefinition -Name Win11 -OperatingSystem 'Windows 11 Pro' -Memory 2GB -IsDomainJoined -DomainName $DomainName -AutoLogonPassword $LabPassword -Network 'Lab'

Install-Lab

Send-ALNotification -Activity 'Base Install' -Message "Base install complete for $LabName" -Provider 'Toast'