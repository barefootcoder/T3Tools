#! /usr/bin/perl

use strict;


open(INV, "invoice.txt") or die("no invoice.txt to open");
open(SQL, ">invoice.sql") or die("can't open invoice.sql");
while ( <INV> )
{
	chomp;
	s/\cM//;
	my ($date, $number, $client, $memo, $amount) = split('\t');
	$amount =~ s/,//g;
	$client =~ s/'/''/g;
	print SQL "update invoice\n";
	print SQL "    set client = c.client, invoice_billdate = '$date',\n";
	print SQL "        invoice_amount = $amount\n";
	print SQL "    from invoice i, client c";
	print SQL "    where i.invoice_number = '$number'\n";
	print SQL "    and c.name = '$client'\n";
	print SQL "go\n\n";
}
close(INV);
close(SQL);
