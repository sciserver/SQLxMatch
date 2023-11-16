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
-- Description:	creates metadata tables under the TAP_SCHEMA schema, conforming to the TAP schema standard.
-- ====================================================================================================================================================================================
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


USE xmatchdb

IF OBJECT_ID('[TAP_SCHEMA].[key_columns]') IS NOT NULL
DROP table [TAP_SCHEMA].[key_columns]
GO
CREATE TABLE [TAP_SCHEMA].[key_columns](
	[key_id] [NVARCHAR](64) NOT NULL,
	[from_column] [NVARCHAR](512) NOT NULL,
	[target_column] [NVARCHAR](512) NULL
)
GO


IF OBJECT_ID('[TAP_SCHEMA].[keys]') IS NOT NULL
DROP table [TAP_SCHEMA].[keys]
GO
CREATE TABLE [TAP_SCHEMA].[keys](
	[key_id] [NVARCHAR](64) NOT NULL,
	[from_table] [NVARCHAR](128) NOT NULL,
	[target_table] [NVARCHAR](128) NOT NULL,
	[description] [text] NULL,
	[utype] [NVARCHAR](512) NULL,
	[from_schema] [NVARCHAR](64) NOT NULL,
	[fromTable] [NVARCHAR](64) NOT NULL,
	[target_database] [NVARCHAR](64) NULL,
	[target_schema] [NVARCHAR](64) NOT NULL,
	[targetTable] [NVARCHAR](64) NOT NULL,
	PRIMARY KEY CLUSTERED
	(
		[key_id] ASC
	)
)
GO


IF OBJECT_ID('[TAP_SCHEMA].[columns]') IS NOT NULL
DROP table [TAP_SCHEMA].[columns]
GO
CREATE TABLE [TAP_SCHEMA].[columns](
	[schema_name] [NVARCHAR](512) NOT NULL,
	[table_name] [NVARCHAR](128) NOT NULL,
	[column_name] [NVARCHAR](128) NOT NULL,
	[description] [NVARCHAR](max) NULL,
	[unit] [NVARCHAR](512) NULL,
	[ucd] [NVARCHAR](512) NULL,
	[utype] [NVARCHAR](512) NULL,
	[datatype] [NVARCHAR](512) NOT NULL,
	[size] [INTEGER] NULL,
	[arraysize] [INTEGER] NULL,
	[precision] [INTEGER] NULL,
	[scale] [INTEGER] NULL,
	[principal] [INTEGER] NOT NULL,
	[indexed] [INTEGER] NOT NULL,
	[std] [INTEGER] NOT NULL,
	[column_index] [INTEGER] NULL,
	PRIMARY KEY CLUSTERED 
	(
		[table_name] ASC,
		[column_name] ASC
	)
)
GO

IF OBJECT_ID('[TAP_SCHEMA].[tables]') IS NOT NULL
DROP table [TAP_SCHEMA].[tables]
GO
CREATE TABLE [TAP_SCHEMA].[tables](
	[schema_name] [NVARCHAR](128) NOT NULL,
	[table_name]  [NVARCHAR](128) NOT NULL,
	[table_type] [NVARCHAR](512) NOT NULL,
	[description] [NVARCHAR](max) NULL,
	[utype] [NVARCHAR](512) NULL,
	[table_index] INTEGER NULL,
	PRIMARY KEY CLUSTERED 
	(
		[table_name] ASC
	)
)

GO


IF OBJECT_ID('[TAP_SCHEMA].[schemas]') IS NOT NULL
DROP table [TAP_SCHEMA].[schemas]
GO
CREATE TABLE [TAP_SCHEMA].[schemas](
	[schema_name] [NVARCHAR](128) NOT NULL,
	[description] [text] NULL,
	[utype] [VARCHAR](512) NULL,
	[schema_index] INT NULL,
	PRIMARY KEY CLUSTERED 
	(
		[schema_name] ASC
	)
) 
GO


IF OBJECT_ID('[TAP_SCHEMA].[catalogs]') IS NOT NULL
DROP table [TAP_SCHEMA].[catalogs]
GO
CREATE TABLE [TAP_SCHEMA].[catalogs](
	[database_name] NVARCHAR(128) NOT NULL,
	[catalog_name] NVARCHAR(128) NOT NULL,
	[summary] NVARCHAR(max) NULL,
	[remarks] NVARCHAR(max) NULL,
	[url] NVARCHAR(512) NULL
	PRIMARY KEY CLUSTERED 
	(
		[catalog_name] ASC
	)
) 
GO


ALTER TABLE [TAP_SCHEMA].[keys]  WITH CHECK ADD FOREIGN KEY([from_table])
REFERENCES [TAP_SCHEMA].[tables] ([table_name])
GO
ALTER TABLE [TAP_SCHEMA].[key_columns]  WITH CHECK ADD FOREIGN KEY([key_id])
REFERENCES [TAP_SCHEMA].[keys] ([key_id])
GO
ALTER TABLE [TAP_SCHEMA].[columns]  WITH CHECK ADD FOREIGN KEY([table_name])
REFERENCES [TAP_SCHEMA].[tables] ([table_name])
GO
