#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# input
#
###########################################################################
#
# General routines to help with script input.
#
# get_yn prints a prompt, accepts input, and returns 1 (true) if the input
# begins with 'y' or 'Y', otherwise returns 0 (false).  Default value is
# always false.
#
# input prints a prompt if given, will return a default value if given and
# the user provides no input, otherwise returns whatever input the user
# gives (chomped).
#
# menu_select works very much like the "select" command of ksh.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 1999-2002 Barefoot Software.
#
###########################################################################

package Barefoot::input;

### Private ###############################################################

use strict;

use Array::PrintCols;

use Barefoot::base;
use Barefoot::range;


use base qw<Exporter>;
use vars qw<@EXPORT_OK>;

@EXPORT_OK = qw<get_yn input menu_select>;

1;


#
# Subroutines:
#


sub get_yn
{
	my ($prompt) = @_;

	# prompt is optional
	print $prompt if defined $prompt;
	print "  [y/N] ";

	my $yn = <STDIN>;
	return 1 if $yn =~ /^y/i;
	return 0;
}


sub input
{
	my ($prompt, $default, $opts) = @_;

	local ($|) = 1;							# autoflush stdout

	my $answer = "";
	INPUT:
	{
		print $prompt if $prompt;
		print " (", $default, ")" if defined($default);
		print "  " if defined($prompt);

		$answer = <STDIN>;
		chomp $answer;

		if ($answer ne "" and exists $opts->{VALID})
		{
			unless ($opts->{VALID}->($answer))
			{
				print $opts->{VALID_ERR} if exists $opts->{VALID_ERR};
				redo INPUT;
			}
		}

		if (exists $opts->{CONVERT})
		{
			my $converted = $opts->{CONVERT}->(
					$answer ne "" ? $answer : $default );
			if (defined $converted)
			{
				return $converted;
			}
			else
			{
				print $opts->{VALID_ERR} if exists $opts->{VALID_ERR};
				redo INPUT;
			}
		}
	}

	return ( $answer ne "" ) ? $answer : $default;
}


sub menu_select
{
	my ($prompt, @choices) = @_;

	my $spec = "%" . length(scalar(@choices)) . "d";

	my $choice = 1;
	my $max_choice_len = 0;
	foreach (@choices)
	{
		$_ = sprintf "$spec: $_", $choice;
		$max_choice_len = range::max($max_choice_len, length($_));
	}
	continue
	{
		++$choice;
	}

	# pointless for print_cols to sort our list
	$Array::PrintCols::PreSorted = true;

	MENU: {
		print_cols \@choices, $max_choice_len + 3, 0, 2;

		print "\n$prompt ";
		$choice = <STDIN>;
		print "\n";

		# q or Q or quit or anything beginning with a Q returns undef
		return undef if $choice =~ /^q/i;

		chomp $choice;
		redo MENU if not $choice or $choice !~ /^\d+$/
				or $choice < 1 or $choice > @choices;
		return $choice - 1;
	}
}
