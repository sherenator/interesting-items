#CLI usage: d:\code\operationsscripts\netscaler_backup.ps1 -NetscalerEndpoint qa.corp.io -NetscalerUsername nsroot -NetscalerPassword <password> -Push $true
#build server usage: .\netscaler_backup.ps1 -NetscalerEndpoint dev.corp.io -NetscalerUsername nsroot -NetscalerPassword <password> -Push $false -RepoPath . -TarDownloadPath .\backup.tgz -TarOutput .\backup
[CmdletBinding()]
param(

    [Parameter(
        Mandatory = $true )] 
        [string] $NetscalerEndpoints, #Accept one endpoint, or a comma separated list
    [Parameter(
        Mandatory = $true )] 
        [string] $NetscalerUsername,
    [Parameter(
        Mandatory = $true )] 
        [string] $NetscalerPassword,
        [string] $RepoPath = "D:\code\netscaler-config",
        [string] $tarDownloadPath = "C:\backup.tgz",
        [string] $tarOutput = "C:\backup",
        [string] $CommitMessage = "Automatic Netscaler backup",
        [switch] $Push,
        [string] $gitUsername,
        [string] $gitPassword
        
        
)

#Download tar, pscp, and plink
$urls = @{
"http://filesrv02.corp.io/artifacts/tar-1.13-1-bin.exe" = ".\tar-1.13-1-bin.exe";
"http://filesrv02.corp.io/artifacts/plink.exe" = ".\plink.exe";
"http://filesrv02.corp.io/artifacts/pscp.exe" = ".\pscp.exe"
}

$urls.keys | %{Invoke-WebRequest -Uri $_ -OutFile $urls["$_"]}

#install tar
Start-Process -Wait -FilePath ".\tar-1.13-1-bin.exe" -ArgumentList "/verysilent /sp" -PassThru

[array]$NetscalerEndpoints = $NetscalerEndpoints.Split(',').Trim()


foreach ($NetscalerEndpoint in $NetscalerEndpoints)
{
    write-host "************************************"
    write-host "*******  $NetscalerEndpoint ********"
    write-host "************************************"
    echo y |.\plink nsroot@$NetscalerEndpoint -pw $NetscalerPassword "save ns config; sh ns hardware; shell tar cvzf /var/tmp/backup.tgz /flash/nsconfig" 2>&1 | Out-Null
    echo y |.\pscp -pw $NetscalerPassword nsroot@$($NetscalerEndpoint):/var/tmp/backup.tgz $tarDownloadPath 2>&1 | Out-Null
    #tar added as native command in windows 10. Install GnuWin32 version if native version is not present
    if (!$(test-path "$tarOutput"))
    {mkdir "$tarOutput"  2>&1 | Out-Null}
    write-host "tar -xvzf $tarDownloadPath -C $tarOutput"
    tar -xvzf $tarDownloadPath -C $tarOutput 2>&1 | Out-Null
    if (!$(test-path "$RepoPath\$NetscalerEndpoint\"))
    {mkdir "$RepoPath\$NetscalerEndpoint\" 2>&1 | Out-Null}

    write-host "Copying $tarOutput\flash\nsconfig\ns.conf to $RepoPath\$NetscalerEndpoint\"
    Copy-Item "$tarOutput\flash\nsconfig\ns.conf" "$RepoPath\$NetscalerEndpoint\"
   
    Write-Host "Lines including hashed passords are pruned to prevent key rotation from interferring with diff"

    $content = Get-Content "$RepoPath\$NetscalerEndpoint\ns.conf" |
    select -Skip 1 |
    %{$_ -replace "^add authentication ldapAction.*$",""} |
    %{$_ -replace "^add ssl certKey.*$",""} |
    %{$_ -replace "^set lb parameter -useEncryptedPersistenceCookie.*$",""} |
    %{$_ -replace "^set ns rpcNode.*$",""} |
    %{$_ -replace "^set ns encryptionParams.*$",""} |
    %{$_ -replace "^# Last modified by.*$",""} |
    %{$_ -replace "^# Last modified by.*$",""} |
    %{$_ -replace "^set urlfiltering parameter.*$",""}
    Set-Content -Value $content -Encoding utf8 "$RepoPath\$NetscalerEndpoint\ns.conf" -Force -Confirm:$false
}

#cleanup
Remove-Item -Force -Recurse .\backup*
$urls.Values | %{Remove-Item -Force $_}

if ($Push )
    {
        cd $RepoPath
        git commit -am "$CommitMessage"
   
        git push https://$gitUsername`:$gitPassword@gitlab.corp.io/Operations/netscaler-config.git
    }


