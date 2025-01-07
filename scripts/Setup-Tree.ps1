param(
    [string] $json
)
Start-Transcript -Path C:\scripts\AutomatedLab-Setup-Tree.log -Append
Write-Host $json
$Config = ConvertFrom-Json $json

Write-Host "Importing ControlUp Monitor Modules"
$pathToUserModule = (Get-ChildItem "C:\Program Files\Smart-X\ControlUpMonitor\*ControlUp.PowerShell.User.dll" -Recurse | Sort-Object LastWriteTime -Descending)[0]
$pathToMonitorModule = (Get-ChildItem "C:\Program Files\Smart-X\ControlUpMonitor\*ControlUp.PowerShell.Monitor.dll" -Recurse | Sort-Object LastWriteTime -Descending)[0]
Import-Module $pathToUserModule, $pathToMonitorModule

Write-Host "Creating folder structure"
Add-CUFolder -Name $Config.LabName -ParentPath "$($Config.OrgName)\" -Description 'Generated by AutomatedLab'

foreach($Domain in $Domains) {
    $DomainPath = "$($Config.OrgName)\$($Config.LabName)\$($Domain.Name)"
    Add-CUFolder -Name $Domain.Name -ParentPath "$($Config.OrgName)\$($Config.LabName)"
    Add-CUFolder -Name Agents -ParentPath $DomainPath
    Add-CUFolder -Name Monitors -ParentPath $DomainPath
}

Write-Host "Creating Batch"

$Batch = New-CUBatchUpdate
foreach($Monitor in ($Config.VirtualMachines.Where({$_.Monitor -eq $true}))) {
    $Path = "$($Config.OrgName)\$($Config.LabName)\$($Monitor.DomainName)\Monitors"
    Write-Host "Moving $($Monitor.Name) to $Path"
    Move-CUComputer -Name $Monitor -FolderPath $Path -Batch $Batch
}

Write-Host "Publishing Updates"
Publish-CUUpdates -Batch $Batch
Stop-Transcript