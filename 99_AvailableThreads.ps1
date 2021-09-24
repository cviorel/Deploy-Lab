Set-Location -Path C:\Temp
. .\00_set-variables.ps1

$query = @'
IF NOT EXISTS (
		SELECT *
		FROM sysobjects
		WHERE name = 'AvailableThreads'
			AND xtype = 'U'
		)
	CREATE TABLE dbo.AvailableThreads (
		AvailableThreads [int] NULL
		,CollectionTime [datetime2](7) NOT NULL
		)

DECLARE @max INT;

SELECT @max = max_workers_count
FROM sys.dm_os_sys_info;

INSERT INTO dbo.AvailableThreads
SELECT @max - SUM(active_workers_count) AS [AvailableThreads]
	,GETDATE()
FROM sys.dm_os_schedulers
WHERE STATUS = 'VISIBLE ONLINE';
'@

$JobName = 'Available Worker Threads'

foreach ($node in $sqlNodes.Keys) {
    $sqlInstance = "$node,$SQLInstancePort"
    $jobExists = Get-DbaAgentJob -SqlInstance $sqlInstance -Job $JobName
    if ($jobExists) {
        $jobExists | Remove-DbaAgentJob
    }

    New-DbaAgentJob -SqlInstance $sqlInstance -Job $JobName -Description 'Available Worker Threads' -OwnerLogin sqladmin -Category 'DBA Reports'
    New-DbaAgentJobStep -SqlInstance $sqlInstance -Job $JobName -StepName 'Available Worker Threads' -Subsystem TransactSql -Database DBA -Command $query
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job $JobName -Schedule 'Every 10 seconds' -FrequencyType Daily -FrequencyInterval EveryDay -FrequencySubdayType Seconds -FrequencySubdayInterval 10 -StartTime 000000 -Force
}
