#!/usr/bin/perl

while(<>) { 
  chomp;
  print "$_\n" unless (/^\d+\t\d+(\t6)?$/);
}
