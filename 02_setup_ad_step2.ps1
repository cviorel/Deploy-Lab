Set-Location -Path C:\Temp
. .\00_set-variables.ps1

# DNS Zones
Try {
    Add-DnsServerPrimaryZone -NetworkId $globalSubnet -DynamicUpdate Secure -ReplicationScope Domain -ErrorAction Stop
    Write-Output "Successfully added in $($globalSubnet) as a reverse lookup within DNS"
}
Catch {
    Write-Warning -Message $("Failed to create reverse DNS lookups zone for network $($globalSubnet). Error: " + $_.Exception.Message)
    Break;
}

# Configure DNS Scavenging
$ReverseLookupZone = ($globalSubnet -split ('/'))[0] -replace '^(\d+)\.(\d+)\.(\d+).(\d+)$', '$3.$2.$1.in-addr.arpa'
Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00 -Verbose
Set-DnsServerZoneAging $domainName -Aging $true -RefreshInterval 7.00:00:00 -NoRefreshInterval 7.00:00:00 -Verbose
Set-DnsServerZoneAging $ReverseLookupZone -Aging $true -RefreshInterval 7.00:00:00 -NoRefreshInterval 7.00:00:00 -Verbose
Get-DnsServerScavenging

# Create Active Directory Sites and Services Subnet
Try {
    New-ADReplicationSubnet -Name $globalSubnet -Site "Default-First-Site-Name" -Location $subnetLocation -ErrorAction Stop
    Write-Output "Successfully added Subnet $($globalSubnet) with location $($subnetLocation) in AD Sites and Services"
}
Catch {
    Write-Warning -Message $("Failed to create Subnet $($globalSubnet) in AD Sites and Services. Error: " + $_.Exception.Message)
    Break;
}

# Add NTP settings to PDC
$serverpdc = Get-ADDomainController -Filter * | Where-Object { $_.OperationMasterRoles -contains "PDCEmulator" }

if ($serverpdc) {
    Try {
        Start-Process -FilePath "C:\Windows\System32\w32tm.exe" -ArgumentList "/config /manualpeerlist:$($ntpserver1),$($ntpserver2) /syncfromflags:MANUAL /reliable:yes /update" -ErrorAction Stop
        Stop-Service W32Time -ErrorAction Stop
        Start-Sleep 2
        Start-Service W32Time -ErrorAction Stop
        Write-Output "Successfully set NTP Servers: $($ntpserver1) and $($ntpserver2)"
    }
    Catch {
        Write-Warning -Message $("Failed to set NTP Servers. Error: " + $_.Exception.Message)
        Break;
    }
}

# Update PTR records
$DnsServer = "$env:COMPUTERNAME"
$ForwardLookupZone = "$domainName"
$ReverseLookupZone = ($globalSubnet -split ('/'))[0] -replace '^(\d+)\.(\d+)\.(\d+).(\d+)$', '$3.$2.$1.in-addr.arpa'

# Get all the DNS A Records
$DNSAresources = Get-DnsServerResourceRecord -ZoneName $ForwardLookupZone -RRType A -ComputerName $DnsServer | Where-Object { $_.Hostname -ne "@" -and $_.Hostname -ne "DomainDnsZones" -and $_.Hostname -ne "ForestDnsZones" }
foreach ($DnsA in $DNSAresources) {
    # The reverse lookup domain name. This is the PTR Response
    $ptrDomain = $DnsA.HostName + '.' + $ForwardLookupZone

    # Reverse the IP Address for the name record
    $name = ($DnsA.RecordData.IPv4Address.ToString() -replace '^(\d+)\.(\d+)\.(\d+).(\d+)$', '$4');

    # Add the new PTR record
    Add-DnsServerResourceRecordPtr -Name $name -ZoneName $ReverseLookupZone -ComputerName $DnsServer -PtrDomainName $ptrDomain
}

# gMSA
Install-WindowsFeature RSAT-ADDS

Add-KdsRootKey –EffectiveTime ((Get-Date).AddHours(-10)) # DON'T DO THIS IN PRODUCTION !!!
Get-KdsRootKey
