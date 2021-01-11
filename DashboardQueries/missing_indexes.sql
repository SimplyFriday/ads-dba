SELECT	numbers.avg_user_impact, numbers.avg_total_user_cost, numbers.user_seeks
	, fields.statement, fields.equality_columns, fields.inequality_columns, fields.included_columns
FROM	sys.dm_db_missing_index_group_stats numbers
	JOIN sys.dm_db_missing_index_groups linker ON linker.index_group_handle = numbers.group_handle
	JOIN sys.dm_db_missing_index_details fields ON fields.index_handle = linker.index_handle
WHERE	numbers.user_seeks >= 50
AND	fields.statement NOT LIKE '%merge%'
AND	fields.statement NOT LIKE '%distribution%'
AND	fields.statement NOT LIKE '%logreader%'
ORDER BY numbers.user_seeks DESC
--ORDER BY avg_user_impact DESC, statement
