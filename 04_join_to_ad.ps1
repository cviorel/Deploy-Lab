Set-Location -Path C:\Temp
. .\00_set-variables.ps1
. .\99_Enable-CredSSP.ps1

if ($($sqlNodes.Keys) -contains $env:COMPUTERNAME) {
    $servicesToInstall = @(
        'RSAT-AD-PowerShell',
        'Failover-Clustering'
    )
    Install-WindowsFeature -Name $servicesToInstall -IncludeManagementTools -IncludeAllSubFeature
}

if ($($managementNodes.Keys) -contains $env:COMPUTERNAME) {
    $servicesToInstallMGMT = @(
        'Failover-Clustering',
        'RSAT-AD-Tools',
        'RSAT-DHCP',
        'RSAT-DNS-Server',
        'NET-Framework-Core'
    )

    Install-WindowsFeature -Name $servicesToInstallMGMT -IncludeManagementTools -IncludeAllSubFeature
}

$interfaceIndex = $(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "Ethernet*" }).InterfaceIndex
Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses $($domainControllers.Values)

Set-DnsClient -InterfaceIndex $interfaceIndex -ConnectionSpecificSuffix $domainName -RegisterThisConnectionsAddress:$true -UseSuffixWhenRegistering:$true
Set-DnsClientGlobalSetting -SuffixSearchList "$domainName"

$trustedHosts = @()
$trustedHosts += $($sqlNodes.Keys)
$trustedHosts += $($managementNodes.Keys)

$trustedHostsFQDN = $trustedHosts | ForEach-Object {
    $_ + ".${domainName}"
}

Enable-CredSSP -RemoteHostsToTrust $trustedHostsFQDN

Set-Item –Path WSMan:\localhost\Client\TrustedHosts -Value "*.${domainName}" -Force

# https://docs.microsoft.com/en-US/troubleshoot/windows-server/networking/guest-access-in-smb2-is-disabled-by-default
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name AllowInsecureGuestAuth
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name AllowInsecureGuestAuth -Value 1

$isJoined = (Get-CimInstance -ClassName Win32_computersystem).PartOfDomain
if ($isJoined -eq $false) {
    $domainAdminCreds = New-Object System.Management.Automation.PSCredential("Administrator@$domainName", ($SafeModeAdminPassword | ConvertTo-SecureString -AsPlainText -Force))
    Add-Computer -DomainName $domainName -Credential $domainAdminCreds -Restart
}
