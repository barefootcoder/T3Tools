#!/usr/bin/perl -w

open(INFILE,"dto-test.dat") or die "can't open file: $!\n";
open(OUTFILE,">dto-test-fixed.dat") or die "can't open file: $!\n";

while (<INFILE>)
{
	s/
	\( # a paren
	(\d\d\d) # followed by three digits, $1
	\) # then another paren
	\s # then a single whitespace
	(\d\d\d) # prefix, $2
	\- # dash
	(\d\d\d\d) # last 4, $3
	/$1$2$3/xg;
	print OUTFILE;
}
close INFILE;
close OUTFILE;
