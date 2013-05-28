topo-lite
=========

Extract AS topology from BGP view projects

- Repositories of BGP view projects:
    - [University of Oregon Route Views](http://archive.routeviews.org)
    - [RIPE RIS Raw Data](http://data.ris.ripe.net)
    - [PCH Route-Server RIB Dumps](https://www.pch.net/resources/data.php)
    - [Internet2 NOC BGP RIB Dumps](http://ndb7.net.internet2.edu/bgp)

- Prerequisite
    - *install* [a modified bgpdump by dkhenry](https://bitbucket.org/dkhenry/bgpdump) (which fixes bugs in the original one).
    - bogus ASN list from [IANA's as-numbers.txt](http://www.iana.org/assignments/as-numbers/as-numbers.txt) retrived on 2013-05-24
    - gzip and bzip2, although bgpdump can handle gzip and bz2 files
    - large disk space if 


- Checklist in the case of errors
    - [ ] Have URLs to the repos been changed?  

- Notes
    - don't warry about 32bit ASN. bgpdump and perl can handle it.
