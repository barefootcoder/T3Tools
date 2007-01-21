###########################################################################
#
# format
#
###########################################################################
#
# A few subs, which allows you to actually _use_ Perl formats:
#
#		my $formatted = swrite(MY_FORMAT, @stuff);
#		# swrite() treats its first argument as a Perl-style format
#		# all other args are expected to be the variables defined in the format
#		# it returns a formatted string
#
#		writeln(MY_FORMAT, @stuff);
#		# writeln() treats its first argument as a Perl-style format
#		# all other args are expected to be the variables defined in the format
#		# first, writeln() will append $\ (\n by default) to MY_FORMAT, unless it is already there
#		# then writeln() prints the formatted string to the currently selected filehandle (STDOUT by default)
#
# FORMATS WITH swrite() AND writeln()
#
# In general, most standard Perl formats should work.  There are some additional features and caveats,
# however.
#
#		1) Undefined Variables
#		Undefined variables sent to either swrite() or writeln() are treated exactly like empty strings.  In
#		general, this is considered to be a Good Thing(tm).  If you disagree, you should make other
#		arrangements (like checking the vars before you call the funcs, or write your own damn funcs).
#
#		2) Multiline Formats
#		These are achieved as normal, that is by using a ^ format field instead of a @ format field, but you
#		should note that putting other formats _after_ a multiline format on the same line is probably doomed
#		to failure.  Also, swrite and writeln support an additional feature, which is the continuation
#		multiline format.  For example, let's say you want your output to look like this:
#
#				Description:	Here's some text, which may continue
#								on till the next line or might even
#								go on longer.
#
#		Your problem is that your format will need to look something like:
#
#				Description:	^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#				~~				^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#
#		but this is not going to work for you because you now have two different formats for the same
#		variable.  If you sent the same variable twice to swrite or writeln, you'd see the first line
#		repeated, which is definitely not what you want.  Therefore, make your format look like:
#
#				Description:	^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<&
#				~~				^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#
#		Note that the only difference is the & character at the end of the first line.  This indicates that
#		the same value should be continued to the next line.  When you do this, make sure there are no formats
#		between the continuation and the next format for that variable, and only send the variable itself once
#		to swrite or writeln.
#
#		One additional caveat: the & is replaced with the character in front of it, so don't try to pass a
#		format like "^&".  Your format must be at least 3 characters to use this feature.
#
#		3) Date Formats
#		Some basic functionality to allow you to format a time integer (i.e., a number of seconds since the
#		epoch, such as might be returned by time()) is included.  To allow maximum flexibility, a date format
#		is defined a bit differently from other formats.  A date format starts with either @ or #, and
#		continues until it hits whitespace (or the end of the format string).  For this format, recognizable
#		pieces which describe the month, day, year, hours, minutes, or day of week are substituted with the
#		relevant pieces.  If a piece begins with @, it is space-padded; if it begins with #, it is
#		zero-padded.  Here are some examples, using January 5, 1990:
#
#				@m/@d/@y		# yields " 1/ 5/90"
#				@m/@d/@yyy		# " 1/ 5/1990" (no Y2K problem)
#				#m-#d-#yyy		# "01-05-1990" (no real difference for years)
#				@m-#d-@yyy		# " 1-05-1990" (weird, but legal)
#				@ww,#d/#m/#y	# "Fri,05/01/90" (can't really control case)
#				@ww #m-#d-#y	# "Fri 01-05-90" (but must send var twice!)
#								# note that "#ww" doesn't make any sense
#
#		That last example is worth stressing: if you put a literal space in your format, what you're really
#		doing is making two separate formats, and that means you have to send your variable twice.
#
#
# ADDITIONAL FUNCTIONS
#
# A function which allows you deal with double-quoted, comma-separated values (commonly referred to as CSV)
# just as you would a normal split:
#
#	my @fields = CSV::split($expr);
#	# /PATTERN/ not needed; always assumed to be , (with double-quoting)
#	# LIMIT always assumed to be -1 (i.e., trailing null fields not stripped)
#	# if EXPR ($expr) is omitted, will split $_
#	# can return undef if (e.g.) double quotes don't match
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2000-2007 Barefoot Software
#
###########################################################################

