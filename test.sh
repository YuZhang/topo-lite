#!/bin/sh
bgpdump -mv ../bgp-data/bview.20020722.2337.gz | ./extractor.pl 
