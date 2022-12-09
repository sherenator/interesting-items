#Convert dynamic mac addreess to static
#Usage example: .\dynamicmac2staticmac.ps1 -ComputerName HypervHostName -VMName dev-rabbit1 -Execute -Verbose
[CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ComputerName,
        [string]$VMName = '*',
        [switch]$ListCommands,
        [switch]$Execute
    )
get-vm -ComputerName $ComputerName -Name $VMName | select -ExpandProperty network* | ?{$_.DynamicMacAddressEnabled -eq $True} |`  
%{

if ($ListCommands)
{
write-host "Set-VMNetworkAdapter -ComputerName $ComputerName -VMName `"$($_.VMName)`" -StaticMacAddress `"$($_.MacAddress)`""
}

if ($Execute)
{
Write-Verbose "Stopping VM: $($_.VMName)"
Stop-VM -ComputerName $ComputerName -Name $($_.VMName)
Write-Verbose "Setting MAC address to static"
Set-VMNetworkAdapter -ComputerName $ComputerName -VMName $($_.VMName) -StaticMacAddress $($_.MacAddress)
Write-Verbose "Starting VM: $($_.VMName)"
Start-VM -ComputerName $ComputerName -Name $($_.VMName)
}
}