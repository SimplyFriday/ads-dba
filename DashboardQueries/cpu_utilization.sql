DECLARE @ts_now BIGINT


SELECT @ts_now = ms_ticks
FROM sys.dm_os_sys_info


-- Linux doesn't play nice with the "other process" stuff, because it always returns SystemIdle as 0
-- So we need to grab the OS type.
DECLARE @majorVersion INT,
    @includeIdle BIT = 1,
    @isLinux BIT = 0;


-- 14 = 2017, anything before that had to run on Windows
SELECT @majorVersion = PARSENAME(CONVERT(VARCHAR(32), SERVERPROPERTY('ProductVersion')), 4);


IF @majorVersion < 14
BEGIN
    SET @includeIdle = 1;
END
ELSE
BEGIN
    IF EXISTS (
            SELECT 1
            FROM sys.dm_os_host_info
            WHERE host_platform = 'Linux'
            )
        SET @isLinux = 1;


    IF @isLinux = 1
        AND @majorVersion = 14
    BEGIN
        RAISERROR (
                'This will not return meaningful data on SQL Server 2017 running on Linux. See https://techcommunity.microsoft.com/t5/SQL-Server/SQL-Server-CPU-usage-available-in-sys-dm-os-ring-buffers-DMV/ba-p/825361',
                10,
                1
                )


        RETURN
    END


    SET @includeIdle = 0
END


IF @includeIdle = 1
BEGIN
    SELECT --record_id, 
        RIGHT(CAST(DATEADD(ms, (y.[timestamp] - @ts_now), GETDATE()) AS VARCHAR(20)), 7) AS EventTime,
        SQLProcessUtilization,
        SystemIdle,
        100 - SystemIdle - SQLProcessUtilization AS OtherProcessUtilization
    FROM (
        SELECT record.value('(./Record/@id)[1]', 'int') AS record_id,
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS SystemIdle,
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization,
            TIMESTAMP
        FROM (
            SELECT TIMESTAMP,
                CONVERT(XML, record) AS record
            FROM sys.dm_os_ring_buffers
            WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
                AND record LIKE '%<SystemHealth>%'
            ) AS x
        ) AS y
    ORDER BY record_id
END
ELSE
BEGIN
    SELECT --record_id, 
        RIGHT(CAST(DATEADD(ms, (y.[timestamp] - @ts_now), GETDATE()) AS VARCHAR(20)), 7) AS EventTime,
        SQLProcessUtilization,
        100 AS MaxCPU
    FROM (
        SELECT record.value('(./Record/@id)[1]', 'int') AS record_id,
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization,
            TIMESTAMP
        FROM (
            SELECT TIMESTAMP,
                CONVERT(XML, record) AS record
            FROM sys.dm_os_ring_buffers
            WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
                AND record LIKE '%<SystemHealth>%'
            ) AS x
        ) AS y
    ORDER BY record_id
END
