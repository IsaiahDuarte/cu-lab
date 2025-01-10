# Install the Remote Access role with Routing
Install-WindowsFeature RemoteAccess -IncludeManagementTools

# Enable IP forwarding on all IPv4 interfaces
Set-NetIPInterface -Forwarding Enabled -AddressFamily IPv4 -InterfaceAlias "*"

# Identify the external network interface (replace '192.168.104.*' with your external IP range)
$ExternalInterface = Get-NetAdapter | Where-Object {
    Get-NetIPAddress -InterfaceAlias $_.Name -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.106.*' }
}
$ExternalInterfaceName = $ExternalInterface.Name

# Create the NAT configuration
New-NetNat -Name "MyNAT" -InternalIPInterfaceAddressPrefix "192.168.105.0/24"

#host? Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IPEnableRouter" -Value 0