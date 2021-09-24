SET NOCOUNT ON;

DECLARE @retention INT = 3
	,@destination_table VARCHAR(500) = 'WhoIsActive'
	,@destination_database SYSNAME = 'DBA'
	,@schema VARCHAR(max)
	,@SQL NVARCHAR(4000)
	,@parameters NVARCHAR(500)
	,@exists BIT;

SET @destination_table = @destination_database + '.dbo.' + @destination_table;

-- create the logging table
IF OBJECT_ID(@destination_table) IS NULL
BEGIN
	EXEC dbo.sp_WhoIsActive @get_transaction_info = 1
		,@get_outer_command = 1
		,@get_plans = 1
		,@return_schema = 1
		,@schema = @schema OUTPUT;

	SET @schema = REPLACE(@schema, '<table_name>', @destination_table);

	EXEC (@schema);
END

-- create index on collection_time
SET @SQL = 'USE ' + QUOTENAME(@destination_database) + '; IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(@destination_table) AND name = N''cx_collection_time'') SET @exists = 0';
SET @parameters = N'@destination_table varchar(500), @exists bit OUTPUT';

EXEC sp_executesql @SQL
	,@parameters
	,@destination_table = @destination_table
	,@exists = @exists OUTPUT;

IF @exists = 0
BEGIN
	SET @SQL = 'CREATE CLUSTERED INDEX cx_collection_time ON ' + @destination_table + '(collection_time ASC)';
	EXEC (@SQL);
END

-- collect activity into logging table
WHILE 1=1
BEGIN
    EXEC dbo.sp_WhoIsActive @get_transaction_info = 1
	    ,@get_outer_command = 1
	    ,@get_plans = 1
	    ,@destination_table = @destination_table;

    -- purge older data
    SET @SQL = 'DELETE FROM ' + @destination_table + ' WHERE collection_time < DATEADD(day, -' + CAST(@retention AS VARCHAR(10)) + ', GETDATE());';
    EXEC (@SQL);

	-- delete data coming from the service accounts
	SET @SQL = 'DECLARE @excludes TABLE (account_name NVARCHAR(500));
INSERT INTO @excludes SELECT service_account FROM sys.dm_server_services;
DELETE FROM ' + @destination_table + ' WHERE login_name IN (SELECT account_name FROM @excludes);';
	EXEC (@SQL);

	-- delete data coming from the diagnostics session
	SET @SQL = 'DELETE FROM ' + @destination_table + ' WHERE CAST([sql_text] AS varchar(max)) LIKE ''%sp_server_diagnostics%'';';
	EXEC (@SQL);

    WAITFOR DELAY '00:00:03'
END
