function Confirm-LabSources {
    <#
    .SYNOPSIS
    Checks that lab sources are configured correctly.

    .PARAMETER DriveLetter
    The drive letter where LabSources should be located.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $DriveLetter
    )

    # I want to automate some of this.
    Write-Host "Checking if Lab Sources are configured"
    if ((Get-LabSourcesLocation -Local) -notcontains "$($DriveLetter):\LabSources") {
        New-LabSourcesFolder -DriveLetter $DriveLetter -Force
        $folder = "$($DriveLetter):\LabSources"
        Clear-Host
        Write-Host -ForegroundColor 'White' "Please copy the following to $folder and press enter to continue"
        Write-Host -ForegroundColor 'Yellow' "Download Windows Server 2022 and place ISO here - $folder\ISOs"
        Write-Host -ForegroundColor 'Yellow' "Download Windows 11 ISO and place here - $folder\ISOs"
        Write-Host -ForegroundColor 'Yellow' "Download ControlUp Console and place here - $folder\SoftwarePackages"
        Write-Host -ForegroundColor 'Yellow' "Download Hive and place here - $folder\SoftwarePackages"
        Write-Host -ForegroundColor 'Yellow' "Download agentmanagersetup.msi and place here - $folder\SoftwarePackages"
        Read-Host -Prompt "Press Enter to continue after copying files"
    }
    $LabLocation = Get-LabSourcesLocation -Local | Where-Object { $_ -like "$($DriveLetter):\*" }
    Write-Host "Lab location is $LabLocation"
    return $LabLocation
}