/*
Copyright 2023 Johns Hopkins University

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================================================================================
-- Author:	Manuchehr Taghizadeh-Popp, Johns Hopkins University
-- Description:	creates the views to tables in astronomical catalog databases (SkyNodes) located in the same server.
-- ====================================================================================================================================================================================
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

USE xmatchdb



IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spDropAllViews') AND TYPE = 'P')
DROP PROCEDURE spDropAllViews
GO
CREATE PROCEDURE spDropAllViews
----------------------------------------------------------------
--/H Drops all views in a database.
----------------------------------------------------------------
AS BEGIN
	DECLARE @viewName nvarchar(max)
	DECLARE cur CURSOR FOR SELECT [name] FROM sys.objects where type = 'v'
	OPEN cur 
	FETCH NEXT FROM cur INTO @viewName 
	WHILE @@FETCH_status = 0 
	BEGIN 
		SET @viewName = N'DROP VIEW ' + CAST(QUOTENAME(@viewName) AS nvarchar(max))
		EXEC(@viewName)
		FETCH NEXT FROM cur INTO @viewName 
	END
	CLOSE cur 
	DEALLOCATE cur 
END
GO


IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spCreateSkynodeViews') AND TYPE = 'P')
DROP PROCEDURE spCreateSkynodeViews
GO
CREATE PROCEDURE spCreateSkynodeViews
----------------------------------------------------------------
--/H Creates all skynode views.
----------------------------------------------------------------
AS BEGIN

	-- Create and populate the #AllTables table with each row consisting of a commnd for creating a new view.

	CREATE TABLE #AllTables (  cmd nvarchar(max))
	DECLARE @SQL nvarchar(max) = '
		USE [?];
		SELECT  
		''create view '' + QUOTENAME( REPLACE(''?'', ''SkyNode_'', '''')  + ''_'' + name) + 
		'' AS SELECT * FROM '' +  QUOTENAME(''?'') + ''.'' + schema_name + ''.'' + QUOTENAME(name) + '' '' AS cmd
		FROM (
			SELECT name, SCHEMA_NAME(schema_id) as schema_name
			FROM sys.tables
			UNION ALL
			SELECT name, SCHEMA_NAME(schema_id) as schema_name
			FROM sys.views
		) AS q 
		WHERE ''?'' like ''skynode_%'' AND ''?'' != ''SkyNode_g'' AND ''?'' NOT LIKE ''%_STAT'' AND ''?'' NOT LIKE ''SkyNode_Test%''
		ORDER BY cmd
	'
	INSERT INTO #AllTables
	EXEC sp_msforeachdb @SQL

	-----------------------------------------------------------------------------------------------------
	-- Create now the views one-by-one with a cursor

	DECLARE cur2 Cursor For SELECT * FROM #AllTables ORDER BY cmd
	OPEN cur2
	FETCH NEXT FROM cur2 INTO @sql
	WHILE @@FETCH_status = 0 
	BEGIN 
		BEGIN TRY
			--PRINT(@sql)
			EXECUTE(@sql)
		END TRY  
		BEGIN CATCH
			PRINT 'Error: ' + @sql
		END CATCH
		FETCH Next FROM cur2 INTO @sql
	END
	CLOSE cur2 
	DEALLOCATE cur2
END
GO


--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
-- Create all views to all skynode tables (and views)

EXECUTE spDropAllViews

EXECUTE spCreateSkynodeViews
