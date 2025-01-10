function New-CULab {
    <#
    .SYNOPSIS
    Creates a new lab environment with specified machines.

    .DESCRIPTION
    Uses the configuration to set up domains, networks, and machines in the lab.

    .PARAMETER Config
    The CUConfig object containing lab configuration.

    .EXAMPLE
    New-CULab -Config $Config

    .NOTES
    Assumes AutomatedLab module is imported.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [CUConfig] $Config
    )

    Write-ScreenInfo "Creating lab $($Config.LabName)"
    New-LabDefinition -Name $Config.LabName -DefaultVirtualizationEngine HyperV

    $LabMachines = New-Object System.Collections.Generic.List[VirtualMachine]

    foreach ($domain in $Config.Domains) {
        Write-ScreenInfo "Processing domain $($domain.Name)"
        Add-LabDomainDefinition -Name $domain.Name -AdminUser $domain.Username -AdminPassword $domain.Password
        
        $domainAdapterName = "$($Config.LabName).$($domain.Name)"
        $domainNatAdapterName = "$($Config.LabName).$($domain.Name).nat"

        Set-LabInstallationCredential -Username $domain.Username -Password $domain.Password

        # Each domain gets its own nat adapter
        Add-LabVirtualNetworkDefinition -Name $domainNatAdapterName -AddressSpace $domain.NatSubnet
        Get-NetNat | Where-Object {$_.name -eq $domainNatAdapterName} | Remove-NetNat -Confirm:$false
        New-NetNat -Name $domainNatAdapterName -InternalIPInterfaceAddressPrefix $domain.NatSubnet
        
        # Each domain gets its own internal adapter
        Add-LabVirtualNetworkDefinition -Name $domainAdapterName -AddressSpace $domain.Subnet

        $RouterVM = $Config.GetRouting() | Where-Object {$_.DomainName -eq $domain.Name}
        $RootDC = $Config.GetRootDomainControllers() | Where-Object {$_.DomainName -eq $domain.Name}

        $RoutingAdapters = @(
            (New-LabNetworkAdapterDefinition -VirtualSwitch $domainAdapterName -Ipv4Address $RouterVM.IpAddress ) # For full isolation of domains, this needs to be set. Manually for now though. -AccessVLANID $domain.HyperVAccessVLANID),
            (New-LabNetworkAdapterDefinition -VirtualSwitch $domainNatAdapterName -Ipv4Address $domain.NatIPAddress -Ipv4Gateway ("$($domain.NatAddressBase).1") -Ipv4DNSServers $RootDC.IpAddress)
        )

        foreach ($vm in $Config.VirtualMachines | Where-Object { $_.DomainName -eq $domain.Name }) {
            if ($vm -in $LabMachines) { continue }
            Write-ScreenInfo "Adding VM $($vm.Name)"
            $splat = @{
                Name                = $vm.Name
                OperatingSystem     = $vm.OS
                Memory              = $vm.RAM
                Processors          = $vm.CPU
                DomainName          = $vm.DomainName
                Roles               = $vm.Roles
                AutoLogonUserName   = $domain.Username
                AutoLogonPassword   = $domain.Password
                Network             = $domainAdapterName
                IpAddress           = $vm.IpAddress
                NetworkAdapter      = $null
                Gateway             = $RouterVM.IpAddress
                DnsServer1           = $RootDC.IpAddress
            }

            if($vm.Roles -contains 'Routing') {
                $splat.NetworkAdapter = $RoutingAdapters
                $Splat.Remove("Network")
                $Splat.Remove("IpAddress")
                $Splat.Remove("Gateway")
                $Splat.Remove("DnsServer1")
            } else {
                $Splat.Remove("NetworkAdapter")
            }

            Add-LabMachineDefinition @splat
            $LabMachines.Add($vm)
        }
    }
}