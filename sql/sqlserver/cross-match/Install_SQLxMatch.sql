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
-- Description:	Creates the SQLxMatch procedure and other utility functions/procedures.
-- ====================================================================================================================================================================================
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


-- Use your own cross-match database
USE xmatchdb


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- create fAlpha function


IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fAlpha') AND type = 'FN')
DROP FUNCTION fAlpha
GO

CREATE FUNCTION fAlpha(@theta FLOAT, @decMin FLOAT, @decMax FLOAT, @zoneHeight FLOAT)
--/H Returns the value of alpha, which is a modified search radius along the RA direction.
--/U ------------------------------------------------------------
--/T Parameters:<br>
--/T <li> @theta float: value of theta (input search radius) in degrees.
--/T <li> @@decMin float: value of minimum declination in degrees.
--/T <li> @decMax float: value of maximum declination in degrees.
--/T <li> @zoneHeight float: value of the zone height in degrees.
--/T <li> returns alpha float: value of alpha.
RETURNS float
AS BEGIN 
	DECLARE @dec FLOAT

	IF ABS(@decMax) < ABS(@decMin)
	BEGIN
		SET @dec = @decMin - @zoneHeight / 100;
	END
	ELSE
	BEGIN
		SET @dec = @decMax + @zoneHeight / 100;
	END

	IF ABS(@dec) + @theta > 89.9 RETURN 180
	
	RETURN degrees(abs(atan(sin(radians(@theta)) / sqrt(abs(cos(radians(@dec-@theta)) * cos(radians(@dec+@theta)))))))

END
GO


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- create spPrintMessage procedure


IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spPrintMessage') AND TYPE = 'P')
DROP PROCEDURE spPrintMessage
GO
CREATE PROCEDURE spPrintMessage @initial_datetime DATETIME, @message NVARCHAR(max)
----------------------------------------------------------------
--/H Prints a text message together with the current time and the time elapsed since an initial time.
--/U ------------------------------------------------------------
--/T Parameters:<br>
--/T <li> @initial_datetime DATETIME: initial time from which to calculate the time elapsed.
--/T <li> @message NVARCHAR(max): text to be printed.
AS BEGIN
	DECLARE @current_datetime DATETIME = SYSDATETIME()
	PRINT  CONVERT(NVARCHAR(23), SYSDATETIME())     + N'  ' +   CONVERT(NVARCHAR(12),  DATEDIFF(MILLISECOND, @initial_datetime, @current_datetime) / 1000) + '.' + RIGHT('000' + CONVERT(NVARCHAR(4), DATEDIFF(MILLISECOND, @initial_datetime, @current_datetime) % 1000), 3) + N' ' + @message
END
GO
						

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- create spGetDataParts procedure


IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spGetDataParts') AND TYPE = 'P')
DROP PROCEDURE spGetDataParts
GO

CREATE PROCEDURE spGetDataParts @table SYSNAME, @do_include_server BIT = 1, @server_name SYSNAME OUTPUT, @db_name SYSNAME OUTPUT, @schema_name SYSNAME OUTPUT, @table_name SYSNAME OUTPUT
----------------------------------------------------------------
--/H Returns the 4 parts defining a sys object name:  server.database.schema.table
--/U ------------------------------------------------------------
--/T Parameters:<br>
--/T <li> @table SYSNAME: can be any of these formats: 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'
--/T <li> @do_include_server bit: whether to output the server name or not.
--/T <li> @server_name SYSNAME OUTPUT: name of database server, or empty string if not defined or @do_include_server=0
--/T <li> @db_name SYSNAME OUTPUT: name of database, or empty string if not defined.
--/T <li> @schema_name SYSNAME OUTPUT: name of database schema, or 'dbo' if not defined.
--/T <li> @table_name SYSNAME OUTPUT: name of database table, or empty string if not defined.
AS BEGIN

	SET @table_name  = PARSENAME(@table, 1)
	SET @schema_name = PARSENAME(@table, 2)
	SET @db_name	 = PARSENAME(@table, 3)
	SET @server_name = PARSENAME(@table, 4)

	IF COALESCE(@server_name, @db_name, @schema_name, @table_name) IS NULL
	BEGIN
		SET @db_name  = N''
		SET @schema_name  = N'dbo'
		SET @table_name  = N''
		SET @server_name = N''
		RETURN
	END

	IF @do_include_server = 1 -- Expects @table = server.database.schema.table 
		BEGIN
			SET @table_name  = COALESCE(@table_name, N'')
			SET @schema_name = COALESCE(@schema_name, N'dbo')
			SET @db_name	 = COALESCE(@db_name, N'')
			SET @server_name = COALESCE(@server_name, N'')
		END
	ELSE	-- Expects @table=database.schema.table or @table=database.table
		BEGIN
			SET @server_name = N''
			-- Case @table=table
			IF COALESCE(@db_name, @schema_name) is null
			BEGIN 
				SET @db_name = N''
				SET @schema_name = N'dbo'
			END

			-- Case @table=database.table (assuming this interpretation takes precedence over @table=schema.table)
			IF @db_name IS NULL AND @schema_name IS NOT NULL
			BEGIN 
				SET @db_name = @schema_name
				SET @schema_name = N'dbo'
			END

			-- Case when @table=database..table
			IF @schema_name IS NULL
				SET @schema_name = N'dbo'

		END
	RETURN 
