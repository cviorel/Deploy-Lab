Set-Location -Path C:\Temp
. .\00_set-variables.ps1

$query = Get-Content -Path .\assets\monitoring.sql -Raw

foreach ($node in $sqlNodes.Keys) {
    $sqlInstance = "$node,$SQLInstancePort"
    $monitoringJobName = 'DBA Monitoring'

    $monitoringJobExists = Get-DbaAgentJob -SqlInstance $sqlInstance -Job $monitoringJobName
    if ($monitoringJobExists) {
        $monitoringJobExists | Stop-DbaAgentJob
        $monitoringJobExists | Remove-DbaAgentJob
    }

    New-DbaAgentJob -SqlInstance $sqlInstance -Job $monitoringJobName -Description 'Logging Activity Using sp_WhoIsActive' -OwnerLogin sqladmin -Category 'DBA Reports'
    New-DbaAgentJobStep -SqlInstance $sqlInstance -Job $monitoringJobName -StepName 'Logging Activity Using sp_WhoIsActive' -Subsystem TransactSql -Database DBA -Command $query
    New-DbaAgentSchedule -SqlInstance $sqlInstance -Job $monitoringJobName -Schedule 'When SQL Server Agent starts' -FrequencyType AgentStart -Force
    Start-DbaAgentJob -SqlInstance $sqlInstance -Job $monitoringJobName
}
