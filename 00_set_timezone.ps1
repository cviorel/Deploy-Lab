
Set-Location -Path C:\Temp
. .\00_set-variables.ps1

$currentTimeZone = (Get-TimeZone).Id

if ($timeZone) {
    if ($currentTimeZone -ne $timeZone) {
        Set-TimeZone -Id $timeZone
    }
}