END
GO


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- create spHasColumn procedure


IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spHasColumn') AND TYPE = 'P')
DROP PROCEDURE spHasColumn
GO

CREATE PROCEDURE spHasColumn(@table SYSNAME, @column SYSNAME, @has_column bit OUTPUT)
----------------------------------------------------------------
--/H Computes whether or not a table or view has a particular column.
--/U ------------------------------------------------------------
--/T Parameters:<br>
--/T <li> @table SYSNAME: can be any of these formats: 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'.
--/T <li> @column SYSNAME: name of column.
--/T <li> @has_column bit OUTPUT: has the value of 1 if the column is in @table, and 0 otherwise.
AS BEGIN
	SET NOCOUNT ON
	DECLARE @server_name SYSNAME,
			@db_name SYSNAME,
			@schema_name SYSNAME,
			@table_name SYSNAME, 
			@temp_table_name SYSNAME

	EXECUTE spGetDataParts @table=@table, @do_include_server=0, @server_name=@server_name OUTPUT, @db_name=@db_name OUTPUT, @schema_name=@schema_name OUTPUT, @table_name=@table_name OUTPUT 

	SET @column = parsename(@column, 1) -- unquotes the column name, if entered with quotes.

	IF @server_name != ''
		SET @server_name =  QUOTENAME(@server_name)
	IF @db_name != ''
		SET @db_name =  QUOTENAME(@db_name)

	SET @temp_table_name = 'tempdb.' + QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_name)

	DECLARE @sql nvarchar(max) = N'
	SELECT @numrows = count(*) FROM (
		SELECT c.name as col_name
		FROM ' + @server_name + N'.' + @db_name + N'.sys.tables t 
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.columns c ON t.object_id = c.object_id
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.schemas s ON t.schema_id = s.schema_id
		WHERE t.name = @table_name AND s.name = @schema_name
		AND c.name = @column
		UNION ALL
		SELECT c.name as col_name
		FROM ' + @server_name + N'.' + @db_name + N'.sys.views t 
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.columns c ON t.object_id = c.object_id
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.schemas s ON t.schema_id = s.schema_id
		WHERE t.name = @table_name AND s.name = @schema_name
		AND c.name = @column
		UNION ALL
		SELECT c.name as col_name
		FROM tempdb.sys.tables t 
		JOIN tempdb.sys.columns c ON t.object_id = c.object_id
		WHERE t.object_id = OBJECT_ID(@temp_table_name)
		AND c.name = @column
		UNION ALL
		SELECT c.name as col_name
		FROM tempdb.sys.views t 
		JOIN tempdb.sys.columns c ON t.object_id = c.object_id
		WHERE t.object_id = OBJECT_ID(@temp_table_name)
		AND c.name = @column
	) as a'
	
	--PRINT @sql
	DECLARE @numrows BIGINT
	EXECUTE sp_executesql @sql, N'@table_name SYSNAME, @schema_name SYSNAME, @temp_table_name SYSNAME, @column SYSNAME, @numrows bigint OUTPUT', 
							      @table_name=@table_name, @schema_name=@schema_name, @temp_table_name=@temp_table_name, @column=@column, @numrows=@numrows OUTPUT

	IF @numrows > 0
	BEGIN
		SET @has_column = 1;
	END
	ELSE
	BEGIN 
		SET @has_column = 0;
	END
END
GO



----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- create spGetColumnType procedure


IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spGetColumnType') AND TYPE = 'P')
DROP PROCEDURE spGetColumnType
GO

