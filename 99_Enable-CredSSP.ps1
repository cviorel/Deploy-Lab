function Enable-CredSSP {
    <#
.SYNOPSIS
    Enables and configures CredSSP Authentication to be used in PowerShell remoting sessions

.DESCRIPTION
    Enabling CredSSP allows a caller from one remote session to authenticate on other remote
    resources. This is known as credential delegation. By default, PowerShell sessions do not
    use credSSP and therefore cannot bake a "second hop" to use other remote resources that
    require their authentication token.


    This command will enable CredSSP and add all RemoteHostsToTrust to the CredSSP trusted
    hosts list. It will also edit the users group policy to allow Fresh Credential Delegation.

.PARAMETER RemoteHostsToTrust
    A list of ComputerNames to add to the CredSSP Trusted hosts list.

.OUTPUTS
    A list of the original trusted hosts on the local machine.

.EXAMPLE
    Enable-CredSSP tf-node1, tf-node2, tf-node3

#>
    param(
        [string[]] $RemoteHostsToTrust
    )
    $Result = @{
        Success                              = $False;
        PreviousCSSPTrustedHosts             = $null;
        PreviousFreshCredDelegationHostCount = 0
    }

    Write-Output "Configuring CredSSP settings..."
    $credssp = Get-WSManCredSSP

    $ComputersToAdd = @()
    $idxHosts = $credssp[0].IndexOf(": ")

    if ($idxHosts -gt -1) {
        $Result.PreviousCSSPTrustedHosts = $credssp[0].substring($idxHosts + 2)
        $hostArray = $Result.PreviousCSSPTrustedHosts.Split(",")
        $RemoteHostsToTrust | Where-Object { $hostArray -notcontains "wsman/$_" } | ForEach-Object { $ComputersToAdd += $_ }
    }
    else {
        $ComputersToAdd = $RemoteHostsToTrust
    }

    if ($ComputersToAdd.Count -gt 0) {
        Write-Output "Adding $($ComputersToAdd -join ',') to allowed credSSP hosts"
        try {
            Enable-WSManCredSSP -DelegateComputer $ComputersToAdd -Role Client -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Output "Enable-WSManCredSSP failed with: $_"
            return $result
        }
    }

    $key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows"
    if (!(Test-Path "$key\CredentialsDelegation")) {
        New-Item $key -Name CredentialsDelegation | Out-Null
    }
    $key = Join-Path $key "CredentialsDelegation"
    New-ItemProperty -Path "$key" -Name "ConcatenateDefaults_AllowFresh" -Value 1 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path "$key" -Name "ConcatenateDefaults_AllowFreshNTLMOnly" -Value 1 -PropertyType Dword -Force | Out-Null

    $result.PreviousFreshNTLMCredDelegationHostCount = Set-CredentialDelegation $key 'AllowFreshCredentialsWhenNTLMOnly' $RemoteHostsToTrust
    $result.PreviousFreshCredDelegationHostCount = Set-CredentialDelegation $key 'AllowFreshCredentials' $RemoteHostsToTrust

    $Result.Success = $True
    return $Result
}

function Set-CredentialDelegation($key, $subKey, $allowed) {
    New-ItemProperty -Path "$key" -Name $subKey -Value 1 -PropertyType Dword -Force | Out-Null
    $policyNode = Join-Path $key $subKey
    if (!(Test-Path $policyNode)) {
        New-Item -Path $policyNode | Out-Null
    }
    $currentHostProps = @()
    (Get-Item $policyNode).Property | ForEach-Object {
        $currentHostProps += (Get-ItemProperty -Path $policyNode -Name $_).($_)
    }
    $currentLength = $currentHostProps.Length
    $idx = $currentLength
    $allowed | Where-Object { $currentHostProps -notcontains "wsman/$_" } | ForEach-Object {
        $idx++
        New-ItemProperty -Path $policyNode -Name "$idx" -Value "wsman/$_" -PropertyType String -Force | Out-Null
    }

    return $currentLength
}
