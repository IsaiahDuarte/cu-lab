function Install-CustomHive {
    param(
        [Parameter(Mandatory = $true)]
        [CUConfig] $Config
    )

    Install-Module -Name ControlUp.Automation -SkipPublisherCheck -Scope AllUsers
    
    foreach($domain in $Config.Domains) {
        Set-LabInstallationCredential -Username $domain.Username -Password $domain.Password
        Install-LabSoftwarePackage -Path (Get-Item -Path "$LabSources\SoftwarePackages\hive*.exe")[0].FullName -ComputerName $Config.GetHives($domain.Name).Name -CommandLine ('/VERYSILENT /LOG="C:\setup_log_sb.log" /DIR="C:\Program Files\Scoutbees Custom Hive" /SUPPRESSMSGBOXES ' + '/token="' + $Config.ScoutbeesKey + '"')  
    }
}