CREATE PROCEDURE spGetColumnType(@table SYSNAME, @column SYSNAME, @col_type SYSNAME OUTPUT, @col_length BIGINT OUTPUT, @col_precision BIGINT OUTPUT, @col_scale BIGINT OUTPUT)
----------------------------------------------------------------
--/H Gets the data type of a particular column in a table or view.
--/U ------------------------------------------------------------
--/T Parameters:<br>
--/T <li> @table SYSNAME: can be any of these formats: 'server.database.schema.table', 'database.schema.table', or 'database.table', or simply 'table'.
--/T <li> @column SYSNAME: name of column.
--/T <li> @col_type SYSNAME OUTPUT: type of column.
--/T <li> @col_length BIGINT OUTPUT: column length.
--/T <li> @col_precision BIGINT OUTPUT: column precision.
--/T <li> @col_scale BIGINT OUTPUT: column scale.
AS BEGIN
	SET NOCOUNT ON
	DECLARE @server_name SYSNAME,
			@db_name SYSNAME,
			@schema_name SYSNAME,
			@table_name SYSNAME, 
			@temp_table_name SYSNAME

	EXECUTE spGetDataParts @table=@table, @do_include_server=0, @server_name=@server_name OUTPUT, @db_name=@db_name OUTPUT, @schema_name=@schema_name OUTPUT, @table_name=@table_name OUTPUT 

	SET @column = parsename(@column, 1) -- unquotes the column name, if entered with quotes.

	IF @server_name != ''
		SET @server_name =  QUOTENAME(@server_name)
	IF @db_name != ''
		SET @db_name =  QUOTENAME(@db_name)

	SET @temp_table_name = 'tempdb.' + QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_name)

	DECLARE @sql nvarchar(max) = N'
	SELECT @col_type=col_type, @col_length=col_length, @col_precision=col_precision, @col_scale=col_scale FROM (
		SELECT y.name as col_type, c.max_length as col_length, c.precision as col_precision, c.scale as col_scale
		FROM ' + @server_name + N'.' + @db_name + N'.sys.tables t 
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.columns c ON t.object_id = c.object_id
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.types y ON y.user_type_id = c.user_type_id
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.schemas s ON t.schema_id = s.schema_id
		WHERE t.name = @table_name AND s.name = @schema_name
		AND c.name = @column
		UNION ALL
		SELECT y.name as col_type, c.max_length as col_length, c.precision as col_precision, c.scale as col_scale
		FROM ' + @server_name + N'.' + @db_name + N'.sys.views t 
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.columns c ON t.object_id = c.object_id
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.types y ON y.user_type_id = c.user_type_id
		JOIN ' + @server_name + N'.' + @db_name + N'.sys.schemas s ON t.schema_id = s.schema_id
		WHERE t.name = @table_name AND s.name = @schema_name
		AND c.name = @column
		UNION ALL
		SELECT y.name as col_type, c.max_length as col_length, c.precision as col_precision, c.scale as col_scale
		FROM tempdb.sys.tables t 
		JOIN tempdb.sys.columns c ON t.object_id = c.object_id
		JOIN tempdb.sys.types y ON y.user_type_id = c.user_type_id
		WHERE t.object_id = OBJECT_ID(@temp_table_name)
		AND c.name = @column
		UNION ALL
		SELECT y.name as col_type, c.max_length as col_length, c.precision as col_precision, c.scale as col_scale
		FROM tempdb.sys.views t 
		JOIN tempdb.sys.columns c ON t.object_id = c.object_id
		JOIN tempdb.sys.types y ON y.user_type_id = c.user_type_id
		WHERE t.object_id = OBJECT_ID(@temp_table_name)
		AND c.name = @column
	) as a'
	
	--PRINT @sql
	DECLARE @numrows BIGINT
	EXECUTE sp_executesql @sql, N'@table_name SYSNAME, @schema_name SYSNAME, @temp_table_name SYSNAME, @column SYSNAME, @col_type nvarchar(max) OUTPUT, @col_length BIGINT OUTPUT, @col_precision BIGINT OUTPUT, @col_scale BIGINT OUTPUT', 
								@table_name=@table_name, @schema_name=@schema_name, @temp_table_name=@temp_table_name, @column=@column, @col_type=@col_type OUTPUT, @col_length=@col_length OUTPUT, @col_precision=@col_precision OUTPUT, @col_scale=@col_scale OUTPUT
END
GO


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- create spGetQuotedPath procedure

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spGetQuotedPath') AND TYPE = 'P')
DROP PROCEDURE spGetQuotedPath
GO

CREATE PROCEDURE spGetQuotedPath(@table SYSNAME, @quoted_path SYSNAME OUTPUT)
----------------------------------------------------------------
--/H Gets the full quoted path to a database table
--/U ------------------------------------------------------------
--/T Parameters:<br>
--/T <li> @table SYSNAME: input table. Can be any of these formats: 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'.
--/T <li> @quoted_path float: output path to the input table, with quotes.
AS BEGIN
	DECLARE @server_name SYSNAME,
			@db_name SYSNAME,
			@schema_name SYSNAME,
			@table_name SYSNAME

	EXECUTE spGetDataParts @table=@table, @do_include_server=0, @server_name=@server_name OUTPUT, @db_name=@db_name OUTPUT, @schema_name=@schema_name OUTPUT, @table_name=@table_name OUTPUT


	SET @table_name = QUOTENAME(@table_name)
	IF @db_name != N''
		SET @db_name = QUOTENAME(@db_name)
	IF @server_name != N''
		SET @server_name = QUOTENAME(@server_name)
	IF @schema_name != N'dbo'
		SET @schema_name = QUOTENAME(@schema_name)

	SET @quoted_path = @server_name + N'.' +   @db_name + N'.' + @schema_name + N'.' + @table_name
	RETURN
