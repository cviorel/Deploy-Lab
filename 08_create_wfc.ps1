Set-Location -Path C:\Temp
. .\00_set-variables.ps1

# Verify Running as Administrator
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
}

# Create the cluster
New-Cluster -Name $ClusterCNO -Node $($sqlNodes.Keys) `
    -StaticAddress $ClusterIP `
    -NoStorage

$allowedAccounts = @()
$allowedAccounts += (Get-ADComputer -Identity $ClusterCNO).SamAccountName

foreach ($node in $sqlNodes.Keys) {
    $allowedAccounts += (Get-ADComputer -Identity $node).SamAccountName
}

Invoke-Command -ComputerName $($domainControllers.Keys) -ScriptBlock {
    $fileShareWitness = 'C:\WFC'
    New-Item -Path $fileShareWitness -ItemType Directory -Force | Out-Null
    New-SmbShare -Name WFC -Path $fileShareWitness -FullAccess $using:allowedAccounts
    Start-Process -FilePath "icacls.exe" -ArgumentList """$fileShareWitness"" /grant ""${domainNameShort}\${ClusterCNO}$"":(OI)(CI)(F) /C" -NoNewWindow -Wait
}

# Execute this on one of the member nodes of the cluster
$cluster = Get-Cluster -Name $ClusterCNO
$cluster | Set-ClusterQuorum -NodeAndFileShareMajority "\\$($domainControllers.Keys)\WFC"
