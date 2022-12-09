#Get Redis connection info from Windows app servers
[CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$port = 6379,
        [string]$sort ="RAM(Mb)"
    )
$CPUPercent = @{
    Label = 'CPUUsed'
    Expression = {
    $SecsUsed = (New-Timespan -Start $_.StartTime).TotalSeconds
    [Math]::Round($_.CPU * 10 / $SecsUsed)
    }
}
$retval= gwmi -ComputerName localhost -NS 'root\WebAdministration' -class 'WorkerProcess' `
| select PSComputerName, AppPoolName,ProcessId , `
    @{n='RAM(Mb)';e={ [math]::round((Get-Process -Id $_.ProcessId -ComputerName $_.PSComputerName).WorkingSet64 / 1Mb)}}, `
    @{n='Connections';e={ $(get-nettcpconnection -RemotePort $port -OwningProcess $_.ProcessId).count }}, `
    @{n='CPU%';e={ $(get-process -PID $_.ProcessID | select $CPUPercent).CPUUsed }} `
| sort $sort -Descending | ft -AutoSize
return $retval