package Barefoot::format;

### Private ###############################################################

use strict;
use warnings;

use Text::CSV;
use Date::Format;
use Data::Dumper;

use Barefoot;


use base qw<Exporter>;
use vars qw<@EXPORT>;
@EXPORT = qw<swrite writeln>;

sub swrite;
sub writeln;

# hash to correspond our date formats with those understood by Date::Format
our %date_fmt =
(
	'@m'	=>	'%L',
	'@d'	=>	'%e',
	'@y'	=>	'%y',
	'@yyy'	=>	'%Y',
	'@ww'	=>	'%a',
	'#m'	=>	'%m',
	'#d'	=>	'%d',
	'#y'	=>	'%y',
	'#Y'	=>	'%Y',
);

# can't make these true constants or else we can't interpolate with them
our $STD_FMT = '\@[<>|]*';
our $MLINE_FMT = '\^[<>|]*\&?';
our $NUM_FMT = '[@^]\#*\.\#*';
our $DATE_FMT_PART = '[@\#][mdywHMS]+';
our $DATE_FMT = $DATE_FMT_PART . '.*?(?=\s|$)';


#
# Subroutines:
#

sub swrite
{
	my ($format, @vars) = @_;

	# clear accumulator
	$^A = "";

	# break up the format into lines
	my $pos = 0;
	my $continuation = false;
	my $terminator = $\ || "\n";
	foreach (split(/(?<=$terminator)/, $format))
	{
		# now break each line into pieces
		my @pieces = split( / ( $DATE_FMT | $NUM_FMT | $MLINE_FMT | $STD_FMT ) /x, $_, -1 );
		debuggit(4 => Dumper(\@pieces));

		# start where we left off, but continuation makes us back up one
		if ($continuation)
		{
			--$pos;
			$continuation = false;
		}
		my $startpos = $pos;

		# handle different types of formats
		foreach (@pieces)
		{
			# ignore undef's (make them "")
			$vars[$pos] = "" unless defined $vars[$pos];

			if ( / ^ $STD_FMT $ /x )
			{
				# nothing special to do, standard format will take care of it

				# skip to next variable
				++$pos;
			}
			elsif ( / ^ $MLINE_FMT $ /x )
			{
				# mostly nothing to do; just check for continuation char (&)
				if ( /(.)\&$/ )
				{
					$continuation = true;
					substr($_, -1) = $1;
				}

				# skip to next variable
				++$pos;
			}
			elsif ( / ^ $NUM_FMT $ /x )
			{
				# nothing special to do, standard format will take care of it

				# skip to next variable
				++$pos;
			}
			elsif ( / ^ $DATE_FMT $ /x )
			{
				# substitute the various pieces with specs understood
				# by Date::Format, these are stored in the %date_fmt hash
				my $format = $_;
				$format =~ s/($DATE_FMT_PART)/$date_fmt{$1}/eg;
				debuggit(3 => "translated", $_, "into", $format);

				# now put a generic format in the format string and
				# the results of Date::Format in the variable list
				$_ = '@' . '>' x (length($_) - 1);
				$vars[$pos] = time2str($format, $vars[$pos]);

				# skip to next variable
				++$pos;
			}
		}

		my $template = join('', @pieces);
		debuggit(3 => "template is [[", $template, "]]");
		if ($pos > $startpos)
		{
			debuggit(3 => "formline with vars from", $startpos, "to", $pos - 1);
			formline($template, @vars[$startpos..$pos-1]);
		}
		else
		{
			$^A .= $template;
		}
		debuggit(3 => "after format, accum is [[", $^A, "]]");
	}

	return $^A;
}

sub writeln
{
	my $format = shift;
	my $terminator = $\ || "\n";
	$format .= $terminator unless $format =~ /$terminator\Z/;
	debuggit(3 => "new format is [[", $format, "]]");
	print swrite($format, @_);
}


package CSV;

sub split
{
	my ($expr) = @_;
	$expr = $_ unless defined $expr;

	my $csv = Text::CSV->new();
	return undef unless $csv->parse($expr);
	return $csv->fields();
}


###########################
# Return a true value:
###########################

1;
