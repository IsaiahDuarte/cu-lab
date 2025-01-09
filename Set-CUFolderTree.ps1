    # Build the FolderTree based on config
    $FolderTable = [ordered]@{}
    $FolderTable["$($Config.OrgName)"] = @($Config.LabName)
    $LabFolder = "$($Config.OrgName)\$($Config.LabName)"
    $FolderTable[$LabFolder] = @()
    
    foreach ($Monitor in $Config.GetMonitors()) {        
        if ($FolderTable[$LabFolder] -notcontains $Monitor.DomainName) {
            $FolderTable[$LabFolder] += $Monitor.DomainName
        }
        
        $DomainPath = "$LabFolder\$($Monitor.DomainName)"
        if (-not $FolderTable.Contains($DomainPath)) {
            $FolderTable[$DomainPath] = @()
        }
        
        if($FolderTable[$DomainPath] -notcontains "Agent") {
            $FolderTable[$DomainPath] += "Agent"
        }

        if($FolderTable[$DomainPath] -notcontains "Monitor") {
            $FolderTable[$DomainPath] += "Monitor"
        }
    }

    # Compress folders to pass to psexec
    $FolderList = New-Object System.Collections.Generic.List[string]
    foreach($key in $FolderTable.Keys) {
        if($FolderTable[$key].Count -gt 1) {
            $FolderTable[$key].ForEach({$FolderList.Add(($key + "\" + $_))})
            continue
        } 
        $FolderList.Add(($key + "\" + $FolderTable[$key]))
    }
    
    # Map monitor loaction 
    $MonitorList = New-Object System.Collections.Generic.List[string]
    foreach($Monitor in $Config.GetMonitors()) {
        $MonitorList.Add(("$($Config.OrgName)\$($Config.LabName)\$($Monitor.DomainName)\Monitor\$($Monitor.Name)"))
    }

    $MonitorToExecute = $Config.GetMonitors()[0].Name
    $FolderList | ConvertTo-Json | Out-File .\folderlist.json
    $MonitorList | ConvertTo-Json | Out-File .\monitorlist.json
    Copy-LabFileItem -Path .\folderlist.json -ComputerName $MonitorToExecute -DestinationFolderPath "C:\scripts\"
    Copy-LabFileItem -Path .\monitorlist.json -ComputerName $MonitorToExecute -DestinationFolderPath "C:\scripts\"

    Remove-Item .\folderlist.json
    Remove-Item .\monitorlist.json

    Invoke-LabCommand -ComputerName $MonitorToExecute -ActivityName 'Moving ControlUp Monitor Object' -ScriptBlock {
        $Arguments = ("/accepteula -s Powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Setup-Tree.ps1")
        Start-Process -FilePath "C:\psexec.exe" -ArgumentList $Arguments -Wait -RedirectStandardOutput 'C:\scripts\psexec-setup-tree.log' -RedirectStandardError 'C:\scripts\psexec-error-setup-tree.log'
    }