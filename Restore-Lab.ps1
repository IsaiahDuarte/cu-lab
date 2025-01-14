function Restore-Lab {
    <#
    .SYNOPSIS
    Cleans the lab if there is an exception.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Exception] $Exception
    )

    Write-ScreenInfo "Error: $($Exception.Message)"
    Clear-Lab

    # Maybe ill do more here with -force and delete the lab folders, restore host file, delete adapters
}