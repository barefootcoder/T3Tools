###########################################################################
#
# input
#
###########################################################################
#
# General routines to help with script input.
#
#
# get_yn prints a prompt, accepts input, and returns 1 (true) if the input
# begins with 'y' or 'Y', otherwise returns 0 (false).  Default value is
# always false.
#
#
# input prints a prompt if given, will return a default value if given and
# the user provides no input, otherwise returns whatever input the user
# gives (chomped).
#
#
# menu_select works similarly to the "select" command of ksh, but with more
# emphasis on _which_ choice you made, as opposed to _what_ the choice is.
#
#		my $choice = menu_select("Pick one:", @choices);
#		print "You chose: $choices[$choice]\n";
#		# *NOT* print "You chose: $choice\n"; !!
#
# You may also use options with menu_select.  To do so, make the final
# argument (or the last element of your menu items array; menu_select
# obviously can't tell the difference) a reference to a hash containing the
# options you want to set.  Like so:
#
#		my $choice = menu_select("Choose:", @choices, { LMARGIN => 3 });
#
# Here are the valid options menu_select understands:
#
#		LMARGIN		=>	Distance from left side of screen for menu (default: 0)
#		TMARGIN		=>	Number of blank lines before menu (default: 0)
#		SPBETWEEN	=>	Number of spaces between menu item columns (default: 1)
#		HEADER		=>	Text to print above the menu.  This must be a single
#						string, though of course it may be several lines long.
#						If the header is so long that it cannot fit on the
#						screen (along with the menu itself and the prompt),
#						then the header is truncated to a proper number of
#						lines (see also TRUNC_MSG).  The LMARGIN and TMARGIN
#						options do *not* apply to the header; if you want
#						margins for your header, apply them yourself when you
#						(default: "")
#						build the string.  HEADER should end with a newline.
#		TRUNC_MSG	=>	If the header needs to be truncated, this message is
#						printed at the bottom (i.e., underneath the HEADER,
#						but before the TMARGIN and menu itself).  For instance,
#						it might be something like "<More ...>".  The number
#						of lines in TRUNC_MSG is taken into consideration when
#						truncating HEADER.  Like HEADER, TRUNC_MSG should end
#						with a newline.  (default: "")
#
#	
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 1999-2003 Barefoot Software, Copyright (c) 2004-2006 ThinkGeek
#
###########################################################################

package Barefoot::input;

### Private ###############################################################

use strict;
use warnings;

use Term::Size;
use Data::Dumper;
use Perl6::Slurp;
use Array::PrintCols;
use File::Temp qw<tempfile>;

use Barefoot::base;
use Barefoot::range;
use Barefoot::string;


use base qw<Exporter>;
use vars qw<@EXPORT_OK>;

@EXPORT_OK = qw< get_yn input input_text menu_select $COLS $ROWS >;


our ($COLS, $ROWS) = Term::Size::chars;


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
	print STDERR "get_yn: got response $yn" if DEBUG >= 4;
	return $yn =~ /^y/i;
}


