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
    WHERE  Cast(CASE WHEN name IN ('master', 'model', 'msdb', 'tempdb') THEN 1 ELSE is_distributor END As bit) = 0), -- Exclude system databases
health AS (
    SELECT
        CASE 
            WHEN RecoveryModel = 'SIMPLE' THEN 'Healthy'
            WHEN LastLogBackup > 60 THEN 'Unhealthy'
            WHEN LastLogBackup IS NULL THEN 'Unhealthy'
            ELSE 'Healthy' 
        END AS LogHealth,
        CASE 
            WHEN LastFullBackup > 1440 THEN 'Unhealthy'
            WHEN LastFullBackup IS NULL THEN 'Unhealthy'
            ELSE 'Healthy' 
        END AS FullHealth
    FROM mostRecentBackups)


SELECT 'Log' AS Type,
    COUNT(CASE WHEN LogHealth = 'Unhealthy' THEN 1 END) AS Unhealthy,
    COUNT(CASE WHEN LogHealth = 'Healthy' THEN 1 END) AS Healthy
FROM health
UNION
SELECT 'Full' AS Type,
    COUNT(CASE WHEN FullHealth = 'Unhealthy' THEN 1 END) AS Unhealthy,
    COUNT(CASE WHEN FullHealth = 'Healthy' THEN 1 END) AS Healthy
FROM health
