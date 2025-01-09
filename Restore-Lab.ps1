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

    Write-Host "Error: $($Exception.Message)"
    Clear-Lab
}