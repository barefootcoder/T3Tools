# this is a set of test modules for the T3 engine designed to be
# used in conjunction with test_t3engd

use strict;

T3::Server::register_request(test => \&test_module);
T3::Server::register_request(large_output => \&large_output_module);
T3::Server::register_request(input => \&input_module);
T3::Server::register_request(request => \&request_module);

1;


# subs


sub test_module
{
	print "TEST OUTPUT\n";
	T3::debug("printed to pipe [test]");
}


sub input_module
{
	my $opts = shift;
	T3::debug("received " . scalar(@_) . " lines of input");
	print uc($_) foreach @_;
	T3::debug("printed to pipe [input]");
}


sub large_output_module
{
	my $opts = shift;
	for my $x (1 .. $opts->{num_lines})
	{
		print "TEST." x 100, "\n";
	}
	T3::debug("printed to pipe [large_output]");
}


sub request_module
{
	my $opts = shift;
	chomp @_;
	print join(';', $opts->{FROM}, $opts->{TO}, @_), "\n";
}
