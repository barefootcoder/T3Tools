#! /usr/bin/perl

use strict;
use Barefoot::array;

my @months = ('', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
		'Sep', 'Oct', 'Nov', 'Dec');

my (@dates, @gross_pay, @employer_pay);


open(PAY, "payroll.txt") or die("no payroll.txt to open");
while ( <PAY> )
{
	chomp;
	s/\cM//;
	if ($. == 2)
	{
		s/^\t//;
		@dates = split(/\t/);
		pop @dates;				# last column is totals, which we don't want
		foreach my $date (@dates)
		{
			my ($from_mon, $from_day, $from_yr, $to_mon, $to_day, $to_yr)
				= $date =~
				/(\w+) (\d+)(?:, '(\d+))? - (?:(\w+) )?(\d+), '(\d+)/;
			$from_yr = $to_yr unless defined($from_yr);
			$to_mon = $from_mon unless defined($to_mon);
			$from_mon = aindex(@months, $from_mon);
			$to_mon = aindex(@months, $to_mon);
			$date = "between '$from_mon/$from_day/$from_yr' and " .
					"'$to_mon/$to_day/$to_yr'";
			# print "$date\n";
		}
	}
	elsif (/^Total Gross Pay/)
	{
		s/,//g;
		@gross_pay = split(/\t/);
		shift @gross_pay;		# first column is label (toss it)
		pop @gross_pay;			# last column is totals (also unnecessary)
	}
	elsif (/^Total Employer Taxes and Contributions/)
	{
		s/,//g;
		@employer_pay = split(/\t/);
		shift @employer_pay;	# first column is label (toss it)
		pop @employer_pay;		# last column is totals (also unnecessary)
	}
}
close(PAY);

open(SQL, ">payroll.sql") or die("can't open payroll.sql");
for my $x (0..$#dates)
{
	print SQL "update payroll\n";
	print SQL "set payroll_amount = $gross_pay[$x],\n";
	print SQL "	overhead_amount = $employer_pay[$x]\n";
	print SQL "where check_date $dates[$x]\n";
	print SQL "go\n\n";
}
close(SQL);
