###########################################################################
#
# Barefoot
#
###########################################################################
#
# This module provides base defintions for Barefoot modules and programs. Most simply, it defines the
# constants true and false, whose utility should be self-evident.
#
# More complexly, the module is used by Barefoot programs to handle debugging.  When use'd normally, thus:
#
#		use Barefoot;
#
# by a top-level script, the DEBUG constant is defined as 0.  However, the module may also be used thus:
#
#		use Barefoot(DEBUG => 3);
#
# to indicate that DEBUG should be defined as 3 instead.  The scripts typically use 5 debugging levels to
# output various amounts of information.
#
# Note that since DEBUG is a constant, code such as:
#
#		print STDERR "value is $val\n" if DEBUG >= 2;
#
# will not even be compiled when debugging is off (or when it's only set to 1, FTM).
#
# Of course, you should not _really_ use the "print STDERR" method.  There's a better way:
#
#		debuggit(3 => "value is", $val);
#
# This is cleaner, more precise, and adds a few niceties (see below for a complete list).  Your first argument
# must be the debug level (you can use comma instead of => if you want, of course, but the => looks sorta
# nifty).  All remaining arguments are printed to STDERR.  Calls to debuggit compile to nothing when DEBUG is
# zero, but they do remain if DEBUG is set to a positive but lower value than you specify (though of course
# they produce no output in that case).  But in that case you're in debug mode anyway so speed really isn't
# your primary goal.
#
# The following transformations are applied to your list of arguments to debuggit():
#
#		1) spaces are inserted between args
#		2) a newline is appended
#		3) undef's are replaced with <<undef>>
#		4) strings with leading and/or trailing spaces are surrounded with << >>
#
# Thus:
#
#		my $val1 = 6;
#		my $val2;
#		my $val3 = ' XX  ';
#		debuggit(3 => "value1", $val1, "value2", $val2, "value3", $val3);
#
# produces (assuming your current debug level is 3 or higher, of course):
#
#		value1 6 value2 <<undef>> value3 << XX  >>
#
# Additionally, if DEBUG is defined to any non-zero value, all further Barefoot modules will be drawn from
# your personal VCtools working copy of the code.  Note that it uses vctools-config to figure out where that
# is, so make sure you can access that program.
#
# You need to make sure you put your "use Barefoot" before any other "use" statements for Barefoot modules, or
# you won't be able to get the debugging versions of those modules.
#
# The value of DEBUG is designed to "fall through" to libraries and modules that are aware of it.  If you do
# this:
#
#				use Barefoot;
#
# in a module, it means that you wish to use the value of DEBUG that was set in a higher level module
# (probably the top level Perl program).  If no such value was ever set, DEBUG will be 0.
#
# Note that you have a distinct chicken-and-egg problem when testing changes to this particular module, in
# that the code that points you to your VCtools working copy is in here, so although turning debugging on
# guarantees that you get test copies of all your other Barefoot modules, you _won't_ get the test copy of
# Barefoot.pm.  Hopefully this module rarely needs to change so that isn't a big deal.
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2006-2009 Barefoot Software, Copyright (c) 2006-2007 ThinkGeek
# based on ideas originally set forth in the following modules:
#		Barefoot::debug, originally written 2000, (c) Barefoot Software
#		Barefoot::base, originally written 2001, (c) Barefoot Software
#		Geek::Dev::Debug, originally written 2004, (c) ThinkGeek
#		VCtools::Base, originally written 2004, (c) Barefoot Software/ThinkGeek
#
###########################################################################

package Barefoot;

### Private ###############################################################

use strict;
use warnings;

use Carp;
use FileHandle;

use base qw<Exporter>;
use vars qw<@EXPORT>;
@EXPORT = qw< true false >;


sub true();
sub false();


###########################
# Helper Routines:
###########################


