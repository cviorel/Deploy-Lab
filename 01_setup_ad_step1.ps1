Set-Location -Path C:\Temp
. .\00_set-variables.ps1

# Networking
$interfaceIndex = $(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "Ethernet*" }).InterfaceIndex
Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses 127.0.0.1, 192.168.1.105

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Add-WindowsFeature RSAT-AD-Powershell

# Create Active Directory Forest
Install-ADDSForest `
    -DomainName "$domainName" `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "7" `
    -DomainNetbiosName $domainName.Split('.')[0] `
    -ForestMode "7" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$True `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true `
    -SafeModeAdministratorPassword $($SafeModeAdminPassword | ConvertTo-SecureString -AsPlainText -Force)

Get-Service adws, kdc, Netlogon, dns
Restart-Computer -Force
