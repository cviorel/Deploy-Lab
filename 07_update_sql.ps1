Set-Location -Path C:\Temp
. .\00_set-variables.ps1

$agNodes = @()
foreach ($node in $sqlNodes.Keys) {
    $agNodes += $node
}

$Credentials = New-Object System.Management.Automation.PSCredential("Administrator", ($SafeModeAdminPassword | ConvertTo-SecureString -AsPlainText -Force))
Update-DbaInstance -ComputerName $agNodes -Restart -Version $cuVersion -Path $cuPath -Credential $Credentials -Confirm:$false
