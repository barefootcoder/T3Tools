#! /usr/bin/perl

use strict;

open(QRP, "qrp_invoice.txt") or die("can't open TXT file");
open(SQL, ">qrp_invoice.sql") or die("can't open SQL file");
print SQL "begin tran\ngo\n\n";
while ( <QRP> )
{
	chomp;
	s/\cM//g;
	my ($billdate, $invnum, $client, $memo, $amount) = split('\t');
	die unless $client eq 'QRP';
	my ($date) = $memo =~ m@(\d+/\d+/\d+)@;
	$date = $billdate unless defined($date);
	$amount =~ s/,//g;
	print SQL "insert invoice\n";
	print SQL "	(client, invoice_number, invoice_amount, invoice_billdate,\n";
	print SQL "			invoice_paydate, create_user, create_date)\n";
	print SQL "values ('807', '$invnum', $amount, '$billdate',\n";
	print SQL "		'$billdate', 'buddy', getdate())\n";
	print SQL "go\n";
	print SQL "insert materials_log\n";
	print SQL "	(client, proj, date, amount_billed, amount_paid, invoice_id,\n";
	print SQL "			create_user, create_date)\n";
	print SQL "select '807', 'MDB', '$date', $amount, $amount, i.invoice_id,\n";
	print SQL "		'buddy', getdate()\n";
	print SQL "from invoice i\n";
	print SQL "where i.invoice_number = '$invnum'\n";
	print SQL "go\n\n";
}
print SQL "rollback tran\ngo\n\n";
close(SQL);
close(QRP);
