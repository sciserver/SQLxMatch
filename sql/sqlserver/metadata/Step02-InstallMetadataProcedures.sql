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
-- Description:	creates stored procedure for populating metadata tables in the TAP_SCHEMA schema.
-- ====================================================================================================================================================================================
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


USE xmatchdb



------------------------------------------------------------------------------
-- Catalogs info 

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spGetTAPcatalogs') AND TYPE = 'P')
DROP PROCEDURE spGetTAPcatalogs
GO
CREATE PROCEDURE spGetTAPcatalogs
--/H Returns a table with all available catalogs and asscociated metadata.
--/U ------------------------------------------------------------
--/T <br><samp>EXECUTE spGetTAPcatalogs</samp>
AS BEGIN

	SET NOCOUNT ON

	-- Create temp table 
	SELECT TOP 0 * INTO #tapcatalogs FROM TAP_SCHEMA.catalogs

	DECLARE @SQL NVARCHAR(max) = N'
		USE [?]; DECLARE @database SYSNAME = DB_NAME();
		INSERT INTO #tapcatalogs
		SELECT DISTINCT 
		@database,
		REPLACE(@database, ''SkyNode_'', ''''), 
		CASE WHEN [meta.summary] IS NULL THEN N'''' ELSE CAST([meta.summary] AS NVARCHAR(max)) END AS summary, 
		CASE WHEN [meta.remarks] IS NULL THEN N'''' ELSE CAST([meta.remarks] AS NVARCHAR(max)) END AS remarks, 
		CASE WHEN [meta.url] IS NULL THEN N'''' ELSE CAST([meta.url] AS NVARCHAR(max)) END AS url
		FROM 
		(
			SELECT db.name as catalog_name, ep.name, ep.value
			FROM sys.databases db 
			LEFT JOIN sys.extended_properties ep ON (ep.class = 0) -- = DATABASE
			WHERE db.name = @database
		) as d
		PIVOT
		(
			MAX(value) 
			FOR name in ([meta.summary], [meta.remarks], [meta.url])
		) as piv
	'
	DECLARE @sql_to_run NVARCHAR(max) = N''
	DECLARE @db_name NVARCHAR(1024)
    DECLARE db_cursor CURSOR FOR 
		SELECT name FROM sys.databases
		WHERE name like 'skynode_%' AND name NOT LIKE '%_STAT' AND name NOT LIKE 'SkyNode_Test%'
		ORDER BY name
    OPEN db_cursor
    FETCH NEXT FROM db_cursor INTO @db_name
    WHILE @@FETCH_STATUS = 0
    BEGIN
		SET @sql_to_run = REPLACE(@sql, N'?', @db_name)
        EXECUTE(@sql_to_run)
        FETCH NEXT FROM db_cursor INTO @db_name
    END
    CLOSE db_cursor;
    DEALLOCATE db_cursor;

	SELECT * FROM #tapcatalogs
	ORDER BY catalog_name
END
GO
--EXECUTE spGetTAPcatalogs




------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Table info


IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spGetTAPtables') AND TYPE = 'P')
DROP PROCEDURE spGetTAPtables
GO
CREATE PROCEDURE spGetTAPtables
--/H Returns a table with the names of all available catalog tables and their asscociated metadata, conforming to the TAP_SCHEMA standard.
--/U ------------------------------------------------------------
--/T <br><samp> EXECUTE spGetTAPtables</samp>
AS BEGIN

	SET NOCOUNT ON

	-- Create temp table 
	SELECT TOP 0 * INTO #taptables FROM TAP_SCHEMA.tables

	-- forced to use cursor beacuse of 2000 character limit in sp_msforeachdb
	DECLARE @sql NVARCHAR(max) = N'
		USE [?];
		DECLARE @database SYSNAME = DB_NAME();
		IF EXISTS(SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES where TABLE_NAME = ''tables'' AND TABLE_SCHEMA=''TAP_SCHEMA'') -- try first using metadata in TAP_SCHEMA
		BEGIN
			INSERT INTO #taptables
			SELECT DISTINCT 
			t.TABLE_SCHEMA [schema_name],
			REPLACE(@database, ''SkyNode_'', '''') + ''_'' + t.TABLE_NAME table_name,
			''view'' [table_type], COALESCE(ts.description, N'''') description, ts.utype, NULL as [table_index]
			FROM INFORMATION_SCHEMA.TABLES t
			LEFT JOIN TAP_SCHEMA.tables ts ON (ts.table_name = t.TABLE_NAME)
		END
		ELSE IF EXISTS(SELECT name from sys.tables where name = ''dbobjects'') -- try using metadata in dbobjects table
		BEGIN
			INSERT INTO #taptables
			SELECT DISTINCT 
			ta.[schema_name], 
			REPLACE(@database, ''SkyNode_'', '''') + ''_'' + ta.table_name as table_name,
			''view'' [table_type],  COALESCE(do.description, N'''') description, NULL utype, NULL as [table_index]
			FROM (
				SELECT t.TABLE_SCHEMA [schema_name], t.TABLE_NAME as table_name
				FROM INFORMATION_SCHEMA.TABLES t 
				UNION
				SELECT t.TABLE_SCHEMA [schema_name], t.TABLE_NAME as table_name
				FROM INFORMATION_SCHEMA.VIEWS t 
			) as ta 
			LEFT JOIN DBObjects AS do ON (do.name = ta.TABLE_NAME AND (do.type = ''U'' OR do.type = ''V''))
		END
		ELSE
		BEGIN
			INSERT INTO #taptables
			SELECT DISTINCT 
			''dbo'' as ''schema_name'',
			REPLACE(@database, ''SkyNode_'', '''') + ''_'' + table_name as ''table_name'', 
			''view'' as table_type, 
			COALESCE(CAST([meta.remarks] AS NVARCHAR(max)), N'''') AS description, 
			NULL as utype, 
			NULL as [table_index]
			FROM
			(
				SELECT t.name as table_name, ep.name as property_name, ep.value as property_value
				FROM sys.tables AS t 
				JOIN sys.all_objects O ON t.object_id = o.object_id 
				LEFT JOIN sys.extended_properties ep ON (ep.major_id = t.object_id)
				UNION 
				SELECT t.name as table_name, ep.name as property_name, ep.value as property_value
				FROM sys.views AS t
				JOIN sys.all_objects O ON t.object_id = o.object_id 
				LEFT JOIN sys.extended_properties ep ON (ep.major_id = t.object_id)
			) as d
			PIVOT
			(
				MAX(property_value) 
				FOR property_name in ([meta.summary], [meta.remarks])
			) as piv
		END
	'
	DECLARE @sql_to_run NVARCHAR(max) = N''
	DECLARE @db_name NVARCHAR(1024)
    DECLARE db_cursor CURSOR FOR 
		SELECT name FROM sys.databases
		WHERE name like 'skynode_%' AND name NOT LIKE '%_STAT' AND name NOT LIKE 'SkyNode_Test%'
		ORDER BY name
    OPEN db_cursor
    FETCH NEXT FROM db_cursor INTO @db_name
    WHILE @@FETCH_STATUS = 0
    BEGIN
		SET @sql_to_run = REPLACE(@sql, N'?', @db_name)
        EXECUTE(@sql_to_run)
        FETCH NEXT FROM db_cursor INTO @db_name
    END
    CLOSE db_cursor;
    DEALLOCATE db_cursor;

	SELECT * FROM #taptables
	ORDER BY table_name  
END
GO
--EXECUTE spGetTAPtables



------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Column info


IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spGetTAPcolumns') AND TYPE = 'P')
DROP PROCEDURE spGetTAPcolumns
GO
CREATE PROCEDURE spGetTAPcolumns
--/H Returns a table with the names of all catalog table columns and their asscociated metadata, conforming to the TAP_SCHEMA standard.
--/U ------------------------------------------------------------
--/T <br><samp>EXECUTE spGetTAPcolumns</samp>
AS BEGIN
	SET NOCOUNT ON 

	-- Create temp table 
	SELECT TOP 0 * INTO #tapcolumns FROM TAP_SCHEMA.columns

	-- forced to use cursor beacuse of 2000 character limit in sp_msforeachdb
	DECLARE @sql NVARCHAR(max) = N'
		USE ?; DECLARE @database SYSNAME = DB_NAME();
		IF EXISTS(SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES where TABLE_NAME = ''columns'' AND TABLE_SCHEMA=''TAP_SCHEMA'') -- try first using metadata in TAP_SCHEMA
		BEGIN
			INSERT INTO #tapcolumns
			SELECT DISTINCT 
			c.TABLE_SCHEMA schema_name, REPLACE(@database, ''SkyNode_'', '''') + ''_'' + c.TABLE_NAME as table_name, c.COLUMN_NAME,
			COALESCE(tc.description, N'''') description, COALESCE(tc.unit, N'''') unit, COALESCE(tc.ucd, N'''') ucd, COALESCE(tc.utype, N'''') utype,
			c.DATA_TYPE as datatype, c.CHARACTER_MAXIMUM_LENGTH as size, c.CHARACTER_MAXIMUM_LENGTH arraysize, c.NUMERIC_PRECISION precision, c.NUMERIC_SCALE scale, 1 principal,0 as indexed, 0 as std, c.ordinal_position column_index
			FROM INFORMATION_SCHEMA.COLUMNS c
			LEFT JOIN TAP_SCHEMA.columns AS tc ON c.COLUMN_NAME = tc.COLUMN_NAME AND c.TABLE_NAME = tc.TABLE_NAME
			ORDER BY table_name, column_index
		END
		ELSE IF EXISTS(SELECT name from sys.tables where name = ''DBColumns'') -- try using metadata in DBColumns table
		BEGIN
			INSERT INTO #tapcolumns
			SELECT DISTINCT 
			c.TABLE_SCHEMA schema_name, REPLACE(@database, ''SkyNode_'', '''') + ''_'' + c.TABLE_NAME as table_name, c.COLUMN_NAME,
			COALESCE(dc.description, N'''') description, COALESCE(dc.unit, N'''') unit, COALESCE(dc.ucd, N'''') ucd, N'''' utype, 
			c.DATA_TYPE as datatype, c.CHARACTER_MAXIMUM_LENGTH as size, c.CHARACTER_MAXIMUM_LENGTH arraysize, c.NUMERIC_PRECISION precision, c.NUMERIC_SCALE scale, 1 principal,0 as indexed, 0 as std, c.ordinal_position column_index			
			FROM INFORMATION_SCHEMA.COLUMNS c
			LEFT JOIN DBColumns AS dc ON dc.name = c.COLUMN_NAME AND dc.tablename = c.TABLE_NAME
			ORDER BY table_name, column_index
		END
		ELSE
		BEGIN
			INSERT INTO #tapcolumns
			SELECT DISTINCT 
			schema_name, REPLACE(@database, ''SkyNode_'', '''') + ''_'' + table_name as table_name, column_name, 
			COALESCE(CAST([meta.summary] AS NVARCHAR(max)), N'''') as description, COALESCE(CAST([meta.unit] AS NVARCHAR(max)), N'''') as unit, COALESCE(CAST([meta.quantity] AS NVARCHAR(max)), N'''') as ucd, N'''' as utype, 
			datatype, size, arraysize, precision, scale, 1 as principal, 0 as indexed, 0 as std, column_index
			FROM 
			(
				SELECT
				table_name, c.name column_name, col.DATA_TYPE datatype, c.max_length size, c.max_length arraysize, c.precision, c.scale, col.ordinal_position column_index, col.TABLE_SCHEMA schema_name, ep.name property_name, ep.value property_value
				FROM sys.columns c 
				JOIN sys.all_objects o ON c.object_id = o.object_id
				JOIN INFORMATION_SCHEMA.COLUMNS as col on col.TABLE_NAME = o.name and col.COLUMN_NAME=c.name
				LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
				WHERE (o.type = ''U'' OR o.type = ''V'')
			) AS d
			PIVOT
			(
				MAX(property_value) 
				FOR property_name in ([meta.quantity], [meta.summary], [meta.unit])
			) AS piv
			ORDER BY table_name, column_index
		END
	'
	DECLARE @sql_to_run NVARCHAR(max) = N''
	DECLARE @db_name NVARCHAR(1024)
    DECLARE db_cursor CURSOR FOR 
		SELECT name FROM sys.databases
		WHERE name LIKE 'skynode_%' AND name NOT LIKE '%_STAT' AND name NOT LIKE 'SkyNode_Test%'
		ORDER BY name
    OPEN db_cursor
    FETCH NEXT FROM db_cursor INTO @db_name
    WHILE @@FETCH_STATUS = 0
    BEGIN
		--PRINT(@db_name)
		SET @sql_to_run = REPLACE(@sql, N'?', @db_name)
        EXECUTE(@sql_to_run)
        FETCH NEXT FROM db_cursor INTO @db_name
    END
    CLOSE db_cursor;
    DEALLOCATE db_cursor;

	SELECT * FROM #tapcolumns 
	ORDER BY table_name, column_index
END
GO
--EXECUTE spGetTAPcolumns
