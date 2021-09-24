# Deploy-Lab

```powershell
if (!(Test-Path -Path 'C:\Temp')) {
    New-Item -Path 'C:\Temp' -ItemType Directory | Out-Null
}

$temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\")
$zipfile = "$temp\main.zip"
$rnd = Get-Random

Invoke-RestMethod -Uri 'https://api.github.com/repos/cviorel/Deploy-Lab/zipball' -OutFile $zipfile

Unblock-File -Path $zipfile -Confirm:$false
Expand-Archive -Path $zipfile -DestinationPath "$temp\$rnd"

$unzipped = (Get-ChildItem -Path "$temp\$rnd" -Directory).FullName
Copy-Item -Path $unzipped\* -Recurse -Destination C:\Temp -Force

Remove-Item -Path $zipfile -Force | Out-Null
Remove-Item -Path "$temp\$rnd" -Recurse | Out-Null

Set-Location -Path C:\Temp
```
