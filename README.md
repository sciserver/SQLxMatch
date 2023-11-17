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

## **Documentation**

Instructions on how to install and operate `SQLxMatch` can found under the [docs](https://github.com/sciserver/sqlxmatch/tree/main/docs) folder.

## **Examples**

Example Jupyter Notebooks and demos can be found under [demo](https://github.com/sciserver/sqlxmatch/tree/main/demo) folder.

## **Citation**

Taghizadeh-Popp, M. and Dobos, L. (2023) “SQLxMatch: In-Database Spatial Cross-Match of Astronomical Catalogs”. Zenodo. doi: 10.5281/zenodo.10142771.

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.10142770.svg)](https://doi.org/10.5281/zenodo.10142770)

## **License**

All code and contents of this repository are licensed under the Apache 2.0 license. For more details see the [LICENSE.txt](https://github.com/sciserver/sqlxmatch/tree/main/LICENSE.txt) file.


