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

    Write-Host "Creating lab $($Config.LabName)"
    New-LabDefinition -Name $Config.LabName -DefaultVirtualizationEngine HyperV

    $LabMachines = New-Object System.Collections.Generic.List[VirtualMachine]

    foreach ($domain in $Config.Domains) {
        Write-Host "Processing domain $($domain.Name)"
        Add-LabDomainDefinition -Name $domain.Name -AdminUser $domain.Username -AdminPassword $domain.Password
        
        $domainAdapterName = "$($Config.LabName).$($domain.Name)"
        $domainNatAdapterName = "$($Config.LabName).$($domain.Name).nat"
        Add-LabVirtualNetworkDefinition -Name $domainAdapterName -AddressSpace $domain.Subnet

        Set-LabInstallationCredential -Username $domain.Username -Password $domain.Password

        # Each domain gets its own nat adapter
        Add-LabVirtualNetworkDefinition -Name "$domainAdapterName.nat" -AddressSpace $domain.NatSubnet
        if(Get-NetIPAddress -IPAddress "$($Domain.NatAddressBase).1" -ErrorAction SilentlyContinue) {
            Remove-NetIPAddress -IPAddress "$($Domain.NatAddressBase).1" -Confirm:$false
        }

        if(-not (Get-NetNat | Where-Object {$_.name -eq $domainNatAdapterName})) {
            New-NetNat -Name $domainNatAdapterName -InternalIPInterfaceAddressPrefix $domain.NatSubnet
        }
        
        # $RouterVM = $Config.GetRouting() | Where-Object {$_.DomainName -eq $domain.Name}

        $RoutingAdapters = @(
            (New-LabNetworkAdapterDefinition -VirtualSwitch $domainAdapterName),
            (New-LabNetworkAdapterDefinition -VirtualSwitch $domainNatAdapterName -UseDhcp)
        )

        foreach ($vm in $Config.VirtualMachines | Where-Object { $_.DomainName -eq $domain.Name }) {
            if ($vm -in $LabMachines) { continue }
            Write-Host "Adding VM $($vm.Name)"
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
            }

            if($vm.Roles -contains 'Routing') {
                $splat.NetworkAdapter = $RoutingAdapters
                $Splat.Remove("Network")
                $Splat.Remove("IpAddress")
            } else {
                $Splat.Remove("NetworkAdapter")
            }

            Add-LabMachineDefinition @splat
            $LabMachines.Add($vm)
        }
    }
}