sub input
{
	my ($prompt, $default, $opts) = @_;
	print STDERR "input: starting function\n" if DEBUG >= 5;

	local ($|) = 1;														# autoflush stdout

	my $answer = "";
	INPUT:
	{
		print $prompt if $prompt;
		print " (", $default, ")" if defined($default);
		print "  " if defined($prompt);

		print STDERR "input: about to get a line of input from stdin\n" if DEBUG >= 5;
		$answer = <STDIN>;
		print STDERR "input: got a line of input from stdin\n" if DEBUG >= 5;
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


sub input_text
{
	my ($name, $explan, $opts) = @_;
	$opts ||= {};
	print STDERR "input_text: args name $name, explanatory text <<$explan>>, opts ", Dumper($opts) if DEBUG >= 4;

	my $max_msg = $opts->{'MAXLEN'} ? " (maximum length $opts->{'MAXLEN'} chars)" : '';
	my $text = $opts->{'DEFAULT'} || '';

	my $error;
	TEXT: {

		print STDERR "input_text: cycled back around again\n" if DEBUG >= 5;
		if ($opts->{'EDITOR'})
		{
			my ($fh, $tmpfile) = tempfile();
			my $separator = "=" x 80;
			print $fh "$text\n$separator\n";
			print $fh "<< ERROR! $error >>\n\n" if $error;
			print $fh "Enter $name above$max_msg\n";
			print $fh $explan;
			#close($fh);

			system($opts->{'EDITOR'}, $tmpfile);
			$text = slurp $tmpfile;
			$text =~ s/\n?${separator}.*$//s;
			print STDERR "input_text: text before adjustment is <<$text>>\n" if DEBUG >= 5;
		}
		else
		{
			print "  {$error}\n\n" if $error;

			print "Enter $name below$max_msg\n$explan";
			print "Enter ^D (control-D) on a line by itself to finish the comments.\n";
			local ($/) = undef;
			$text = input();

			<STDIN>;					# HACK! don't know why this is necessary
		}

		$text =~ s/^\s+$//mg if $opts->{'STRIP_BLANK_LINES'};			# no completely blank lines
		$text =~ s/^\s*\n+\s*// if $opts->{'ALLTRIM'};					# no extra newlines in front
		$text =~ s/\s*\n+\s*$// if $opts->{'ALLTRIM'};					# none at the end either

		print STDERR "input_text: text after adjustments is <<$text>>\n" and <STDIN> if DEBUG >= 5;

		$error = "You must have $name" and redo TEXT if $opts->{'REQUIRED'} and not $text;
		$error = "\u$name too long!" and redo TEXT if $opts->{'MAXLEN'} and length($text) > $opts->{'MAXLEN'};
	}

	print STDERR "input_text: final text is <<$text>>\n" and <STDIN> if DEBUG >= 4;
	return $text;
}


sub menu_select
{
	my ($prompt, @choices) = @_;
	my $options = {};
	$options = pop @choices if ref $choices[-1] eq "HASH";

	# set defaults in case not specified
	$options->{LMARGIN} ||= 0;
	$options->{SPBETWEEN} ||= 1;
	$options->{TMARGIN} ||= 0;

	my $spec = "%" . length(scalar(@choices)) . "d";

	my $choice = 1;
	my $max_choice_len = 0;
	my %opt_letters;
	foreach (@choices)
	{
		# save initial letter so menu items can be referenced that way
		# if two choices have the same initial letter, the first one wins
		# as of now, there is no way to specify the second one by letter
		my $initial_letter = lc substr($_, 0, 1);
		$opt_letters{$initial_letter} = $choice unless exists $opt_letters{$initial_letter};

		$_ = sprintf "$spec: $_", $choice;
		$max_choice_len = range::max($max_choice_len, length($_));
	}
	continue
	{
		++$choice;
	}

	# pointless for print_cols to sort our list
	$Array::PrintCols::PreSorted = true;
	my $menu = format_cols \@choices, $max_choice_len + $options->{SPBETWEEN}, $COLS, $options->{LMARGIN};

	# get header and make sure it will fit on screen
	my $header = $options->{HEADER} || "";
	my $hlines = string::count($header, "\n");
	my $mlines = string::count($menu, "\n");
	# final 2 is for prompt and empty line above it
	my $max_hlines = $ROWS - $options->{TMARGIN} - $mlines - 2;
	if ($hlines > $max_hlines)
	{
		if ($options->{TRUNC_MSG})
		{
			$max_hlines -= string::count($options->{TRUNC_MSG}, "\n");
		}
		else
		{
			$options->{TRUNC_MSG} = "";
		}

		$header =~ /^ ( (.*?\n){$max_hlines} ) /x;
		$header = $1 . $options->{TRUNC_MSG};
	}

	MENU: {
		print "$header";
		print "\n" x $options->{TMARGIN};
		print "$menu\n$prompt ";
		$choice = <STDIN>;
		print "\n";

		chomp $choice;
		if (not defined $choice)
		{
			# don't think this actually possible, but JIC
			redo MENU;
		}
		elsif ($choice =~ /^\d+$/)
		{
			redo MENU if $choice < 1 or $choice > @choices;
		}
		else
		{
			$choice = $opt_letters{lc $choice};
			redo MENU unless $choice;
		}

		return $choice - 1;
	}
}
