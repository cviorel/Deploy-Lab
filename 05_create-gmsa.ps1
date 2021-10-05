Set-Location -Path C:\Temp
. .\00_set-variables.ps1

$nodeList = @($sqlNodes.Keys)

$dc = (Get-ADDomainController -Filter *).Name
$fqdn = Get-ADDomain -Server $dc

$serviceAccounts = @(
    $EngineAccountName,
    $AgentAccountName
)

$allowedHosts = Get-ADComputer -Filter * -Server $fqdn.Forest | Where-Object { $_.Name -in $nodeList }
if ($null -eq $allowedHosts) {
    throw "$nodeList are not joined to the domain!"
}
$domainAdminCreds = New-Object System.Management.Automation.PSCredential("Administrator@$domainName", ($SafeModeAdminPassword | ConvertTo-SecureString -AsPlainText -Force))

foreach ($service in $serviceAccounts) {
    try {
        $exists = Get-ADServiceAccount -Identity $service
    }
    catch {
    }

    if ($null -eq $exists) {
        try {
            $newAccount = New-ADServiceAccount -Name $service -PrincipalsAllowedToRetrieveManagedPassword $allowedHosts -Enabled:$true `
                -DNSHostName "${service}.$($fqdn.Forest)" -SamAccountName $service -ManagedPasswordIntervalInDays 30 `
                -Description "gMSA for the $($SQLInstanceName) instance $($service) on $($ClusterCNO) Cluster" `
                -TrustedForDelegation:$false `
                -KerberosEncryptionType AES128, AES256 `
                -Server $fqdn.Forest `
                -Credential $domainAdminCreds `
                -PassThru

            $newAccount | Select-Object *
        }
        catch {
        }
    }
    else {
        Write-Output "Service account $service already exist. Nothing to do."
    }
}
