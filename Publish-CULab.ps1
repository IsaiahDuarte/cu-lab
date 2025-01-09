param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $ConfigPath
)

try {
    Start-Transcript -Path "$PSScriptRoot\Build.txt" -Append -Force
    # Ill put these in a module later.
    Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' | Where-Object { $_.name -ne 'old.ps1' -and $_.name -ne 'Publish-CULab.ps1' } | ForEach-Object { Import-Module $_.FullName -Force }
    
    # Ensure necessary components are installed and configured
    Confirm-HyperV
    Confirm-RequiredModules

    # Import configuration
    Write-ScreenInfo "Importing Config"
    $Config = [CUConfig]::new()
    $Config.ImportFromJson($ConfigPath)
    Confirm-LabSources -DriveLetter $Config.DriveLetter | Out-Null

    # Set up the lab and install services
    New-CULab -Config $Config
    
    Get-LabDefinition
    Install-Lab

    Checkpoint-LabVM -All -SnapshotName "Before CU Products"
    
    # Install-MonitorService -Config $Config
    # Install-AgentService -Config $Config
    # Install-Hive -Config $Config
    # Install-EdgeDX -Config $Config

    Send-ALNotification -Activity 'ControlUp Configuration Complete' -Message "Installed configuration" -Provider 'Toast'
    Show-LabDeploymentSummary -Detailed
}
catch {
    Restore-Lab $_.Exception
}
finally {
    Stop-Transcript
}