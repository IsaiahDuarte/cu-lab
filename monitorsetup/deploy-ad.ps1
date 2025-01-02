$ethipaddress = '20.20.20.21'
$ethprefixlength = '24'
$ethdns = '20.20.20.3','8.8.8.8'
$ethdefaultgw = '20.20.20.1' 

$domainname = 'lab.internal'
$domainNetbiosName = 'lab'
$computername = 'monitor'

$ntpserver1 = '0.ba.pool.ntp.org'
$ntpserver2 = '1.ba.pool.ntp.org'

$RegPath = "HKLM:\SOFTWARE\Auto-AD"

if (Test-Path $RegPath) {
    Write-Host "$RegPath Exists" -ForegroundColor Yellow
}
else {
    Write-Host "Creating $RegPath" -ForegroundColor Green
    try {
        New-Item -Path $RegPath
    }
    catch {
        Read-Host $("Could not create logfile. Error: " + $_.Exception.Message)
        exit
    }
}


$firstcheck = Get-ItemProperty -Path $RegPath -Name "FirstStep" -ErrorAction SilentlyContinue
if (!$firstcheck) {
    Write-Host "First step not done" -ForegroundColor Yellow
    try {
        Get-NetIPAddress -IPAddress $ethipaddress | Remove-NetIPAddress -Confirm:$false 
        New-NetIPAddress -IPAddress $ethipaddress -PrefixLength $ethprefixlength -DefaultGateway $ethdefaultgw -InterfaceIndex (Get-NetAdapter).InterfaceIndex -ErrorAction Stop | Out-Null
        Set-DNSClientServerAddress -ServerAddresses $ethdns -InterfaceIndex (Get-NetAdapter).InterfaceIndex -ErrorAction Stop
        Write-Host "IP Address successfully set to $($ethipaddress), subnet $($ethprefixlength), default gateway $($ethdefaultgw) and DNS Server $($ethdns)" -ForegroundColor Green

        Rename-Computer -ComputerName $env:computername -NewName $computername -ErrorAction Stop | Out-Null
        Write-Host "Computer name set to $($computername)" -ForegroundColor Green

        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy' -Name 'EnableNT4Cryptography' -Value 1 -ErrorAction Stop
        Write-Host "Enabled NT4-compatible cryptography algorithms" -ForegroundColor Green

        Write-Host "Enabling FIPS-compliant algorithms" -ForegroundColor Yellow
        $fipsPolicyValue = "Enabled"
        $fipsPolicyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy"
        Set-ItemProperty -Path $fipsPolicyPath -Name "Enabled" -Value $fipsPolicyValue -ErrorAction Stop

        New-ItemProperty -Path $RegPath -Name "FirstStep" -Value "1" -PropertyType "String" -Force
        Write-Host "First Step Complete"

       Restart-Computer -Force -Confirm:$false -ErrorAction Stop
    } catch {
        Write-Warning -Message $("Failed to complete basic server configuration. Error: " + $_.Exception.Message)
        exit
    }
}

$secondcheck = Get-ItemProperty -Path $RegPath -Name "SecondStep" -ErrorAction SilentlyContinue
if (!$secondcheck) {
    Write-Host "Second Step hasn't finished" -ForegroundColor Yellow
    try {
        Write-Host "Installing Active Directory Domain Services" -ForegroundColor Yellow
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
        Write-Host "Active Directory Domain Services installed successfully" -ForegroundColor Green

        Write-Host "Creating new domain" -ForegroundColor Yellow
        Install-ADDSForest -DomainName $domainname -DomainNetbiosName $domainNetbiosName -InstallDNS -SafeModeAdministratorPassword (Read-Host -AsSecureString "Enter dsrm password") -Confirm:$false | Out-Null
        Write-Host "New domain created successfully" -ForegroundColor Green

        New-ItemProperty -Path $RegPath -Name "SecondStep" -Value "1" -PropertyType "String" -Force
        Write-Host "Active Directory Built, step complete" -ForegroundColor Green

        Restart-Computer -ComputerName $env:computername -ErrorAction Stop
    } catch {
        Write-Warning "Failed to complete Active Directory configuration. Error: $($_.Exception.Message)"
        exit
    }
}

$serverpdc = Get-AdDomainController -Filter * | Where-Object {$_.OperationMasterRoles -contains "PDCEmulator"}
if ($serverpdc) {
    try {
        Start-Process -FilePath "C:\Windows\System32\w32tm.exe" -ArgumentList "/config /manualpeerlist:$($ntpserver1),$($ntpserver2) /syncfromflags:MANUAL /reliable:yes /update" -ErrorAction Stop
        Stop-Service w32time -ErrorAction Stop
        Start-Service w32time -ErrorAction Stop
        Write-Host "Successfully set NTP Servers: $($ntpserver1) and $($ntpserver2)" -ForegroundColor Green
    }
    catch {
        Write-Warning -Message $("Failed to set NTP Servers. Error: "+ $_.Exception.Message)
        exit
    }
}