sub _set_up_debug_value
{
	my ($caller_package, $debug_value) = @_;
	# print STDERR "debug value is ", (defined $debug_value ? $debug_value : "undefined"), "\n";
	my $caller_defined = defined eval "${caller_package}::DEBUG();";

	my $Debuggit_value = eval { Debuggit::DEBUG(); };
	my $Debuggit_loaded = defined $Debuggit_value;
	# print STDERR "Debuggit loaded is $Debuggit_loaded\n";

	# if Debuggit is loaded _and_ DEBUG is defined in our caller, assume that Debuggit was loaded
	# _by_ our caller; consequently, nothing left to do here
	return if $Debuggit_loaded and $caller_defined;

	# the "master" value is in the Barefoot namespace
	# get the master value: if it's undefined, we'll need to define it;
	# if it's defined, we'll need to use it as a default value
	# EXCEPTION: if Debuggit has been loaded, use the Debuggit value as the master value
	my $master_debug = $Debuggit_loaded ? $Debuggit_value : eval "Barefoot::DEBUG();";
	# print STDERR "master eval returns $master_debug and eval err is $@\n";

	if (not defined $debug_value)
	{
		# if already defined in the caller, just assume that all is well
		# with the world; in this one case (only) a duplicate is allowed
		return if $caller_defined;

		# if neither one is defined, assume 0 (debugging off)
		$debug_value = defined $master_debug ? $master_debug : 0;
	}

	croak("DEBUG already defined; don't use Barefoot(DEBUG => #) twice") if $caller_defined;

	eval "sub ${caller_package}::DEBUG () { return $debug_value; }";
	# print STDERR "set debug val to $debug_value in $caller_package and err was $@\n";

	# also have to tuck this value into the Barefoot namespace if it isn't already there
	eval "sub Barefoot::DEBUG () { return $debug_value; }" unless defined $master_debug;
	# $master_debug = eval "Barefoot::DEBUG();";
	# print STDERR "after all is said and done, master eval returns $master_debug and eval err is $@\n";

	# return whatever we came up with in case somebody else needs it
	return $debug_value;
}


sub _set_debuggit_func
{
	my ($caller_package, $debug_value) = @_;

	my $caller_loaded = defined eval qq{ ${caller_package}::debuggit(); 1; };
	# print STDERR "Debuggit loaded is $Debuggit_loaded\n";
	return if $caller_loaded;

	my $Debuggit_loaded = defined eval qq{ Debuggit::DEBUG(); };
	# print STDERR "Debuggit loaded is $Debuggit_loaded\n";

	if ($debug_value)
	{
		# print STDERR "going to try to set debuggit() in $caller_package because of value $debug_value\n";
		if ($Debuggit_loaded)
		{
			my $sub = eval qq{ package $caller_package; sub _define_debuggit__ { Debuggit->import(DEBUG => $debug_value) } };
			die("cannot create debuggit defining routine") if $@;
			eval qq{ ${caller_package}::_define_debuggit__(); };
			die("cannot call Debuggit::import") if $@;
		}
		else
		{
			my $print = q{
				print STDERR join(' ', map { !defined $_ ? '<<undef>>' : /^\s+/ || /\s+$/ ? "<<$_>>" : $_ } @_), "\n"
			};
			eval qq{ sub ${caller_package}::debuggit { $print if ${caller_package}::DEBUG() >= shift } };
			die("cannot create debuggit subroutine: $@") if $@;
		}
	}
	else
	{
		eval "sub ${caller_package}::debuggit { 0 };";
	}
}


my $already_prepended;
sub _redirect_modules_to_testing
{
	# print STDERR "going to prepend testing dirs\n";
	return if $already_prepended;

	my $working_dir = `/usr/local/bin/vctools-config --working`;
	chomp $working_dir;
	die("can't determine VCtools working dir") unless $working_dir;
	my $lib_testing_dir = "$working_dir/T3/Barefoot";

	unshift @INC, sub
	{
		my ($this, $module) = @_;

		if ($module =~ m@^Barefoot/(.*)$@)
		{
			my $bfsw_module = "$lib_testing_dir/$1";
			# print STDERR "module is $bfsw_module\n";
			if (-d $lib_testing_dir and -f $bfsw_module)
			{
				my $fh = new FileHandle $bfsw_module;
				if ($fh)
				{
					$INC{$module} = $bfsw_module;
					return $fh;
				}
			}
		}
		return undef;
	};

	$already_prepended = 1;
}


###########################
# Subroutines:
###########################


sub import
{
	my ($pkg, %opts) = @_;

	# print STDERR "here i am in base import!\n";
	$pkg->export_to_level(1, $pkg, 'true');
	$pkg->export_to_level(1, $pkg, 'false');

	my $caller_package = caller;
	# print STDERR "my calling package is $caller_package\n";

	$opts{DEBUG} = _set_up_debug_value($caller_package, $opts{DEBUG});

	_set_debuggit_func($caller_package, $opts{DEBUG});

	# prepend testing dirs into @INC path if we're actually in DEBUG mode
	# print STDERR "just before prepending, value is $debug_value\n";
	_redirect_modules_to_testing() if $opts{DEBUG};
}


sub true ()
{
	return 1;
}

sub false ()
{
	return 0;
}


###########################
# Return a true value:
###########################

1;
