Set-Location -Path C:\Temp
. .\00_set-variables.ps1

$newCommandFullBackup = @"
EXECUTE [dbo].[DatabaseBackup]`r
@Databases = 'USER_DATABASES',`r
@Directory = N'NUL',`r
@BackupType = 'FULL',`r
@CheckSum = 'Y',`r
@LogToTable = 'N'`r
"@

$newCommandTLogBackup = @"
EXECUTE [dbo].[DatabaseBackup]`r
@Databases = 'USER_DATABASES',`r
@Directory = N'NUL',`r
@BackupType = 'LOG',`r
@CheckSum = 'Y',`r
@LogToTable = 'N'`r
"@

foreach ($node in $sqlNodes.Keys) {
    $sqlInstance = "$node,$SQLInstancePort"
    ":: $sqlInstance"

    # full backup job
    $JobFullBackup = Get-DbaAgentJob -SqlInstance "$sqlInstance" -Job 'DatabaseBackup - USER_DATABASES - FULL'
    foreach ($Step in $JobFullBackup.jobsteps.Where{ $_.Name -eq 'DatabaseBackup - USER_DATABASES - FULL' }) {
        $Step.Command = $newCommandFullBackup
        $Step.Alter()
    }

    # tlog backup job
    $JobTLogBackup = Get-DbaAgentJob -SqlInstance "$sqlInstance" -Job 'DatabaseBackup - USER_DATABASES - LOG'
    foreach ($Step in $JobTLogBackup.jobsteps.Where{ $_.Name -eq 'DatabaseBackup - USER_DATABASES - LOG' }) {
        $Step.Command = $newCommandTLogBackup
        $Step.Alter()
    }

    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'DatabaseBackup - SYSTEM_DATABASES - FULL' -Schedule Daily -FrequencyType Daily -FrequencyInterval Everyday -StartTime 010000 -Force
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'DatabaseBackup - USER_DATABASES - DIFF' -Schedule Weekdays -FrequencyType Weekly -FrequencyInterval Weekdays -StartTime 020000 -Force
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'DatabaseBackup - USER_DATABASES - FULL' -Schedule Sunday -FrequencyType Daily -FrequencyInterval Everyday -StartTime 020000 -Force
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'DatabaseBackup - USER_DATABASES - LOG' -Schedule 'Every_5_Minutes' -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Minutes -FrequencySubdayInterval 5 -StartTime 000000 -Force

    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'DatabaseIntegrityCheck - SYSTEM_DATABASES' -Schedule Saturday -FrequencyType Weekly -FrequencyInterval Saturday -StartTime 210000 -Force
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'DatabaseIntegrityCheck - USER_DATABASES' -Schedule Saturday -FrequencyType Weekly -FrequencyInterval Saturday -StartTime 220000 -Force
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'IndexOptimize - USER_DATABASES' -Schedule Saturday -FrequencyType Weekly -FrequencyInterval Saturday -StartTime 230000 -Force

    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'CommandLog Cleanup' -Schedule Monthly -FrequencyType Monthly -FrequencyInterval 1 -StartTime 060000 -Force
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'Output File Cleanup' -Schedule Monthly -FrequencyType Monthly -FrequencyInterval 1 -StartTime 060000 -Force
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'sp_delete_backuphistory' -Schedule Monthly -FrequencyType Monthly -FrequencyInterval 1 -StartTime 060000 -Force
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job 'sp_purge_jobhistory' -Schedule Monthly -FrequencyType Monthly -FrequencyInterval 1 -StartTime 060000 -Force
}
