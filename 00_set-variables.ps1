#region VMs
$domainControllers = @{
    'tf-dc01' = "192.168.1.81"
}

$sqlNodes = @{
    'tf-node01' = "192.168.1.82"
    'tf-node02' = "192.168.1.83"
    'tf-node03' = "192.168.1.84"
}

$managementNodes = @{
    'tf-mgmt01' = "192.168.1.85"
}
#endregion VMs

#region AD
$globalSubnet = '192.168.1.0/24'

# NTP Variables
$ntpserver1 = '0.be.pool.ntp.org'
$ntpserver2 = '1.be.pool.ntp.org'

$subnetLocation = 'Brussels,Belgium'
$timeZone = 'Romance Standard Time'

$domainName = 'lab.local'
$domainNameShort = (($domainName.Split('.'))[0]).ToUpper()
$SafeModeAdminPassword = 'SecretPa$$word'
$LocalAdminPassword = 'SecretPa$$word'
#endregion AD

#region WFC
$cluster_name = 'dbcluster'
$ClusterCNO = 'SQLClu'
$ClusterIP = '192.168.1.99'
#endregion WFC

#region SQL
$SQLVersion = 2019
$SQLInstanceName = 'SQL1'
$SQLInstancePort = 10001
$dacSQLInstancePort = '2000' + $SQLInstanceName.Substring($($SQLInstanceName.Length) - 1, 1)
$db_folder_data = 'SQLData'
$db_folder_log = 'SQLLog'
$db_folder_backup = 'SQLBackup'
$db_name = 'TestDB'
$sa_password = 'SecretPa$$word'
$EngineAccountName = "svc_${SQLInstanceName}_de"
$AgentAccountName = "svc_${SQLInstanceName}_ag"
$sqlCollation = 'SQL_Latin1_General_CP1_CI_AS'
$SQLSYSADMINACCOUNTS = @("$domainNameShort\Administrator")


switch ($SQLVersion) {
    2016 {
        $setupPath = "\\192.168.1.250\data\SQL2016SP2\SQLServer2016-x64-ENU"
        $cuVersion = "SQL2016SP2CU17"
        $cuPath = "\\192.168.1.250\data\SQL2016SP2\CU17\SQLServer2016-KB5001092-x64.exe"
    }
    2017 {
        $setupPath = "\\192.168.1.250\data\SQL2017\SQLServer2017-x64-ENU"
        $cuVersion = "SQL2017CU24"
        $cuPath = "\\192.168.1.250\data\SQL2017\CU24\SQLServer2017-KB5001228-x64.exe"
    }
    2019 {
        $setupPath = "\\192.168.1.250\data\SQL2019\SQLServer2019-x64-ENU"
        $cuVersion = "SQL2019CU12"
        $cuPath = "\\192.168.1.250\data\SQL2019\CU12\SQLServer2019-KB5004524-x64.exe"
    }
}
#endregion SQL

#region Availability Group
$name_ag = 'cluster-ag'
$name_ag_listener = 'ag-listener'
$ag_listener_ip = '192.168.1.199'
#endregion Availability Group
