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
-- Description:	created informative views to the metadata tables in the TAP_SCHEMA schema.
-- ====================================================================================================================================================================================
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



-- Use your own cross-match database
USE xmatchdb


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Catalogs') AND TYPE = 'V') 
DROP VIEW Catalogs
GO
CREATE VIEW [dbo].[Catalogs]
--/H Returns all available catalogs and asscociated metadata.
--/U ------------------------------------------------------------
--/T <br><samp>SELECT * FROM Catalogs</samp>
AS
	SELECT catalog_name, summary, remarks, url FROM TAP_SCHEMA.catalogs
GO
--SELECT * FROM Catalogs

-----------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Tables') AND TYPE = 'V') 
DROP VIEW Tables
GO
CREATE VIEW Tables
--/H Returns all available catalog tables and asscociated metadata.
--/U ------------------------------------------------------------
--/T <br><samp>SELECT * FROM Tables</samp>
AS
	SELECT s.value as catalog_name, table_name, table_type, description, schema_name
	FROM TAP_SCHEMA.tables t
	CROSS APPLY STRING_SPLIT(table_name, '_', 1) as s
	WHERE s.ordinal = 1 AND s.value IN (SELECT catalog_name FROM Catalogs)
GO
--SELECT * FROM Tables

-----------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Columns') AND TYPE = 'V') 
DROP VIEW Columns
GO
CREATE VIEW Columns
--/H Returns all available catalog table columns and asscociated metadata.
--/U ------------------------------------------------------------
--/T <br><samp>SELECT * FROM Columns</samp>
AS
	SELECT s.value as catalog_name, table_name, column_name, description, unit, ucd, utype, datatype, size, precision, scale, column_index, schema_name
	FROM TAP_SCHEMA.columns t
	CROSS APPLY STRING_SPLIT(table_name, '_', 1) AS s
	WHERE s.ordinal = 1 AND s.value IN (SELECT catalog_name FROM Catalogs)
GO
--SELECT * FROM Columns