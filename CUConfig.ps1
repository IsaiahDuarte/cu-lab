class Domain {
    [string] $Name
    [string] $Username
    [string] $Password
    [string] $NetworkBase
    [string] $Subnet
    [string] $NatAddressBase
    [string] $NatSubnet
    [string] $NatIPAddress
}

class VirtualMachine {
    [string] $Name
    [string] $OS
    [string] $RAM
    [string] $CPU
    [string] $DomainName
    [string[]] $Roles
    [string] $IpAddress
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
    [string] $ScoutbeesKey
    [VirtualMachine[]] $VirtualMachines
    [Domain[]] $Domains

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

    [VirtualMachine[]] GetRTDX([string] $domainName) {
        return $this.VirtualMachines | Where-Object { $_.RTDX -eq $true -and $_.DomainName -eq $domainName }
    }

    [VirtualMachine[]] GetEdgeDX([string] $domainName) {
        return $this.VirtualMachines | Where-Object { $_.EdgeDX -eq $true -and $_.DomainName -eq $domainName }
    }

    [VirtualMachine[]] GetHives([string] $domainName) {
        return $this.VirtualMachines | Where-Object { $_.Hive -eq $true -and $_.DomainName -eq $domainName  }
    }

    [VirtualMachine[]] GetMonitors([string] $domainName) {
        return $this.VirtualMachines | Where-Object { $_.Monitor -eq $true -and $_.DomainName -eq $domainName }
    }

    [VirtualMachine[]] GetDomainControllers([string] $domainName) {
        return $this.VirtualMachines | Where-Object { $_.Roles -contains 'DC' -and $_.DomainName -eq $domainName }
    }

    [VirtualMachine[]] GetRootDomainControllers([string] $domainName) {
        return $this.VirtualMachines | Where-Object { $_.Roles -contains 'RootDC' -and $_.DomainName -eq $domainName }
    }

    [VirtualMachine[]] GetRouting([string] $domainName) {
        return $this.VirtualMachines | Where-Object { $_.Roles -contains 'Routing' -and $_.DomainName -eq $domainName }
    }

    [void] ImportFromJson([string] $path) {
        $jsonObj = Get-Content -Path $path | ConvertFrom-Json
        $this.LabName = $jsonObj.LabName
        $this.OrgName = $jsonObj.OrgName
        $this.DriveLetter = $jsonObj.DriveLetter
        $this.DEXKey = $jsonObj.DEXKey
        $this.DEVREGCODE = $jsonObj.DEVREGCODE
        $this.TENANT = $jsonObj.TENANT
        $this.ScoutbeesKey = $jsonObj.ScoutbeesKey
        $this.VirtualMachines = foreach ($vm in $jsonObj.VirtualMachines) {
            $obj = [VirtualMachine]::new()
            $obj.Name = $vm.Name
            $obj.OS = $vm.OS
            $obj.RAM = $vm.RAM
            $obj.CPU = $vm.CPU
            $obj.Roles = $vm.Roles
            $obj.DomainName = $vm.DomainName
            $obj.RTDX = $vm.RTDX
            $obj.EdgeDX = $vm.EdgeDX
            $obj.Hive = $vm.Hive
            $obj.Monitor = $vm.Monitor
            $obj.IpAddress = $vm.IpAddress
            $obj
        }
        $this.Domains = foreach($domain in $jsonObj.Domains) {
            $obj = [Domain]::New()
            $obj.Name = $domain.Name
            $obj.Username = $domain.Username
            $obj.Password = $domain.Password
            $obj.NetworkBase = $domain.NetworkBase
            $obj.Subnet = $domain.Subnet
            $obj.NatAddressBase = $domain.NatAddressBase
            $obj.NatSubnet = $domain.NatSubnet
            $obj.NatIPAddress = $domain.NatIPAddress
            $obj
        }
    }
}
