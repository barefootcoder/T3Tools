#! /usr/local/bin/perl

# For RCS:
# $Date$
# $Log$
# $Id$
# $Revision$

###########################################################################
#
# string
#
###########################################################################
#
# Some generally useful string routines
#
###########################################################################

package string;

### Private ###############################################################

use strict;

1;


#
# Subroutines:
#


sub upper
{
	my ($str) = @_;
	"\U$str\E";
}

sub lower
{
	my ($str) = @_;
	"\L$str\E";
}

sub left
{
	my ($str, $count) = @_;
	return substr($str, 0, $count);
}

sub right
{
	my ($str, $count) = @_;
	return substr($str, -$count);
}

sub count
{
	my ($str, $tocount) = @_;
	my $count = ($str =~ s/\Q$tocount\E//g);
	return !defined($count) ? 0 : $count;
}

sub trim
{
	my ($str) = @_;
	$str =~ s/\s+$//;
	return $str;
}

sub ltrim
{
	my ($str) = @_;
	$str =~ s/^\s+//;
	return $str;
}

sub alltrim
{
	my ($str) = @_;
	$str =~ s/^\s*(.*?)\s*$/$1/;
	return $str;
}

sub pad
{
	my ($str, $len, $char) = @_;
	$char = ' ' unless defined($char);
	return left($str . $char x $len, $len);
}

sub lpad
{
	my ($str, $len, $char) = @_;
	$char = ' ' unless defined($char);
	return right($char x $len . $str, $len);
}

sub strip
{
	my ($str, $char) = @_;
	$str =~ s/$char//g;
	return $str;
}

use Text::Tabs ();				# don't import the functions
sub tab_align
{
	my ($str_before, $tabstop, $str_after, $tabwidth) = @_;
	$tabwidth = 4 unless defined($tabwidth);
	$Text::Tabs::tabstop = 4;
	my $expanded = Text::Tabs::expand($str_before);	# handle existing tabs
	my $after_column = $tabstop * $tabwidth;		# $str_after starts here

	# this calculates how many tabs we need ... obviously, if $str_before
	# is longer than will fit before the requested tabstop, this won't work
	my $num_tabs = ($after_column - length($expanded) - 1) / $tabwidth + 1;

	# now put it all together and send it back
	return $str_before . "\t" x $num_tabs . $str_after;
}