END
GO


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- create spSetCatalogIdColumn procedure



IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spSetCatalogIdColumn') AND TYPE = 'P')
DROP PROCEDURE spSetCatalogIdColumn
go
CREATE PROCEDURE spSetCatalogIdColumn(@target_table SYSNAME, @reference_table SYSNAME, @reference_id_col SYSNAME = 'objid')
----------------------------------------------------------------
--/H Changes the type of the unique identifier column (must be named 'objid') in a target table, and set it equal to the type of a column in a refernece table.
--/U ------------------------------------------------------------
--/T Parameters:<br>
--/T <li> @target_table SYSNAME: target table. Can be any of these formats: 'server.database.schema.table', 'database.schema.table', or 'database.table', or simply 'table'.
--/T <li> @reference_table SYSNAME: reference table. Can be any of these formats: 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'.
--/T <li> @reference_id_col SYSNAME: name of column in the refernce table. Takes the default value 'objid'.
AS BEGIN
	SET NOCOUNT ON

	DECLARE @sql NVARCHAR(max)
	DECLARE @col_type NVARCHAR(max)
	DECLARE @col_length BIGINT
	DECLARE @col_precision BIGINT
	DECLARE @col_scale BIGINT
	EXECUTE spGetColumnType @table=@reference_table, @column=@reference_id_col, @col_type=@col_type OUTPUT, @col_length=@col_length OUTPUT, @col_precision=@col_precision OUTPUT, @col_scale=@col_scale OUTPUT

	DECLARE @server_name SYSNAME,
			@db_name SYSNAME,
			@schema_name SYSNAME,
			@table_name SYSNAME

	EXECUTE spGetDataParts @table=@target_table, @do_include_server=0, @server_name=@server_name OUTPUT, @db_name=@db_name OUTPUT, @schema_name=@schema_name OUTPUT, @table_name=@table_name OUTPUT 

	-- Force table to be a local temp table:
	IF @table_name NOT LIKE '#%'
	BEGIN
		RAISERROR('Table whose ID column is to be altered should be a temp table.', 16, 1)
		RETURN
	END

	SET @table_name = QUOTENAME(@table_name)
	IF @db_name != N''
		SET @db_name = QUOTENAME(@db_name)
	IF @server_name != N''
		SET @server_name = QUOTENAME(@server_name)
	IF @schema_name != N'dbo'
		SET @schema_name = QUOTENAME(@schema_name)
	
	SET @table_name = @server_name + N'.' +   @db_name + N'.' + @schema_name + N'.' + @table_name

	IF @col_type like N'%char%' or @col_type = N'text' or @col_type like N'%binary%'  
	BEGIN
		SET @sql = N'ALTER TABLE ' + @table_name + N' ALTER COLUMN objid @col_type(@col_length) NOT NULL'
	END
	ELSE
	BEGIN
		IF @col_type = N'numeric' or @col_type = N'decimal'
		BEGIN
			SET @sql = N'ALTER TABLE ' + @target_table + N' ALTER COLUMN objid @col_type(@col_precision, @col_scale) NOT NULL'
		END
		ELSE
		BEGIN
			SET @sql = N'ALTER TABLE ' + @target_table + N' ALTER COLUMN objid ' + @col_type + N' NOT NULL'
		END
	END

	SET @sql = REPLACE(@sql, N'@col_length', @col_length)
	SET @sql = REPLACE(@sql, N'@col_type', @col_type)
	SET @sql = REPLACE(@sql, N'@col_scale', @col_scale)
	SET @sql = REPLACE(@sql, N'@col_precision', @col_precision)
	--PRINT(@sql)
	EXECUTE sp_executesql @sql
END


GO


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- create spBuildCatalog procedure

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spBuildCatalog') AND TYPE = 'P')
DROP PROCEDURE spBuildCatalog
GO

