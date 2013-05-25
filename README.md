topo-lite
=========

extract AS topology from BGP view projects

- MRT to plain txt
     - a modified bgpdump: hg clone https://bitbucket.org/dkhenry/bgpdump (the original bgpdump has bugs)
     - don't need unzip as bgpdump can handle uncompressed, gzip, and bz2 files
     - don't warry about 32bit ASN. bgpdump and perl can handle it.
