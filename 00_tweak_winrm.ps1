# https://www.techpaste.com/2016/07/unexpected-http-response-500-winrm-rundeck/

# winrm set winrm/config '@{ MaxEnvelopeSizekb = "4294967295" }'
# winrm set winrm/config '@{ MaxTimeoutms = "4294967295" }'
# winrm set winrm/config '@{ MaxBatchItems = "4294967295" }'

# winrm set winrm/config/Service '@{ MaxConcurrentOperations = "4294967295" }'
# winrm set winrm/config/Service '@{ MaxConcurrentOperationsPerUser = "4294967295" }'
# winrm set winrm/config/service '@{ EnumerationTimeoutms = "4294967295" }'
# winrm set winrm/config/service '@{ MaxConnections = "50" }'
# winrm set winrm/config/service '@{ MaxPacketRetrievalTimeSeconds = "4294967295" }'
# winrm set winrm/config/service/auth '@{ CredSSP = "True"}'

# winrm set winrm/config/client '@{ TrustedHosts = "*" }'
# winrm set winrm/config/client '@{ NetworkDelayms = "4294967295" }'

# winrm set winrm/config/winrs '@{ IdleTimeout = "2147483647" }'
# winrm set winrm/config/winrs '@{ MaxConcurrentUsers = "100" }'
# winrm set winrm/config/winrs '@{ MaxShellRunTime = "2147483647" }'
# winrm set winrm/config/winrs '@{ MaxProcessesPerShell = "5000" }'
# winrm set winrm/config/winrs '@{ MaxShellsPerUser = "5000" }'
# winrm set winrm/config/winrs '@{ AllowRemoteShellAccess = "True" }'
# winrm set winrm/config/winrs '@{ MaxMemoryPerShellMB = "2048" }'

# Reset WinRM
# winrm invoke restore winrm/config '@{}'
# winrm invoke restore winrm/config/plugin '@{}'

Set-Item -Path WSMan:\localhost\Shell\MaxShellsPerUser -Value 50
Set-Item -Path WSMan:\localhost\Shell\MaxProcessesPerShell -Value 1000
Set-Item -Path WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 2048
Set-Item -Path WSMan:\localhost\Plugin\Microsoft.PowerShell\Quotas\MaxMemoryPerShellMB -Value 2048
Set-Item -Path WSMan:\localhost\MaxTimeoutms -Value 7200000

Restart-Service -Name WinRM -Force

# Display configuration
$winrs = & winrm get winrm/config/winrs |
    Select-Object -Skip 1 |
    Out-String |
    ConvertFrom-StringData
$winrs
