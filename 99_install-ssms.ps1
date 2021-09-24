function Install-SSMS {
    <#
    .SYNOPSIS
        Silently Download and Install SQL Server Management Studio (SSMS).

    .DESCRIPTION
        This will download and install the latest available SSMS from Microsoft.

    .PARAMETER LocalFile
        Specifies the path to a local file to install SSMS from.
        If the local file is not the latest released, the user will be prompted to download the latest one available.
        If this parameter is not specified, the latest version will be downloaded and installed from https://aka.ms/ssmsfullsetup

    .PARAMETER InstallAzureDataStudio
        This will prevent the installation of Azure Data Studio

    .PARAMETER WriteLog
        You want to log to a file. It will generate more than a few files :)

    .PARAMETER RemoveDownload
        Removes the downloaded file after the installation.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Force
        If this switch is enabled, the installation will continue even if another version of SSMS is found on the system

    .PARAMETER IgnoreUpdate
        If this switch is enabled, the installation will always use the LocalFile, even if it's an outdated version.
        Only works if LocalFile is specified.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Viorel Ciucu
        Website: https://cviorel.com
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://www.cviorel.com/2017/01/27/silently-download-and-install-sql-server-management-studio-ssms
        https://www.cviorel.com/2020/12/20/sql-server-management-studio-automatically-get-the-latest-version

    .EXAMPLE
        Install-SSMS -WriteLog 1

        Silently downloads and installs latest version of SSMS.
        It will create a log for the installation.

    .EXAMPLE
        Install-SSMS -InstallAzureDataStudio $false -WriteLog $true -LocalFile C:\Users\Administrator\Downloads\SSMS-Setup-ENU.exe

        Silently installs SSMS without Azure Data Studio from the C:\Users\Administrator\Downloads\SSMS-Setup-ENU.exe local file

    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
    param (
        [parameter(Mandatory = $false, ParameterSetName = 'LocalFile')]
        [string]$LocalFile,

        [parameter(Mandatory = $false, ParameterSetName = 'LocalFile')]
        [switch]$IgnoreUpdate,

        [parameter(Mandatory = $false)]
        [bool]$InstallAzureDataStudio = $false,

        [parameter(Mandatory = $false)]
        [bool]$WriteLog = $false,

        [parameter(Mandatory = $false)]
        [bool]$RemoveDownload = $false,

        [parameter(Mandatory = $false)]
        [switch]$Force
    )


    if (-not ($PSBoundParameters.ContainsKey('LocalFile'))) {
        if ($PSBoundParameters.ContainsKey('IgnoreUpdate')) {
            Write-Output "Parameter IgnoreUpdate can be only used with '-LocalFile'"
            break
        }
    }

    $temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\")
    $outFile = "$temp\SSMS-Setup-ENU.exe"

    $argList = @()
    $argList += "/install /quiet /norestart"

    # Check the last version of SSMS
    $uri = 'https://raw.githubusercontent.com/MicrosoftDocs/sql-docs/live/docs/ssms/release-notes-ssms.md'
    $md = Invoke-WebRequest -Uri $uri -UseBasicParsing | Select-Object -ExpandProperty Content

    $regEx = '(- Release number\:\s+(\d+\.)?(\d+\.)?(\d+))|(- Build number\:\s+(\d+\.)(\d+\.)(\d+\.)(\d+))|(- Release date\:\s+(\w+\s+\d{1,2})\,\s+\d{4})'

    $HashTable = @{}
    $index = 1
    $md | Select-String -Pattern $regEx -AllMatches | `
        ForEach-Object { $_.Matches } | `
        ForEach-Object {
        $value = ($_.Value -replace ('-', '')).Trim();
        $HashTable.Add($index, $value);
        $index++
    }

    $lastVersion = @{
        ReleaseNumber = (($HashTable[1] -split (':'))[1]).Trim()
        BuildNumber   = (($HashTable[2] -split (':'))[1]).Trim()
        ReleaseDate   = (($HashTable[3] -split (':'))[1]).Trim()
    }

    $filter = 'Microsoft SQL Server Management Studio'
    $uninstall32 = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -match $filter } | Select-Object DisplayVersion
    $uninstall64 = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -match $filter } | Select-Object DisplayVersion

    if ($uninstall64) {
        $isInstalled = $true
        $installedVersion = $uninstall64.DisplayVersion
    }
    if ($uninstall32) {
        $isInstalled = $true
        $installedVersion = $uninstall32.DisplayVersion
    }

    if ($isInstalled -eq $true) {
        Write-Output "Version $installedVersion was detected on your system!"
        if (-not $Force) {
            $confirmation = Read-Host "Are you sure you want to proceed [y/n]"
            if ($confirmation -notmatch "[yY]") {
                break
            }
        }
    }

    if ($LocalFile.Length -ne 0) {
        if (Test-Path -Path $LocalFile) {
            $existingVersion = (Get-ChildItem -Path $LocalFile).VersionInfo.ProductVersion
            if ($existingVersion -ne $lastVersion.BuildNumber) {
                Write-Output "There is a newer release available: $($lastVersion.ReleaseNumber) ($($lastVersion.ReleaseDate)). We will download it and save it to: $($outFile)"
                if (-not $IgnoreUpdate) {
                    $outdated = $true
                }
            }
        }
        else {
            Write-Output "The local file does not exist. We will download the latest available realease."
            $LocalFile = $null
        }
    }

    if ($null -eq $LocalFile -or $LocalFile.Length -eq 0) {
        if (Test-Path -Path $outFile) {
            $existingVersion = (Get-ChildItem -Path $outFile).VersionInfo.ProductVersion
            if ($existingVersion -ne $lastVersion.BuildNumber) {
                Write-Output "Locally-cached copy exists, but it's outdated. There is a newer version available $($lastVersion.ReleaseNumber) (released on $($lastVersion.ReleaseDate)). We will download it and save it to: $($outFile)"
                $outdated = $true
            }
        }

        if ((Test-Path -Path $outFile) -and (-not $outdated)) {
            Write-Output "Locally-cached copy exists and it's the newest one available, skipping download."
        }
        else {
            if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Downloading latest SSMS to $outFile")) {
                try {
                    # Create SSL/TLS secure channel
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                    # Start the download
                    $url = "https://aka.ms/ssmsfullsetup"

                    try {
                        $ProgressPreference = "SilentlyContinue"
                        Invoke-WebRequest $url -OutFile $outFile -UseBasicParsing
                    }
                    catch {
                        (New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                        Invoke-WebRequest $url -OutFile $outFile -UseBasicParsing
                    }
                }
                catch {
                    Write-Output "Download failed. Please download manually from $url."
                    return
                }
            }
        }
    }

    if ($InstallAzureDataStudio -eq $false) {
        $argList += "DoNotInstallAzureDataStudio=1"
    }

    if ($WriteLog -eq $true) {
        $logFile = "$temp\SSMS_$(Get-Date -Format `"yyyyMMddHHmm`").txt"
        $argList += "/log $logFile"
        Write-Output "InstallationLog: $logFile"
    }

    # Start the install
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Installing latest SSMS from $outFile")) {
        # Closing running SSMS processes
        if (Get-Process 'Ssms' -ErrorAction SilentlyContinue) {
            Stop-Process -Name Ssms -Force -ErrorAction SilentlyContinue
        }

        # Install silently
        if (Test-Path $outFile) {
            if ($outFile.EndsWith("exe")) {
                Write-Output "Performing silent install..."
                $process = Start-Process -FilePath $outFile -ArgumentList $argList -Wait -Verb RunAs -PassThru

                if ($process.ExitCode -ne 0) {
                    Write-Output "$_ exited with status code $($process.ExitCode). Check the error code here: https://docs.microsoft.com/en-us/windows/win32/msi/error-codes"
                }
                else {
                    Write-Output "Instalation was sucessfull!"
                }
            }
        }
        else {
            Write-Output "$outFile does not exist. Probably the download failed."
        }
    }

    # Cleanup
    if ($RemoveDownload -eq $true) {
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Removing the installation file $outFile")) {
            Remove-Item $outFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Install-SSMS -InstallAzureDataStudio $false -WriteLog $true -LocalFile 'C:\Temp\SSMS-Setup-ENU.exe'
