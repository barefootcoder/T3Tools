# this is a set of test modules for the T3 engine designed to be
# used in conjunction with test_t3engd

use strict;

T3::register_module(test => \&test_module);
T3::register_module(large_output => \&large_output_module);

1;


# subs

sub test_module
{
	print "TEST OUTPUT\n";
	T3::debug("printed to pipe");
}

sub large_output_module
{
	for my $x (1..1_000)
	{
		print "TEST." x 100, "\n";
	}
	T3::debug("printed to pipe");
}
