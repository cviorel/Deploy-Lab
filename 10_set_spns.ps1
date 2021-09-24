Set-Location -Path C:\Temp
. .\00_set-variables.ps1

# Verify Running as Administrator
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
}

#region create SPNs
$dc = (Get-ADDomainController -Filter *).Name

$sqlserviceuser = @()
foreach ($node in $sqlNodes.Keys) {
    $sqlserviceuser += ((Get-DbaService -ComputerName $node -InstanceName $SQLInstanceName -Type Engine).StartName).Split('\')[1]
}

$sqlserviceuser = $sqlserviceuser | Sort-Object -Unique
$gMSA_de = Get-ADServiceAccount -Identity $sqlserviceuser -Server $dc -Properties *

if ($gMSA_de) {
        foreach ($node in $sqlNodes.Keys) {
        Set-ADServiceAccount -Identity $gMSA_de -ServicePrincipalNames @{Add = "MSSQLSvc/${node}:${SQLInstancePort}" } -Server $dc
        Set-ADServiceAccount -Identity $gMSA_de -ServicePrincipalNames @{Add = "MSSQLSvc/${node}:${SQLInstanceName}" } -Server $dc
        Set-ADServiceAccount -Identity $gMSA_de -ServicePrincipalNames @{Add = "MSSQLSvc/${node}.${domainName}:${SQLInstancePort}" } -Server $dc
        Set-ADServiceAccount -Identity $gMSA_de -ServicePrincipalNames @{Add = "MSSQLSvc/${node}.${domainName}:${SQLInstanceName}" } -Server $dc
    }
}

# SPN for the AG Listener
if ($name_ag_listener -ne '' -and $null -ne $name_ag_listener) {
    Set-ADServiceAccount -Identity $gMSA_de -ServicePrincipalNames @{Add = "MSSQLSvc/${name_ag_listener}.${domainName}:${SQLInstancePort}" } -Server $dc
    Set-ADServiceAccount -Identity $gMSA_de -ServicePrincipalNames @{Add = "MSSQLSvc/${name_ag_listener}.${domainName}:${SQLInstanceName}" } -Server $dc
}

Get-ADServiceAccount -Identity $sqlserviceuser -Server $dc -Property ServicePrincipalNames
(Get-ADServiceAccount -Identity $sqlserviceuser -Server $dc -Property ServicePrincipalNames).ServicePrincipalNames
#endregion create SPNs
