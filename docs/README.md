[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.10142770.svg)](https://doi.org/10.5281/zenodo.10142770)

# [**SQLxMatch: In-Database Spatial Cross-Match of Astronomical Catalogs**](https://github.com/sciserver/SQLxMatch)

##### Manuchehr Taghizadeh-Popp <sup>1*</sup> and Laszlo Dobos<sup>1,2</sup>
<sup>1</sup> Department of Physics and Astronomy, Johns Hopkins University, Baltimore, MD, USA.<br>
<sup>2</sup> Department of Physics of Complex Systems, Eötvös Loránd University, Budapest, Hungary.<br>
<sup>*</sup> Leading contributor email: mtaghiza [at] jhu.edu  |  Help Desk: sciserver-helpdesk [at] jhu.edu
<br><br>

`SQLxMatch` (or *sequel cross match*)  is a SQL stored procedure that allows to perform 2-dimensional spatial cross-matches and cone searches across multiple astronomical catalogs stored in relational databases.
This procedure implements the `Zones Algorithm` ([[1]](https://arxiv.org/abs/cs/0701171), [[2]](https://arxiv.org/abs/cs/0408031)), which leverages relational database algebra and B-Trees to cross-match the database tables or views containing the catalogs. To run a cross-match, these tables must simply contain at least the Right Ascension (RA) or Longitude, Declination (Dec) or Latitude, and unique object identifier (ID) columns.

We have integrated `SQLxMatch` with more than 50 astronomical catalogs, and made those publicly available as tables in remote SQL Server databases `in the cloud` through the [CasJobs](https://skyserver.sdss.org/CasJobs) website, as part of the [SciServer](https://www.sciserver.org) science platform ([[3]](https://www.sciencedirect.com/science/article/abs/pii/S2213133720300664)). In CasJobs, users can directly execute form-free SQL queries for cross-matching, either synchronously or as asynchronous jobs. For general audiences, a simpler form-based [interactive web interface](http://skyserver.sdss.org/public/CrossMatchTools/crossmatch) that uses the CasJobs REST API for running cross-match queries will be soon available in the [SkyServer](http://skyserver.sdss.org) astronomy portal.<br>
To improve cross-match query execution speed, we install `SQLxMatch` in a SQL Server database supported by fast NVMe storage in a RAID 6 configuration. We also place the catalog tables across several databases in the same physical server, thus avoiding having to move data across servers with a potentially slower network connection.

The advantage of this <i>`in-database`</i> remote cross-match, compared to other <i>`in-memory`</i> local cross-match software libraries, is that the users leverage the remote database server's own (and potentially bigger) computing/memory/storage resources to filter and cross-match the full catalogs right away, having only a relatively small-sized cross-match output table returned to them.
This can be faster and more efficient than having users to download the full catalogs into their own computers (if they have enough storage), and then load them in python for filtering and running the cross-match, for instance.

**Citation**
------------

Taghizadeh-Popp, M. and Dobos, L. (2023) “SQLxMatch: In-Database Spatial Cross-Match of Astronomical Catalogs”. Zenodo. doi: 10.5281/zenodo.10142771.

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.10142770.svg)](https://doi.org/10.5281/zenodo.10142770)


**Installation**
----------------


- **SQLxMatch stored procedure**

    For SQL Server, we execute a SQL script in order to install the SQLxMatch stored procedure. This script can be found under this path:
    
    [/sql/sqlserver/cross-match/Install_SQLxMatch.sql](https://github.com/sciserver/sqlxmatch/tree/main/sql/sqlserver/cross-match/Install_SQLxMatch.sql)
           

    We installed this procedure in the `xmatchdb` database, which is accessible as the `xmatch` database context in CasJobs, to which users can connect and then run cross-match queries.

    This script also installs several other procedures and functions, but those are intended to be used internally by the cross-match code only.


- **Utilities**

    Although not necessary for running a cross-match, several utility functions, procedures, and views can be installed as well in the same database where `SQLxMatch` is installed:

    - **Catalog table views**

        The astronomical catalogs are physically stored as tables in several databases in the same database server where `xmatchdb` is located. The database names conform to the following pattern: 
        
            SkyNode_<CatalogName>


        To simplify the cross-match queries, we create in `xmatchdb` multiple views to the tables (and views) in all those databases, in the form of
        
            <CatalogName>_<TableName>


        For creating those views, we run the script 
        
        [/sql/sqlserver/catalog/CreateCatalogTableViews.sql](https://github.com/sciserver/sqlxmatch/tree/main/sql/sqlserver/catalog/CreateCatalogTableViews.sql)

    - **Schema Metadata**

        We store the descriptions of tables, views and columns related to all the catalogs in tables under the [TAP SCHEMA](https://ivoa.net/documents/TAP/20190927/REC-TAP-1.1.html) in the `xmatchdb` database.
        In order to make the metadata more accessible, we create views to those TAP tables, so that they can be directly queries by the users. The SQL scripts for creating that are located under [/sql/sqlserver/metadata/](https://github.com/sciserver/sqlxmatch/tree/main/sql/sqlserver/metadata/), and should be executed in the specified ordered steps.


**Usage**
-----------

- **SQLxMatch stored procedure**

    Although several more complex use cases can be found in demo Jupyter Notebooks under the [demo](https://github.com/sciserver/sqlxmatch/tree/main/demo) folder, all follow the pattern of a basic two-table cross-match:

        EXECUTE SQLxMatch @table1='CatalogTable1', @table2='CatalogTable2', @radius=5

    which returns the following output table:
        
        TABLE(id1, id2, sep)

    The first two input parameters are the names of catalog tables, views, or temporary tables located in the CasJobs `xmatch` database context. This context already contains several table views to specific astronomical catalog tables, and are named as `<CatalogName>_<TableName>`. <br>
    The code assumes that the two input tables at least contain columns named `RA` (Right Ascension), `Dec` (Declination), and `ObjID` (unique object or row identifier). If the names are different, then those can be passed as extra input parameters as well (see below). <br>
    The third parameter is the search radius, measured in arcseconds. 
    
    The output table contains all objects found within the input search radius, although it will return only the closest match if the `@only_nearest` input parameter is set to 1 (see below). The first two columns in the returned table include the IDs of the objects in the first and seconds input tables, respectively, and the third column is the separation distance in arcseconds.

    The code will run faster if the 3-D cartesian coordinates of an object located on the surface of a unit-radius sphere (named as `cx`, `cy`, and `cz`) are already present as columns under those names in the input tables. The reason is that the cross-match code works internally with those coordinates (rather than with `RA`, `Dec`), and then it will not have to calculate them on the fly in that case. <br>
    Similarly, the presence of the precomputed `zoneid` column in the catalog tables (based on a zone height of 4 arcseconds) will speed up the code, although it can be calculated on the fly if missing. 


    <b>INPUT PARAMETERS:</b> <br>
    <ul>
    <li> <b>@table1 NVARCHAR(128) or SYSNAME</b>: name of first input catalog. Can be any of these formats: 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'
    <li> <b>@table2 NVARCHAR(128) or SYSNAME</b>: name of first input catalog. Can be any of these formats: 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'
    <li> <b>@radius FLOAT</b>: search radius around each object, in arcseconds. Takes a default value of 10 arcseconds.
    <li> <b>@id_col1 NVARCHAR(128) or SYSNAME</b>: name of the column defining a unique object identifier in catalog @table1. Takes a default value of 'objid'.
    <li> <b>@id_col2 NVARCHAR(128) or SYSNAME</b>: name of the column defining a unique object identifier in catalog @table2. Takes a default value of 'objid'.
    <li> <b>@ra_col1 NVARCHAR(128) or SYSNAME</b>: name of the column containing the Right Ascension (RA) in degrees of objects in catalog @table1. Takes a default value of 'ra'.
    <li> <b>@ra_col2 NVARCHAR(128) or SYSNAME</b>: name of the column containing the Right Ascension (RA) in degrees of objects in catalog @table2. Takes a default value of 'ra'.
    <li> <b>@dec_col1 NVARCHAR(128) or SYSNAME</b>: name of the column containing the Declination (Dec) in degrees of objects in catalog @table1. Takes a default value of 'dec'.
    <li> <b>@dec_col2 NVARCHAR(128) or SYSNAME</b>: name of the column containing the Declination (Dec) in degrees of objects in catalog @table2. Takes a default value of 'dec'.
    <li> <b>@max_catalog_rows1 BIGINT</b>: default value of NULL. If set, the procedure will use only the TOP @max_catalog_rows1 rows in catalog @table1, with no special ordering.
    <li> <b>@max_catalog_rows2 BIGINT</b>: default value of NULL. If set, the procedure will use only the TOP @max_catalog_rows2 rows in catalog @table2, with no special ordering.
    <li> <b>@output_table NVARCHAR(128) or SYSNAME</b>: If NOT NULL, this procedure will insert the output results into the table @output_table (of format 'server.database.schema.table', 'database.schema.table', 'database.table', or simply 'table'), which must already exist and be visible within the scope of the procedure. If set to null, the output results will be simply returned as a table resultset. Takes a default value of NULL.
    <li> <b>@only_nearest BIT</b>: If set to 0 (default value), then all matches within a distance @radius to an object are returned. If set to 1, only the closest match to an object is returned.
    <li> <b>@sort_by_separation BIT</b>: If set to 1, then the output will be sorted by the 'id1' and 'sep' columns. If set to 0 (default value), no particular ordering is applied.
    <li> <b>@include_sep_rank BIT</b>: If set to 1, then the output table will include an extra column named 'sep_rank', denoting the rank of all matches to an object when sorted by angular separation. If set to 0 (default value), this column is not included.
    <li> <b>@include_radec BIT </b>: If set to 1, then the output table will contain the original (RA, Dec) columns from both input tables, as ra1, dec1, ra2, and dec2.
    <li> <b>@print_messages BIT </b>: If set to 1, then time-stamped messages will be printed as the different sections in this procedure are completed.
    </ul>

    <b>RETURNS:</b> <br>
    <ul>
        <li><b>TABLE (id1, id2, sep)</b>, where id1 and id2 are the unique object identifier columns in @table1 and @table2, respectively, and sep (FLOAT) is the angular separation between objects in arseconds. 
            
    or
    <li><b>TABLE (id1, id2, sep, ra1, dec1, ra2, dec2)</b> when @include_radec=1
    
    or
    <li><b>TABLE (id1, id2, sep, sep_rank)</b> when @include_sep_rank=1
    

    or
    <li><b>TABLE (id1, id2, sep, sep_rank, ra1, dec1, ra2, dec2)</b> when @include_radec=1 and @include_sep_rank = 1.
    </ul>    


<br>


- **Catalog Metadata**

    We have created views to the tables under the `TAP_SCHEMA` schema, which allow to easily retrieve metadata related to the astronomical catalogs, including table, and column descriptions:


        SELECT * FROM Catalogs  

        SELECT * FROM Tables

        SELECT * FROM Columns



