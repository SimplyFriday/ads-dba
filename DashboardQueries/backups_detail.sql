USE msdb;

DECLARE @now DATETIME = GETDATE();

WITH mostRecentBackups
AS (
    SELECT db.name AS DatabaseName,
           (
                SELECT DATEDIFF(MINUTE, MAX(bs.backup_finish_date), @now) 
                FROM dbo.backupset bs
                WHERE bs.[type] = 'L'
                   AND bs.database_name = db.name
           ) AS LastLogBackup,
           (
                SELECT DATEDIFF(MINUTE, MAX(bs.backup_finish_date), @now) 
                FROM dbo.backupset bs
                WHERE bs.[type] = 'D'
                   AND bs.database_name = db.name
           ) AS LastFullBackup,
           db.recovery_model_desc AS RecoveryModel
    FROM    sys.databases db    
    WHERE  Cast(CASE WHEN name IN ('master', 'model', 'msdb', 'tempdb') THEN 1 ELSE is_distributor END As bit) = 0) -- Exclude system databases


SELECT mostRecentBackups.DatabaseName,
       mostRecentBackups.LastFullBackup,
       mostRecentBackups.LastLogBackup,
       CASE 
        WHEN mostRecentBackups.LastFullBackup > 1440
            THEN 'Unhealthy'
        WHEN mostRecentBackups.LastLogBackup > 15 AND RecoveryModel = 'FULL'
            THEN 'Unhealthy'
        WHEN mostRecentBackups.LastFullBackup IS NULL
            THEN 'Unhealthy'
        WHEN mostRecentBackups.LastLogBackup IS NULL AND RecoveryModel = 'FULL'
            THEN 'Unhealthy'
        ELSE 'Healthy' END AS Health
FROM mostRecentBackups
ORDER BY Health, DatabaseName