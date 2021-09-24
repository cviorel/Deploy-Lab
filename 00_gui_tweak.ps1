# Run this on the systems that are running the GUI version of Windows
$isCore = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallationType -eq "Server Core"

if ($isCore -eq $false) {
    Write-Output "Disabling Server Manager auto-start"
    $serverManagerMachineKey = "HKLM:\SOFTWARE\Microsoft\ServerManager"
    $serverManagerUserKey = "HKCU:\SOFTWARE\Microsoft\ServerManager"
    if (Test-Path $serverManagerMachineKey) {
        Set-ItemProperty -Path $serverManagerMachineKey -Name "DoNotOpenServerManagerAtLogon" -Value 1
    }
    if (Test-Path $serverManagerUserKey) {
        Set-ItemProperty -Path $serverManagerUserKey -Name "CheckedUnattendLaunchSetting" -Value 0
    }

    Write-Output "Disabling Internet Explorer ESC"
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    if ((Test-Path $AdminKey) -or (Test-Path $UserKey)) {
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
        Stop-Process -Name Explorer -ErrorAction SilentlyContinue
    }
} else {
    Write-Verbose ":: Nothing to do!"
}
