topo-lite
=========

Extract AS topology from BGP view projects

- BGP view projects:
    - [Route Views](http://archive.routeviews.org)
    - [RIPE RIS][http://data.ris.ripe.net]
    - [PCH Data][https://www.pch.net/resources/data.php]

- Prerequisite
    - *install* a modified bgpdump: hg clone https://bitbucket.org/dkhenry/bgpdump (the original bgpdump has bugs)
    - bogus ASN list from http://www.iana.org/assignments/as-numbers/as-numbers.txt retrived on 2013-05-24
    - gzip and bzip2, although bgpdump can handle gzip and bz2 files
    - large disk space if 


- Checklist in the case of errors
    - [] Have URLs to the repos been changed?  

- Notes
    - don't warry about 32bit ASN. bgpdump and perl can handle it.
