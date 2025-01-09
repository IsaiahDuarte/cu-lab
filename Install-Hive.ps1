    # Install Hive
    Install-LabSoftwarePackage -Path (Get-Item -Path "$LabSources\SoftwarePackages\hive*.exe")[0].FullName -ComputerName $Config.GetHives().Name -CommandLine ('/VERYSILENT /LOG="C:\setup_log_sb.log" /DIR="C:\Program Files\Scoutbees Custom Hive" /name="ScoutbeesCustomHive" /SUPPRESSMSGBOXES ' + '/token="' + $Config.ScoutbeesKey + '"')  