CREATE PROCEDURE spBuildCatalog(@target_table SYSNAME, @reference_table SYSNAME, @zoneHeight float = 30, @id_col SYSNAME = 'objid', @ra_col SYSNAME = 'ra', @dec_col SYSNAME = 'dec', @max_catalog_rows BIGINT = null)
----------------------------------------------------------------
--/H Populates the @target_table table with a modified version of the inpute @reference_table table, in a format ready to be used by the SQLxMatch procedure.
--/T The input @reference_table is expected to have at least a unique identifier column, as well as an RA (Right Ascension) and Dec (Declination) columns.
--/T If the columns defining the cartesian coordinates an object on the unit sphere (must be named 'cx', 'cy', and 'cz') are missing, then this procedure will calculate and add them.
--/T If the column defining the zone ID (must be named 'zoneid') is missing, then this procedure will calculate and add it by using the value of @zoneHeight.
--/U ------------------------------------------------------------
--/T Parameters:<br>
--/T <li> @target_table SYSNAME: target table to be populated. Can be any of these formats: 'server.database.schema.table', 'database.schema.table', or 'database.table', or simply 'table'.
--/T <li> @reference_table SYSNAME: reference table. Can be any of these formats: 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'.
--/T <li> @zoneHeight float: If @table does not contain a column named 'zoneid', then it will calculate this column using zones of this height (in units of arcsec). Takes a default value of 30 arsec.
--/T <li> @id_col SYSNAME: name of column that uniquely identifies an object. Defaults to 'objid'.
--/T <li> @ra_col SYSNAME: name of column containing the RA (Right Ascension) value of an object. Defaults to 'ra'.
--/T <li> @dec_col SYSNAME: name of column containing the Dec (Declination) value of an object. Defaults to 'dec'.
--/T <li> @max_catalog_rows bigint: default value of null. If set, the procedure will return the TOP @max_catalog_rows rows, with no special ordering.
AS BEGIN

	SET NOCOUNT ON

	-- parsing input parameters
	DECLARE @reference_quoted_path SYSNAME
	EXECUTE spGetQuotedPath @table=@reference_table, @quoted_path=@reference_quoted_path OUTPUT

	DECLARE @target_quoted_path SYSNAME
	EXECUTE spGetQuotedPath @table=@target_table, @quoted_path=@target_quoted_path OUTPUT

	SET @id_col = QUOTENAME(PARSENAME(@id_col, 1))
	SET @ra_col = QUOTENAME(PARSENAME(@ra_col, 1))
	SET @dec_col = QUOTENAME(PARSENAME(@dec_col, 1))

	DECLARE @has_column bit

	EXECUTE spHasColumn @table=@reference_table, @column=@id_col, @has_column=@has_column OUTPUT
	IF @has_column = 0
	BEGIN
		RAISERROR('Input table must have an ID column.',16,1)
		PRINT('Input table is ' + QUOTENAME(@reference_table))
		RETURN
	END

	EXECUTE spHasColumn @table=@reference_table, @column=@ra_col, @has_column=@has_column OUTPUT
	IF @has_column = 0
	BEGIN
		RAISERROR('Input table must have an RA column.',16,1)
		PRINT('Input table is ' + QUOTENAME(@reference_table))
		RETURN
	END

	EXECUTE spHasColumn @table=@reference_table, @column=@dec_col, @has_column=@has_column OUTPUT
	IF @has_column = 0
	BEGIN
		RAISERROR('Input table must have a Dec column.',16,1)
		PRINT('Input table name is ' + QUOTENAME(@reference_table))
		RETURN
	END

	DECLARE @has_columns BIT = 1
	DECLARE @has_zoneid BIT = 1
	DECLARE @has_cxcycz BIT = 1

	EXECUTE spHasColumn @table=@reference_table, @column='cx', @has_column=@has_column OUTPUT
	SET @has_columns = @has_column
	EXECUTE spHasColumn @table=@reference_table, @column='cy', @has_column=@has_column OUTPUT
	SET @has_columns = @has_columns & @has_column
	EXECUTE spHasColumn @table=@reference_table, @column='cz', @has_column=@has_column OUTPUT
	SET @has_cxcycz = @has_columns & @has_column
	EXECUTE spHasColumn @table=@reference_table, @column='zoneid', @has_column=@has_zoneid OUTPUT

	DECLARE @select_top nvarchar(max) = N'INSERT INTO ' + @target_quoted_path + ' WITH (TABLOCKX) SELECT '
	IF @max_catalog_rows is not null
		SET @select_top = @select_top + N' TOP ' + CAST(@max_catalog_rows as nvarchar) + N' '

	DECLARE @sql nvarchar(max) = N'DECLARE @d2r float = PI()/180.0; ' + @select_top 
	IF @has_zoneid = 1
		SET @sql = @sql + N'zoneid, ' 
	ELSE
		SET @sql = @sql + 'CONVERT(INT,FLOOR((' + @dec_col + N' + 90.0)/' + CAST(@zoneHeight as nvarchar) + N')) as zoneid, '


	SET @sql = @sql + @id_col + N' as objid, ' +  @ra_col + N' as ra, ' + @dec_col + N' as dec, '

	IF @has_cxcycz = 1
		SET @sql = @sql + N' cx, cy, cz '
	ELSE
		SET @sql = @sql + N' COS(' + @dec_col + N'*@d2r)*COS(' + @ra_col + N'*@d2r) as cx, 
							 COS(' + @dec_col + N'*@d2r)*SIN(' + @ra_col + N'*@d2r) as cy, 
							 SIN(' + @dec_col + N'*@d2r) as cz '

	SET @sql = @sql + N'FROM ' + @reference_quoted_path + N';' 

	--PRINT @sql

	EXEC sp_executesql @sql, N'@zoneHeight float', @zoneHeight=@zoneHeight

