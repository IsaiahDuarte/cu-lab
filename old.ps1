param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $ConfigPath
)


try {
    Start-Transcript -Path ".\BuildLog.txt" -Append

    # This technically only works on Windows, On a Windows Server you have to use Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools
    Write-Host "seeing if Hyper-V is installed"
    if(-not(Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V')) {
        Write-Host "Hyper-V is not installed. Installing Hyper-V now."
        Enable-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V' -Online -All
        Restart-Computer -Force
    }

    Write-Host "Importing Config"
    $Config = [CUConfig]::new()
    $Config.ImportFromJson($ConfigPath)

    Write-Host "Checking if AutomatedLab is installed"
    if(-not(Get-Module -Name AutomatedLab -ListAvailable)) {
        Write-Host "AutomatedLab module is not installed. Installing AutomatedLab now."
        Install-Module AutomatedLab -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
    }
    Import-Module AutomatedLab

    Write-Host "Checking if Lab Sources are configured"
    if((Get-LabSourcesLocation -Local) -notcontains "$($Config.DriveLetter):\LabSources") {
        New-LabSourcesFolder -DriveLetter $Config.DriveLetter -Force
        $folder = "$($Config.DriveLetter):\LabSources"
        Clear-Host
        Write-Host -ForegroundColor 'White' "Please copy the following to $folder and press enter to continue"
        Write-Host -ForegroundColor 'Yellow' "Download Windows Server 2022 and place ISO here - $folder\ISOs"
        Write-Host -ForegroundColor 'Yellow' "Download Windows 11 ISO and place here - $folder\ISOs"
        Write-Host -ForegroundColor 'Yellow' "Download ControlUp Console and place here - $folder\SoftwarePackages"
        Write-Host -ForegroundColor 'Yellow' "Download Hive and place here - $folder\SoftwarePackages"
        Write-Host -ForegroundColor 'Yellow'"Download agentmanagersetup.msi and place here - $folder\SoftwarePackages"
        Read-Host
    }
    $LabLocation = Get-LabSourcesLocation -Local | Where-Object { $_ -like "$($Config.DriveLetter):\*" }
    Write-Host "Lab location is $LabLocation"

    Write-Host "Checking if Lab $($Config.LabName) exists"
    if((Get-LabDefinition).Name -contains $Config.LabName) {
        Write-Host "Lab $($Config.LabName) already exists. Removing it now."
        Remove-Lab -Name $Config.LabName -Confirm:$false -ErrorAction SilentlyContinue
    }

    Write-Host "Creating lab $($Config.LabName)"
    New-LabDefinition -Name $Config.LabName -DefaultVirtualizationEngine HyperV

    $LabMachines = New-Object System.Collections.Generic.List[VirtualMachine]
    Add-LabVirtualNetworkDefinition -Name 'Default Switch' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }

    foreach($domain in $Config.Domains) {
        Write-Host "Processing $($domain.Name)"
        Add-LabDomainDefinition -Name $domain.Name -AdminUser $domain.Username -AdminPassword $domain.Password
        $domainAdatperName = $Config.LabName + "." + $Domain.Name
        Set-LabInstallationCredential -Username $domain.Username -Password $domain.Password

        # Use the default switch and a new adapter for routing
        Add-LabVirtualNetworkDefinition -Name $domainAdatperName
        $RoutingAdapters = @((New-LabNetworkAdapterDefinition -VirtualSwitch $domainAdatperName), (New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp))

        foreach($vm in $Config.VirtualMachines.Where({$_.DomainName -eq $domain.Name})) {
            if($vm -in $LabMachines) { Continue }
            Write-Host "Adding $($VM.Name)"
            $splat = @{
                Name = $vm.Name
                OperatingSystem = $vm.OS
                Memory = $vm.RAM
                Processors = $vm.CPU
                DomainName = $vm.DomainName
                Roles = $vm.Roles
                AutoLogonUserName = $domain.Username
                AutoLogonPassword = $domain.Password
                Network = $null
                NetworkAdapter = $null
            }
            
            if($vm.Roles -contains 'Routing') {
                $splat.NetworkAdapter = $RoutingAdapters
                $Splat.Remove('Network')
            } else {
                $splat.Network = $domainAdatperName
                $splat.Remove('NetworkAdapter')
            }            
            Add-LabMachineDefinition @splat
            $LabMachines.Add($vm)
        }    
    }

    # Handle Non-Domain
    foreach($vm in $Config.VirtualMachines.Where({[string]::IsNullOrEmpty($_.DomainName)})) {
        if($vm -in $LabMachines) { Continue }
        $splat = @{
            Name = $vm.Name
            OperatingSystem = $vm.OS
            Memory = $vm.RAM
            Processors = $vm.CPU
            DomainName = $vm.DomainName
            Roles = $vm.Roles
            AutoLogonUserName = $domain.Username
            AutoLogonPassword = $domain.Password
            Network = 'Default Switch'
        }
        Add-LabMachineDefinition @splat
        $LabMachines.Add($vm)    
    }

    Write-Host "Installing Lab $($Config.LabName)"
    Install-Lab

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

    # Setup Tree
    $FolderList = [Ordered]@{}
    $FolderList["$($Config.OrgName)\"] = $Config.LabName
    foreach($Monitor in $Config.GetMonitors()) {
        $DomainFolder = @{"$($Config.OrgName)\$($Config.DomainName)" = $Monitor.DomainName}
        $DomainPath = "$($Config.OrgName)\$($Config.LabName)"
        $AgentFolder = @{$DomainPath="Agent"}
        $MonitorFolder = @{$DomainPath="Monitor"}
        if(-not($FolderList.Contains($DomainFolder))){
            $FolderList[$DomainFolder.GetEnumerator().name] = $DomainFolder[$domainfolder.keys[0]]
        }
        if($AgentFolder -notin $FolderList) {
            $FolderList[$DomainFolder.GetEnumerator().name] = $AgentFolder[$domainfolder.keys[0]]
        }
        if($MonitorFolder -notin $FolderList) {
            $FolderList[$DomainFolder.GetEnumerator().name] = $MonitorFolder[$domainfolder.keys[0]]
        }
    }

    Invoke-LabCommand -ComputerName $Config.GetMonitors()[0].Name -ActivityName 'Moving ControlUp Monitor Object' -ScriptBlock {
        $json = $StrippedConfig | ConvertTo-Json -Compress -Depth 4
        $Arguments = ("/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Setup-Tree.ps1 -json " + $json)
        Write-Host $Arguments
        Start-Process -FilePath "C:\psexec.exe" -ArgumentList $Arguments -Wait -RedirectStandardOutput 'C:\scripts.\psexec-setup-tree.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-tree.log'
    } -Variable (Get-Variable -Name StrippedConfig)

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
    Install-LabSoftwarePackage -Path (Get-Item -Path "$LabSources\SoftwarePackages\hive*.exe")[0].FullName -ComputerName $Config.GetHives().Name -CommandLine ('/VERYSILENT /LOG="C:\setup_log_sb.log" /DIR="C:\Program Files\Scoutbees Custom Hive" /name="ScoutbeesCustomHive" /SUPPRESSMSGBOXES ' + '/token="' + $Config.ScoutbeesKey + '"')  

    # Install EdgeDX
    $Params = "/qn DEVREGCODE=$($Config.DEVREGCODE) TENANT=$($Config.TENANT) ALLUSERS=1"
    Install-LabSoftwarePackage -Path $LabSources\SoftwarePackages\agentmanagersetup.msi -ComputerName $Config.GetEdgeDX().Name -CommandLine $Params

    Send-ALNotification -Activity 'ControlUp Configuration Complete' -Message "Installed configuration" -Provider 'Toast'
    Show-LabDeploymentSummary -Detailed
} catch {
    Write-Host "Error: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}