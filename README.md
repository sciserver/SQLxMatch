# dbXmatch
In-database cross-match of astronomical objects.


<h3> Cross-matching objects in astronomical databases.</h3>

[SciServer](https://apps.sciserver.org) offers the capability of cross-matching objects across multiple astronomical catalogs. These catalogs are available as tables in remote databases `in the cloud` through the [CasJobs](https://skyserver.sdss.org/CasJobs) web interface.

The cross-match is run by executing a simple SQL stored procedure called `sp_xmatch`. This procedure implements the Zones Algorithm ([[1]](https://arxiv.org/abs/cs/0701171), [[2]](https://arxiv.org/abs/cs/0408031), which involves relational database algebra and B-Trees to run a 2-dimensional spatial cross-match between 2 catalogs of objects stored as database tables. These input tables must contain at least RA, Dec and ID columns.

The advantage of this <i>`in-database`</i> remote cross-match, compared to other <i>`in-memory`</i> local cross-match software libraries, is that it uses the remote database server's own computing/storage resources to filter and cross-match the full catalogs right away, having only a relatively small-sized cross-match output table returned to the user.
This can be faster and more efficient than having users to download the catalogs into their own computers (if they have big enough storage), and then load them in python for filtering and running the cross-match, for example.