END
GO




----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- create SQLxMatch procedure

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'SQLxMatch') AND TYPE = 'P')
DROP PROCEDURE SQLxMatch
GO
CREATE PROCEDURE SQLxMatch
	@table1 SYSNAME, 
	@table2 SYSNAME, 
	@radius FLOAT = 10, 
	@id_col1 SYSNAME = 'objid', 
	@id_col2 SYSNAME = 'objid', 
	@ra_col1 SYSNAME = 'ra', 
	@ra_col2 SYSNAME = 'ra', 
	@dec_col1 SYSNAME = 'dec', 
	@dec_col2 SYSNAME = 'dec',
	@max_catalog_rows1 BIGINT = null,
	@max_catalog_rows2 BIGINT = null,
	@output_table SYSNAME = null,
	@only_nearest bit = 0,
	@sort_by_separation BIT = 0,
	@radec_in_output BIT = 0,
	@print_messages BIT = 0
----------------------------------------------------------------
--/H Runs a spatial crossmatch between 2 catalogs of objects, using the Zones algorithm. Returns a table with the object IDs and angular separation between matching objects. 
--/U ------------------------------------------------------------
--/T The 2 catalogs can be tables or views, and are expected to have at least a unique identifier column, as well as an RA (Right Ascention) and Dec (Declination) columns.
--/T For each catalog, if the columns defining the cartesian coordinates an object (must be named 'cx', 'cy', and 'cz') are missing, then the code will calculate them on the fly.
--/T If the column defining the zone ID (must be named 'zoneid') is missing, then the code will calculate it on the fly, based on the value of the search radius @radius around each object.
--/T Parameters:<br>
--/T <li> @table1 SYSNAME: name of first input catalog. Can be any of these formats: 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'
--/T <li> @table2 SYSNAME: name of first input catalog. Can be any of these formats: 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'
--/T <li> @radius float: search radius around each object, in arcseconds. Takes a default value of 10 arcseconds.
--/T <li> @id_col1 SYSNAME: name of the column defining a unique object identifier in catalog @table1. Takes a default value of 'objid'.
--/T <li> @id_col2 SYSNAME: name of the column defining a unique object identifier in catalog @table2. Takes a default value of 'objid'.
--/T <li> @ra_col1 SYSNAME: name of the column containing the Right Ascention (RA) in degrees of objects in catalog @table1. Takes a default value of 'ra'.
--/T <li> @ra_col2 SYSNAME: name of the column containing the Right Ascention (RA) in degrees of objects in catalog @table2. Takes a default value of 'ra'.
--/T <li> @dec_col1 SYSNAME: name of the column containing the Declination (Dec) in degrees of objects in catalog @table1. Takes a default value of 'dec'.
--/T <li> @dec_col2 SYSNAME: name of the column containing the Declination (Dec) in degrees of objects in catalog @table2. Takes a default value of 'dec'.
--/T <li> @max_catalog_rows1 bigint: default value of null. If set, the procedure will use only the TOP @max_catalog_rows1 rows in catalog @table1, with no special ordering.
--/T <li> @max_catalog_rows2 bigint: default value of null. If set, the procedure will use only the TOP @max_catalog_rows2 rows in catalog @table2, with no special ordering.
--/T <li> @output_table SYSNAME: If NOT NULL, this procedure will insert the output results into the table @output_table (of format 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'), which must already exist and be visbile within the scope of the procedure. If set to null, the output results will be simply returned as a table resultset. Takes a default value of null.
--/T <li> @only_nearest bit: If set to 0 (default value), then all matches within a distance @radius to an object are returned. If set to 1, only the closest match to an object is returned.
--/T <li> @sort_by_separation bit: If set to 1, then the output will be sorted by the 'id1' and 'sep' columns. If set to 0 (default value), no particular ordering is applied.
--/T <li> @radec_in_output bit: If set to 1, then the output table will contain as well the (RA, Dec) values of each object.
--/T <li> @print_messages bit: If set to 1, then time-stamped messages will be printed as the different sections in this procedure are completed.
--/T <li> RETURNS TABLE(id1, id2, sep), where id1 and id2 are the unique object identifier columns in @table1 and @table2, respectively, and sep (float) is the angular separation between objetcs in arseconds.
--/T <li> In the case @radec_in_output=1, the procedure returns extra columns in the form of TABLE(id1, id2, sep, ra1, dec1, ra2, dec2), where ra1, dec1, ra2 and dec2 (float) are the coordinates of the objets in @table1 and @table2, respectively.

AS BEGIN

	SET NOCOUNT ON 
	
	IF @print_messages = 1
	BEGIN
		PRINT 'Laszlo'
		DECLARE @initial_datetime datetime = SYSDATETIME()
		EXECUTE spPrintMessage @initial_datetime , N'START xmatch procedure'
	END

	-- Enforce maximum allowed radius:
	
	DECLARE @max_radius float = 10 * 60.0 -- maximum allowed search radius in arcsec
	DECLARE @theta float = @radius/3600.0 -- in degrees
	
	IF @theta > @max_radius/ 3600
	BEGIN
		DECLARE @max_radius_str nvarchar(128) = CAST(@max_radius as nvarchar(128)) -- RAISERROR won't allow float data types like @max_radius as arguments.
		RAISERROR(N'Input search radius @radius surpassed maxiumum limit of %s arcsec.', 16, 1, @max_radius_str)
		RETURN
	END


	-- Define variables
	-- If a zoneid column is provided in both input @table1 and @table2 tables, 
	-- then we assume that they are calculated from a standard value of @DefaultZoneHeight.

	DECLARE @zoneHeight float = 10.0 / 3600.0 -- in degrees
	DECLARE @DefaultZoneHeight float = 4.0 / 3600.0 -- 4 arcsec was chosen as a standard value for creating the zoneid columns in the public catalogs.

	DECLARE @has_zones bit = 1
	DECLARE @has_column bit
	EXECUTE spHasColumn @table=@table1, @column='zoneid', @has_column=@has_zones OUTPUT
	SET @has_zones = @has_zones & @has_column
	EXECUTE spHasColumn @table=@table2, @column='zoneid', @has_column=@has_column OUTPUT
	SET @has_zones = @has_zones & @has_column
	IF @has_zones = 1
		SET @zoneHeight = @DefaultZoneHeight

	DECLARE @maxZone BIGINT = CAST(FLOOR(180.0/(@zoneHeight)) as BIGINT)
	DECLARE @num_zones int = CONVERT(int, FLOOR(@theta/@zoneHeight) + 1)
	DECLARE @sql NVARCHAR(MAX);
	DECLARE @col_type NVARCHAR(max)
	DECLARE @col_length BIGINT
	DECLARE @col_precision BIGINT
	DECLARE @col_scale BIGINT

	IF @print_messages = 1
		EXECUTE spPrintMessage @initial_datetime , N'ended stting up parameters'


	-- Create Zones definition table

	CREATE TABLE #ZoneDef (
		ZoneID INT PRIMARY KEY NOT NULL,
		DecMin FLOAT NOT NULL,
		DecMax FLOAT NOT NULL,
	) 
	INSERT INTO #ZoneDef WITH (TABLOCKX)
	SELECT value as zoneid, value*@zoneheight-90 as decMin, value*@zoneheight-90 + @zoneheight as decMax 
	FROM GENERATE_SERIES(CAST(0 as BIGINT), @maxZone, CAST(1 as BIGINT))
	
	IF @print_messages = 1
		EXECUTE spPrintMessage @initial_datetime , N'ended filling up #ZoneDef'


	-- Creating and populating both intermediary tables:

	CREATE TABLE #Table1 (
	  ZoneID INT NOT NULL,
	  ObjID BIGINT NOT NULL,
	  RA FLOAT NOT NULL,
	  Dec FLOAT NOT NULL,
	  Cx FLOAT NOT NULL,
	  Cy FLOAT NOT NULL,
	  Cz FLOAT NOT NULL,
	)
	EXECUTE spSetCatalogIdColumn @target_table='#Table1', @reference_table=@table1, @reference_id_col=@id_col1
	EXECUTE spBuildCatalog @target_table='#Table1', @reference_table=@table1, @zoneHeight=@zoneHeight, @id_col=@id_col1, @ra_col=@ra_col1, @dec_col=@dec_col1, @max_catalog_rows=@max_catalog_rows1
	CREATE CLUSTERED INDEX PK_zone_Table1 ON #Table1(ZoneID, RA);

	IF @print_messages = 1
		EXECUTE spPrintMessage @initial_datetime , N'ended filling up #Table1'

	CREATE TABLE #Table2 (
	  ZoneID INT NOT NULL,
	  ObjID FLOAT NOT NULL,
	  RA FLOAT NOT NULL,
	  Dec FLOAT NOT NULL,
	  Cx FLOAT NOT NULL,
	  Cy FLOAT NOT NULL,
	  Cz FLOAT NOT NULL,
	)
	EXECUTE spSetCatalogIdColumn @target_table='#Table2', @reference_table=@table2, @reference_id_col=@id_col2
	EXECUTE spBuildCatalog @target_table='#Table2', @reference_table=@table2, @zoneHeight=@zoneHeight, @id_col=@id_col2, @ra_col=@ra_col2, @dec_col=@dec_col2, @max_catalog_rows=@max_catalog_rows2
	CREATE CLUSTERED INDEX PK_zone_Table2 ON #Table2(ZoneID, RA);

	IF @print_messages = 1
		EXECUTE spPrintMessage @initial_datetime , N'ended filling up #Table2'


	-- Create zones linkeage table

	CREATE TABLE #Link (
	  ZoneID1 INT NOT NULL,
	  ZoneID2 INT NOT NULL,
	  Alpha	FLOAT NOT NULL
	)
	
	INSERT #Link WITH (TABLOCKX)
	SELECT zd1.ZoneID, zd2.ZoneID, dbo.fAlpha(@theta, zd2.DecMin, zd2.DecMax, @zoneheight)
	FROM #ZoneDef AS zd1
	INNER JOIN #ZoneDef AS zd2
	ON zd2.ZoneID BETWEEN zd1.ZoneID - @num_zones AND zd1.ZoneID + @num_zones
	CREATE UNIQUE CLUSTERED INDEX PK_zone_Link ON #Link(ZoneID1, ZoneID2);


	IF @print_messages = 1
		EXECUTE spPrintMessage @initial_datetime , N'ended filling up #Link'


	-- Setting up query that returns cross-match table . 

	DECLARE @rank_column NVARCHAR(256) = N''
	DECLARE @order_clause NVARCHAR(256) = N''
	DECLARE @radec_columns NVARCHAR(256) = N''
	DECLARE @dec_columns NVARCHAR(256) = N''
	DECLARE @sep_column NVARCHAR(256) = N'sep'
	DECLARE @dist2 FLOAT = 4 * power(sin(radians(@theta/2)), 2);


	-- Set output for radec input option.
	IF @radec_in_output = 1
	BEGIN
		SET @radec_columns = N', ra1, dec1, ra2, dec2 '
		SET @dec_columns = N', t1.dec AS dec1, t2.dec AS dec2 '
	END

	-- Set output for only-nearest-object input option.
	IF @only_nearest = 1
	BEGIN
		SET @rank_column = N', RANK() OVER (PARTITION BY id1 ORDER BY sep) AS sep_rank'
	END

	SET @sql = 'SELECT id1, id2' + @radec_columns + N', sep' + @rank_column + N' FROM wrap' -- wrap is the common table expression defined below.

	IF @only_nearest = 1
	BEGIN
		SET @sql = N'SELECT * FROM ( ' + @sql + N' ) AS q WHERE sep_rank = 1'
	END

	-- Set output for sort-by-separation input option.
	IF @sort_by_separation = 1
	BEGIN
		SET @sql = @sql + N' ORDER BY id1, sep'
	END

	-- Set output table statement
	IF @output_table IS NOT NULL
	BEGIN
		DECLARE @quoted_path SYSNAME
		EXECUTE spGetQuotedPath @table=@output_table, @quoted_path=@quoted_path OUTPUT
		SET @sql = N'INSERT INTO ' + @quoted_path + N' ' + @sql
	END;

	-- prepend common table expression
	SET @sql = N'
	WITH pairs AS
	(
		SELECT	
			t1.objid AS id1, t2.objid AS id2,
			t1.ra AS ra1, t2.ra AS ra2 ' + @dec_columns + N',
			60*120*degrees(asin(sqrt((t1.cx-t2.cx) * (t1.cx-t2.cx) + (t1.cy-t2.cy) * (t1.cy-t2.cy) + (t1.cz-t2.cz) * (t1.cz-t2.cz))/2)) AS sep,
			li.Alpha
		FROM #Link AS li
		INNER LOOP JOIN #Table1 AS t1 ON  li.ZoneID1 = t1.ZoneID
		INNER LOOP JOIN #Table2 AS t2 ON  li.ZoneID2 = t2.ZoneID
		WHERE (t1.cx - t2.cx) * (t1.cx - t2.cx) + (t1.cy - t2.cy) * (t1.cy - t2.cy) + (t1.cz - t2.cz) * (t1.cz - t2.cz) < @dist2
	),
	wrap AS
	(
		SELECT id1, id2, sep' + @radec_columns + N' FROM pairs
		WHERE
			[RA2] BETWEEN [RA1] - [Alpha] AND [RA1] + [Alpha]

		UNION ALL

		-- Add negative wrap-around
		SELECT id1, id2, sep' + @radec_columns + N' FROM pairs
		WHERE
			[RA1] BETWEEN 360 - [Alpha] AND 360  AND
			[RA2] BETWEEN 0 AND [RA1] - 360 + [Alpha]

		UNION ALL

		-- Add positive wrap-around
		SELECT id1, id2, sep' + @radec_columns + N' FROM pairs
		WHERE
			[RA1] BETWEEN 0 AND [Alpha] AND
			[RA2] BETWEEN [RA1] + 360 - [Alpha] AND 360
	)
	' + @sql

	--print @sql

	EXECUTE sp_executesql @sql, N'@dist2 FLOAT', @dist2=@dist2

	IF @print_messages = 1
		EXECUTE spPrintMessage @initial_datetime , N'Ended running xmatch query'

END
GO
