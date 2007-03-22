###########################################################################
#
# Barefoot::DataStore
#
###########################################################################
#
# This package provides a moderately thin layer around DBI to aid in
# RDBMS independence and legibility.  SQL passed through a DataStore
# is trivially translated for some simple substitutions.  Server name
# and database name, as well as any other connection parameters, are
# saved as a permanent part of the data store.  Once the data store is
# created, all the user needs is a data store name and a user name.
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2002-2007 Barefoot Software, Copyright (c) 2004-2007 ThinkGeek
#
###########################################################################

package DataStore;

### Private ###############################################################

use strict;
use warnings;

use version; our $VERSION = qv('2.0.1');

use DBI;
use Carp;
use Storable;
use Date::Format;
use Data::Dumper;
use Text::Balanced qw<:ALL>;

use Barefoot;
use Barefoot::date;
use Barefoot::DataStore::DataSet;


use constant CONFIG_ATTRIBS => qw< rdbms server connect_string user date_handling initial_commands >;

use constant EMPTY_SET_OKAY => 'EMPTY_SET_OKAY';

use constant PASSWORD_FILE => '.dbpasswd';

my $SCALAR_PH = qr/(?<=[^?])\?(?=[^?]|$)/;
my $HASH_PH = qr/(?:\(\s*)?\Q???\E(?:\s*\))?/;
my $ARR_PH = $HASH_PH;

my $QUERY_VAR = qr/\{(\w+)\}/;
my $QUERY_SUB = qr/^\{.+\}$/;


# load_table is just an alias for load_data
# it's just there for people who feel more comfortable matching it up
# with replace_table and append_table
{
	no warnings 'once';
	*load_table = \&load_data;
}


our $data_store_dir = DEBUG ? "." : "/etc/data_store";

our $base_types =
{
		Sybase		=>	{
							date		=>	'datetime',
							boolean		=>	'numeric(1)',
						},
		Oracle		=>	{
							int			=>	'number(10)',
							boolean		=>	'number(1)',
							money		=>	'number(19,4)',
							text		=>	'varchar2(2000)',
						},
		mysql		=>	{
							money		=>	'decimal(17,2)',
							boolean		=>	'bool',
						},
};

our $column_attributes =
{
		Sybase		=>	{
							null			=>	{
													order		=>	1,
											},
							'not null'		=>	{
													order		=>	1,
												},
							identity		=>	{
													order		=>	1,
													invalidates	=>	0,
													implies		=>	'primary key',
													unique		=>	1,
												},
							default			=>	{
													order		=>	0,
												},
							'primary key'	=>	{
													order		=>	2,
													unique		=>	1,
												},
						},
		Oracle		=>	{
							null			=>	{
													order		=>	1,
												},
							'not null'		=>	{
													order		=>	1,
												},
							default			=>	{
													order		=>	0,
												},
							'primary key'	=>	{
													order		=>	2,
													unique		=>	1,
												},
						},
		mysql		=>	{
							null			=>	{
													order		=>	0,
												},
							'not null'		=>	{
													order		=>	0,
												},
							identity		=>	{
													order		=>	2,
													invalidates	=>	[ 0, 1 ],
													implies		=>	'primary key',
													translate	=>	'auto_increment',
													unique		=>	1,
												},
							default			=>	{
													order		=>	1,
												},
							'primary key'	=>	{
													order		=>	3,
													invalidates	=>	0,
													unique		=>	1,
												},
						},
};

our $date_formats =
{
		Sybase		=>	{
							date_in		=> '%m/%d/%Y',				time_in		=> '%m/%d/%Y %T',
							date_out	=> '%b %e %Y %H:%M%p',		time_out	=> '%b %e %Y %H:%M%p',
							perl_date	=> 'int',
						},
		Oracle		=>	{
							date_in		=> '%d-%b-%Y',				time_in		=> '%d-%b-%Y %T',
							date_out	=> '%d-%b-%Y',				time_out	=> '%d-%b-%Y %T',
							perl_date	=> 'number(20)',
						},
		mysql		=>	{
							date_in		=> '%Y-%m-%d',				time_in		=> '%Y-%m-%d %T',
							date_out	=> '%Y-%m-%d',				time_out	=> '%Y-%m-%d %T',
							perl_date	=> 'bigint(20)',
						},

		string		=>	{
							date_in		=> '%Y%m%d',				time_in		=> '%Y%m%d%H%M%S',
							date_out	=> '%Y%m%d',				time_out	=> '%Y%m%d%H%M%S',
							beginning_of_time	=>	'00000000',
							end_of_time			=>	'99999999',
						},
		perl		=>	{
							date_in		=> '%s',					time_in		=> '%s',
							date_out	=> '%s',					time_out	=> '%s',
							beginning_of_time	=>	-2147483648,
							end_of_time			=>	2147483647,
						},
};

our $constants =
{
		Sybase		=>	{
							BEGINNING_OF_TIME	=>	"1/1/1753",
							END_OF_TIME			=>	"12/31/9999",
						},
		Oracle		=>	{
							BEGINNING_OF_TIME	=>	"01-JAN-0001",
							END_OF_TIME			=>	"31-DEC-9999",
						},
		mysql		=>	{
							BEGINNING_OF_TIME	=>	"1000-01-01",
							END_OF_TIME			=>	"9999-12-31",
						},
};

our $funcs =
{
		Sybase		=>	{
							today			=>	sub { "getdate()" },
							now				=>	sub { "getdate()" },
							ifnull			=>	sub { "isnull($_[0], $_[1])" },
							drop_index		=>	sub { "drop index $_[0].$_[1]" },
							place_on		=>	sub { "on $_[0]" },
						},
		Oracle		=>	{
							today			=>	sub { "sysdate" },
							now				=>	sub { "sysdate" },
							ifnull			=>	sub { "nvl($_[0], $_[1])" },
							drop_index		=>	sub { "drop index $_[1]" },
							place_on		=>	sub { "tablespace $_[0]" },
						},
		mysql		=>	{
							today			=>	sub { "curdate()" },
							now				=>	sub { "now()" },
							ifnull			=>	sub { "ifnull($_[0], $_[1])" },
							drop_index		=>	sub { "drop index $_[1] on $_[0]" },
							# no way to really implement this one AFAIK
							place_on		=>	sub { '' },
						},
};

our $procs = {};														# we don't use this, but someone else might


#
# Subroutines:
#


# helper methods


sub _login
{
	my $this = shift;

	if (exists $this->{'config'}->{'connect_string'})
	{
		my $server = $this->{'config'}->{'server'};
		debuggit(3 => "attempting to get password for server", $server, "user", $this->{'user'});

		debuggit(4 => "environment for dbpasswd: user", $ENV{'USER'}, "home", $ENV{'HOME'}, "path", $ENV{'PATH'});
		my $passwd;
		eval
		{
			$passwd = get_password($server, $this->{'user'});
		};
		croak("can't get db password: $@") unless defined $passwd;

		# connect to database via DBI
		# note that some attributes to connect are RDBMS-specific
		# this is okay, as they will be ignored by RDBMSes they don't apply to
		debuggit(4 => "connecting via:", $this->{'config'}->{'connect_string'});
		$this->{'dbh'} = DBI->connect($this->{'config'}->{'connect_string'}, $this->{'user'}, $passwd,
			{
				PrintError => 0,
				# Sybase specific attributes
				syb_failed_db_fatal => 1,
				syb_show_sql => 1,
			});
		croak("can't connect to data store as user $this->{'user'}: $DBI::errstr") unless $this->{'dbh'};
		debuggit(5 => "successfully connected");

		if (exists $this->{'initial_commands'})
		{
			foreach my $command (@{$this->{'initial_commands'}})
			{
				debuggit(1 => "now trying to perform command: $command");
				my $res = $this->do($command);
				debuggit(1 => "results has", $res->{'rows'}, "rows");
				debuggit(1 => "last error was", $this->{'last_err'});
				debuggit(1 => "statement handle isa", ref $res->{'sth'});
				croak("initial command ($command) failed for data store $this->{'name'}") unless defined $res;
			}
		}
	}
}


sub _set_date_types
{
	my $this = shift;

	my $date_handling = $this->{'config'}->{'date_handling'} || 'native';
	debuggit(3 => "DataStore: setting date types to", $date_handling);

	# note that we don't need to do anything here for native date handling
	if ($date_handling eq 'string')
	{
		configure_type($this, date => 'char(8)');
		configure_type($this, datetime => 'char(14)');
	}
	elsif ($date_handling eq 'perl')
	{
		my $rdbms = $this->{'config'}->{'rdbms'};
		configure_type($this, date => $date_formats->{$rdbms}->{'perl_date'});
		configure_type($this, datetime => $date_formats->{$rdbms}->{'perl_date'});
	}
}


sub _initialize_vars
{
	my $this = shift;

	$this->{'vars'} = {};
	my $constant_table = $constants->{$this->{'config'}->{'rdbms'}};
	$this->{'vars'}->{$_} = $constant_table->{$_} foreach keys %$constant_table;
	debuggit(5 => 'DataStore::_initialize_vars (post): $this', Dumper($this));
}


sub _make_schema_trans
{
	my $this = shift;

	$this->{'schema_translation'} = sub { eval $this->{'config'}->{'schema_translation_code'} }
			if exists $this->{'config'}->{'schema_translation_code'};
}


sub _set_date_handling
{
	my $this = shift;
	debuggit(5 => 'DataStore::_set_date_handling (pre): $this', Dumper($this));

	my $rdbms = $this->{'config'}->{'rdbms'};
	my $date_handling = $this->{'config'}->{'date_handling'} || 'native';
	debuggit(3 => "DataStore: setting date handling to", $date_handling);

	if ($date_handling eq 'native')
	{
		Barefoot::date->request_change_to_def_option(date_fmt => $date_formats->{$rdbms}->{'date_in'});
		Barefoot::date->request_change_to_def_option(time_fmt => $date_formats->{$rdbms}->{'time_in'});
	}
	else
	{
		croak("DataStore: unknown date handling type $date_handling") unless exists $date_formats->{$date_handling};
		Barefoot::date->request_change_to_def_option(date_fmt => $date_formats->{$date_handling}->{'date_in'});
		Barefoot::date->request_change_to_def_option(time_fmt => $date_formats->{$date_handling}->{'time_in'});

		# update {&today} and {&now}
		$funcs->{$rdbms}->{'today'} = sub { time2str($date_formats->{$date_handling}->{'date_in'}, time()) };
		$funcs->{$rdbms}->{'now'} = sub { time2str($date_formats->{$date_handling}->{'time_in'}, time()) };

		# reset constants for BEGINNING_OF_TIME and END_OF_TIME
		$this->{'vars'}->{'BEGINNING_OF_TIME'} = $date_formats->{$date_handling}->{'beginning_of_time'};
		$this->{'vars'}->{'END_OF_TIME'} = $date_formats->{$date_handling}->{'end_of_time'};
	}

	# backwards compatibility: {&curdate} == {&today}
	$funcs->{$rdbms}->{'curdate'} = $funcs->{$rdbms}->{'today'};
}


# just a handy place to do all these things, since all need to be done in both create() and open()
sub _setup_internals
{
	my $this = shift;

	# eval schema translation code if it's there
	_make_schema_trans($this);

	# set up variable space; fill it with constants if any
	_initialize_vars($this);

	# set date handling correctly
	# (this *must* be after _initialize_vars())
	_set_date_handling($this);

	# set blank query cache
	$this->{'_query_cache'} = {};										# this is only used by _transform_query

	# read in data dictionary (if exists)
	my $data_store_name = $this->{'config'}->{'name'};
	my $dd_filename = "$data_store_dir/$data_store_name.ddict";
	eval { $this->{'datadict'} = retrieve($dd_filename); };				# no big deal if this fails
}


# used only by _transform_query (below) while checking for ??? (non-scalar placeholders)
sub _check_for_variable
{
	my ($this, $which, $value, $temp_vars) = @_;

	my $is_sub = defined $value && $value =~ /$QUERY_SUB/;
	my $varname = $is_sub && $value =~ /$QUERY_VAR/ ? $1 : undef;
	debuggit(4 => $which, "found that", $value, $is_sub ? "is" : "is not", "a substitution and",
			$varname ? "is" : "is not", "a variable");
	if ($which eq 'PLACEHOLDER')
	{
		# if it's a substitution (but not a variable!), just return it back; otherwise return a ? placeholder
		return ($is_sub && not $varname) ? $value : '?';
	}
	elsif ($which eq 'BIND_VAL')
	{
		# if it's a substitution (except for variables), then there will be no bind val, so return an empty list
		# else return the value, which if it's a var means actually _getting_ the value
		# (note that since vars actually are subs themselves, the order of the code was rearranged for better
		# efficiency; that's why it doesn't match the comment above)
		return $varname ? $this->_get_var_value($varname, $temp_vars) : $is_sub ? () : $value;
	}
	else
	{
		die("don't know what to return when checking for variable ($which)");
	}
}


# grab the value for a variable (i.e. {somevar} construction)
sub _get_var_value
{
	my ($this, $varname, $temp_vars) = @_;
	debuggit(4 => "trying to get value for variable", $varname, "vars are", Dumper($temp_vars));

	if (exists $temp_vars->{$varname})
	{
		# temp_vars override previously defined vars
		return $temp_vars->{$varname};
	}
	elsif (exists $this->{'vars'}->{$varname})
	{
		return $this->{'vars'}->{$varname};
	}
	else
	{
		croak("variable/constant unknown: $varname");
	}
}


# check a type for possible translations: user defined types, and base types
# returns the RDBMS native type (which may be the same as the input type)
sub _translate_type
{
	my ($this, $type) = @_;

	# translate user-defined types
	if (exists $this->{'config'}->{'user_types'})
	{
		$type = $this->{'config'}->{'user_types'}->{$type} if exists $this->{'config'}->{'user_types'}->{$type};
	}

	# translate base types
	my $trans_table = $base_types->{ $this->{'config'}->{'rdbms'} };
	$type = $trans_table->{$type} if exists $trans_table->{$type};

	return $type;
}


# translate column attributes (during create table)
sub _translate_attrs
{
	my ($this, @attributes) = @_;

	my $attr_table = $column_attributes->{ $this->{'config'}->{'rdbms'} };
	die("no column attribute table supplied for RDBMS $this->{'config'}->{'rdbms'}") unless $attr_table;

	my @xlated_attrs;
	foreach my $attr (@attributes)
	{
		$attr = lc($attr);
		my $attr_key = $attr;

		my ($rule, $args);
		if (exists $attr_table->{$attr})
		{
			$rule = $attr_table->{$attr};
		}
		else
		{
			($attr_key, $args) = split(' ', $attr);
			if (exists $attr_table->{$attr_key})
			{
				$rule = $attr_table->{$attr_key};
			}
		}
		die("lacking implementation for $this->{'config'}->{'rdbms'} attribute $attr") unless $rule;

		if ($rule->{'unique'})
		{
			croak("can't have multiple $attr columns") if $this->{'col_attrs_seen'}->{$attr_key};
			$this->{'col_attrs_seen'}->{$attr_key} = 1;
		}

		if ($rule->{'translate'})
		{
			$attr = $rule->{'translate'};
			$attr =~ s/{}/$args/ if $args;
		}

		@xlated_attrs[$rule->{'order'}] = $attr;

		# cheat by using redo to handle implied attributes
		# this is safer than trying to tack them onto the end of the array from within the loop
		if ($rule->{'implies'})
		{
			$attr = $rule->{'implies'};
			redo;
		}
	}

	return join(' ', grep { defined } @xlated_attrs);
}


# handle all substitutions on queries
sub _transform_query
{
	my $this = shift;
	my $query = shift;

	# this is an algorithm cribbed from Filter::Simple (by the excellent Damian Conway) to replace all
	# quoted strings with string placeholders (not to be confused with SQL placeholders) so they're out of the
	# way while we search for ?'s (i.e. SQL placeholders).  after we're done searching, we'll put the quoted
	# strings back.  in this way, we avoid thinking that a ? in quotes is actually a SQL placeholder without
	# having to lex & parse the whole damn SQL string
	my @quoted_strings;
	$query = join('', map { ref $_ ? scalar((push @quoted_strings, $_), "{Q$#quoted_strings}") : $_ }
		extract_multiple($query,
		[
			{ SQ => sub { extract_delimited($_[0], q{'}, '', q{'}) } },
			{ DQ => sub { extract_delimited($_[0], q{"}, '', q{"}) } },
			qr/[^'"]+/,
		])
	);
	debuggit(4 => "after replacing quoted strings, query looks like:", $query);

	# figure out how many standard placeholder (a.k.a. "scalar placeholder") values we should have and chop
	# them off tne end of our parameter list first
	# note that we replace the ?'s with an easier to identify string; this avoids having the
	# ?-in-quoted-strings problem again
	my $sc_placeholder_count = $query =~ s/$SCALAR_PH/{??}/g;
	my @sc_placeholders = splice @_, -$sc_placeholder_count if $sc_placeholder_count;
	debuggit(4 => "built placeholder vars with", scalar(@sc_placeholders), "elements");

	# now put the quoted strings back (note that it's okay to have a _variable_ inside a quoted string, so we
	# don't do anything in particular to avoid those)
	$query =~ s/{Q(\d+)}/${$quoted_strings[$1]}/g;
	
	# sort out parameters according to whether they're the query (first param), hash or array placeholder
	# (a.k.a. "non-scalar placeholder") values (any hashrefs or arrayrefs), or variables (everything else)
	my (@ns_placeholders, @var_stuff);
	foreach (@_)
	{
		if (ref $_)
		{
			push @ns_placeholders, $_;
		}
		else
		{
			push @var_stuff, $_;
		}
	}
	my $temp_vars = { @var_stuff };
	debuggit(4 => "built temp_vars with", @var_stuff / 2, "elements");
	debuggit(4 => "built ns_placeholders with", scalar(@ns_placeholders), "elements");

	my @vars = ();
	my $calc_funcs = {};

	debuggit(5 => "at top of transform:", $this->ping() ? "connected" : "NOT CONNECTED!");

	# it's a bad idea to allow queries while the data store is modified.
	# the biggest reason is that the result set returned by do() contains a reference to the data store, so if
	# the result sets remain in scope for some reason, the destructor won't save the data store (in fact, it
	# won't even get called, because there's still an outstanding reference--or more--to the object).  this
	# could produce weird results, including trying to save the same data store twice (or more) in a row with
	# different modifications.  for that reason, we just disallow it altogether.  and since this function gets
	# called by every main subroutine that calls queries, this is a good common place to check.
	if ($this->{'modified'})
	{
		croak("can't execute query with config's pending; run commit_configs()");
	}

	debuggit(5 => 'DataStore::_transform_query: before SQL preproc $this', Dumper($this));
	debuggit(5 => "about to check for vars in", $query);
	# variables and constants
	while ($query =~ / $QUERY_VAR | (\Q{??}\E) | (values) \s+ $HASH_PH | (set) \s+ $HASH_PH /iox)
	{
		if ($1)															# {somevar} (just a variable)
		{
			my $variable = $&;
			my $varname = $1;

			my $value = $this->_get_var_value($varname, $temp_vars);

			# for variable substitution, we use placeholders and return the var values
			# the funky substring is pretty much straight out of the perlvar manpage
			# it avoids the use of $& (which causes severe performance penalties), _and_ it's faster for this
			# operation anyways, because using $& would involve a s//, which is going to be slower than using
			# substr() as an lvalue
			substr($query, $-[0], $+[0] - $-[0]) = '?';
			push @vars, $value;
		}
		elsif ($2)														# ? (standard placeholder)
		{
			# have to put the placeholder back the way it was
			# note that if we hadn't changed the ?'s to something else, we not only would have possibly
			# counted ?'s in quoted strings, we'd have also generated an infinite loop here
			# (funky substring same as above)
			substr($query, $-[0], $+[0] - $-[0]) = '?';
			push @vars, shift @sc_placeholders;
		}
		elsif ($3)														# values ???
		{
			# since we can have multiple values here, and nowhere else, and since no other non-scalar
			# placeholders can be used in conjunction with this one, just assume that the whole
			# @ns_placeholders array is ours

			# they're all the same, so just grab the first one
			# (at least they damn well _better_ be all the same ...)
			my $hash = $ns_placeholders[0];

			my $values = join(',', map { $this->_check_for_variable(PLACEHOLDER => $hash->{$_}, $temp_vars) }
					sort keys %$hash);
			substr($query, $-[0], $+[0] - $-[0]) = '(' . join(', ', sort keys %$hash) . ') values (' .  $values . ')';
			debuggit(3 => 'values :', $values);

			foreach $hash (@ns_placeholders)
			{
				push @vars, [ map { $this->_check_for_variable(BIND_VAL => $hash->{$_}, $temp_vars) } sort keys %$hash ];
			}
			debuggit(4 => "theoretically added", scalar(@ns_placeholders), "arrayrefs to var list");

			# this is probably unnecessary, but just to be neat
			undef @ns_placeholders;
		}
		elsif ($4)														# set ???
		{
			my $hash = shift @ns_placeholders;

			substr($query, $-[0], $+[0] - $-[0]) = 'set ' .
					join(', ', map { "$_ = " . $this->_check_for_variable(PLACEHOLDER => $hash->{$_}, $temp_vars) }
							sort keys %$hash);

			push @vars, map { $this->_check_for_variable(BIND_VAL => $hash->{$_}, $temp_vars) } sort keys %$hash;
		}
	}

	debuggit(5 => "about to check for functions in", $query);
	# function calls
	while ($query =~ / {\& (\w+) (?: \s+ (.*?) )? } /x)
	{
		my $function = quotemeta($&);
		my $func_name = $1;
		my @args = ();
		@args = split(/,\s*/, $2) if $2;

		debuggit(4 => "translating function", $func_name);
		my $func_table = $funcs->{$this->{'config'}->{'rdbms'}};
		croak("unknown translation function: $func_name") unless exists $func_table->{$func_name};

		my $func_output = $func_table->{$func_name}->(@args);
		$query =~ s/$function/$func_output/g;
	}

	my $sth;		# statement handle for us to return at the end of it all

	# check to see if we have this query cached
	# note: the "raw" query isn't quite raw: it's the query after variable
	# substitutions (only).  variables could change, but it's assumed that
	# aliases, schema names, etc, will NOT change.  you're going to get
	# funky results if you try to change them in the middle of querying.
	my $raw_query = $query;
	# do *not* return a cached statement handle that is still active!
	# this could screw up pathological cases
	if (exists $this->{'_query_cache'}->{$raw_query} and not $this->{'_query_cache'}->{$raw_query}->{'Active'})
	{
		$sth = $this->{'_query_cache'}->{$raw_query};
		$this->_show_query($query, true, @vars) if $this->{'show_queries'};
	}
	else																# do it the hard way
	{
		debuggit(3 => "about to check for curly braces in query", $query);
		# this outer if protects queries with no substitutions from paying
		# the cost for searching for the various types of sub's
		if ($query =~ /{/)	# if you want % to work in vi, you need a } here
		{

			# alias translations
			while ($query =~ / {\@ (\w+) } /x)
			{
				my $alias = $&;
				my $alias_name = $1;
				my $table_name = $this->{'config'}->{'aliases'}->{$alias_name};
				croak("unknown alias: $alias_name") unless $table_name;
				$query =~ s/$alias/$table_name/g;
			}

			# schema translations
			while ($query =~ / {~ (\w+) } \. /x)
			{
				my $schema = $&;
				my $schema_name = $1;
				die("cannot translate schema $schema with no translation code") unless exists $this->{'schema_translation'};
				my $translation = $this->{'schema_translation'}->($schema_name);
				debuggit(4 => "schema:", $schema, "/ s name:", $schema_name, "/ translation:", $translation);
				$query =~ s/$schema/$translation/g;
			}

			debuggit(5 => "about to check for calc cols in", $query);
			# calculated columns
			while ($query =~ / { \* (.*?) \s* = \s* (.*?) } /sx)
			{
				my $field_spec = quotemeta($&);
				my $calc_col = $1;
				my $calculation = $2;
				debuggit(4 => "found a calc column:", $calc_col, "=", $calculation);
				debuggit(5 => "going to replace <<", $field_spec, ">> with <<1 as \"*$calc_col\">> in query <<",
						$query, ">>");

				while ($calculation =~ /%(\w+)/)
				{
					my $col_ref = $1;
					my $spec = quotemeta($&);

					debuggit(4 => "found col ref in calc:", $col_ref);
					debuggit(5 => "going to sub", $spec, "with", qq/\$_[0]->col($col_ref)/);
					$calculation =~ s/$spec/\$_[0]->col("$col_ref")/g;
				}

				while ($calculation =~ /\$([a-zA-Z]\w+)/)
				{
					my $varname = $1;
					my $spec = quotemeta($&);

					$calculation =~ s/$spec/\${\$_[0]}->{'vars'}->{$varname}/g;
				}

				debuggit(2 => "going to evaluate calc func:", "sub { $calculation }");
				my $calc_function = eval "sub { $calculation }";
				croak("illegal syntax in calculated column: $field_spec ($@)") if $@;
				$calc_funcs->{$calc_col} = $calc_function;

				$query =~ s/$field_spec/1 as "*$calc_col"/g;
				debuggit(5 => "after calc col subst, query is <<", $query, ">>");
			}
		}

		debuggit(4 => "after transform:", $query);
		$this->_show_query($query, false, @vars) if $this->{'show_queries'};

		debuggit(5 => "before preparing query:", $this->ping() ? "connected" : "NOT CONNECTED!");

		local $SIG{__WARN__} = sub { die $_[0] };
		eval { $sth = $this->{'dbh'}->prepare($query) };
		unless ($sth)
		{
			$this->{'last_err'} = $this->{'dbh'}->errstr();
			debuggit(5 => "prepare bombed:", $this->{'last_err'});
			return wantarray ? () : undef;
		}
		debuggit(5 => "successfully prepared query");

		# cache the sth for next time
		$this->{'_query_cache'}->{$raw_query} = $sth;
	}

	debuggit(5 => "at bottom of transform:", $this->ping() ? "connected" : "NOT CONNECTED!");

	if (wantarray)
	{
		return ($sth, $calc_funcs, @vars);
	}
	else
	{
		carp("calculated columns are being lost") if %$calc_funcs;
		return $sth;
	}
}


sub _show_query
{
	my ($this, $query, $cached, @vars) = @_;
	debuggit(5 => "DataStore::_show_query: entering with bind vals", Dumper(\@vars));

	print "DataStore current query:\n";
	print "   cached version of\n" if $cached;
	print "$query\n";

	print "   bind vals: ", join(' || ', map { defined $_ ? $_ : 'NULL' } @vars), "\n" if @vars;
}


# interface methods


sub get_password
{
	my ($find_server, $find_user) = @_;
	my $pwfile = "$ENV{'HOME'}/" . PASSWORD_FILE;
	debuggit(4 => "password file is", $pwfile);

	croak("must have a $pwfile file in your home directory") unless -e $pwfile;
	my $pwf_mode = (stat _)[2];											# i.e., the permissions
	croak("$pwfile must be readable and writable only by you") if $pwf_mode & 077;

	open(PW, $pwfile) or croak("can't read file $pwfile");
	while ( <PW> )
	{
		chomp;

		my ($server, $user, $pass) = split(/:/);
		if ($server eq $find_server and $user eq $find_user)
		{
			close(PW);
			debuggit(4 => "get_password: returning password", $pass);
			return $pass;
		}
	}
	close(PW);

	debuggit(4 => "get_password: couldn't find password");
	return undef;
}


sub open
{
	my $class = shift;
	my ($data_store_name, $user_name) = @_;

	my $ds_filename = "$data_store_dir/$data_store_name.dstore";
	debuggit(3 => "file name is", $ds_filename);
	croak("data store $data_store_name not found") unless -e $ds_filename;

	my $this = {};
	$this->{'name'} = $data_store_name;
	eval { $this->{'config'} = retrieve($ds_filename); };
	croak("read error opening data store") unless $this->{'config'};

	# supply user name for this session
	croak("must specify user to data store") unless $user_name;
	$this->{'user'} = $user_name;

	# get our guts set up properly
	_setup_internals($this);

	# mark unmodified
	$this->{'modified'} = false;
	$this->{'show_queries'} = false;

	debuggit(5 => 'DataStore::open: $this', Dumper($this));

	bless $this, $class;
	$this->_login();
	debuggit(4 => "this is a", ref $this, "for ds", $data_store_name);
	return $this;
}


sub create
{
	my $class = shift;
	my ($data_store_name, %attribs) = @_;

	# error check potential attributes
	foreach my $key (keys %attribs)
	{
		croak("can't create data store with unknown attribute $key") unless grep { /$key/ } CONFIG_ATTRIBS;
	}

	my $this = {};
	$this->{'name'} = $data_store_name;

	# RDBMS has to be present
	croak("must specify RDBMS to data store") unless exists $attribs{'rdbms'};
	
	# user has to be present, and should be moved out of config section
	croak("must specify user to data store") unless exists $attribs{'user'};
	$this->{'user'} = $attribs{'user'};
	delete $attribs{'user'};

	$this->{'config'} = \%attribs;
	$this->{'config'}->{'name'} = $data_store_name;
	$this->{'modified'} = true;
	$this->{'show_queries'} = false;
	debuggit(5 => 'DataStore::create: $this', Dumper($this));

	# get our guts set up properly
	_set_date_types($this);
	_setup_internals($this);

	bless $this, $class;
	$this->_login();

	return $this;
}


sub DESTROY
{
	my $this = shift;
	debuggit(5 => 'DataStore::DESTROY: $this', Dumper($this));

	$this->commit_configs();
}


sub commit_configs
{
	my $this = shift;

	if ($this->{'modified'})
	{
		$this->{'modified'} = false;

		my $data_store_name = $this->{'config'}->{'name'};
		my $ds_filename = "$data_store_dir/$data_store_name.dstore";
		debuggit(3 => "DataStore::commit_configs: saving to file", $ds_filename);

		croak("can't save data store specification") unless store($this->{'config'}, $ds_filename);
	}
}


sub ping
{
	my $this = shift;
	debuggit(5 => "DataStore: in ping()");
	return $this->{'dbh'}->ping();
}


sub last_error
{
	my $this = shift;

	return $this->{'last_err'};
}


sub show_queries
{
	my $this = shift;
	my $state = defined $_[0] ? $_[0] : true;

	$this->{'show_queries'} = $state;
}


sub do
{
	# query etc not needed here; just pass thru to _transform_query below
	my ($this) = @_;

	# handle substitutions
	# (note & form of sub call, which just passes our args through w/o copying)
	my ($sth, $calc_funcs, @vars) = &_transform_query or return undef;

	my $rows = 0;
	if (ref $vars[0] eq 'ARRAY')										# then we must be doing multiple INSERT statements
	{
		foreach (@vars)
		{
			my $sub_rows = $sth->execute(@$_);
			if (defined $sub_rows)
			{
				$rows += $sub_rows;
			}
			else
			{
				$rows = undef;
				last;
			}
		}
	}
	else
	{
		$rows = $sth->execute(@vars);
	}

	unless (defined $rows)
	{
		$this->{'last_err'} = $sth->errstr();
		return undef;
	}
	debuggit(5 => "successfully executed query");

	my $results = {};
	$results->{'ds'} = $this;
	$results->{'rows'} = $rows;
	$results->{'sth'} = $sth;
	$results->{'calc_funcs'} = $calc_funcs;
	bless $results, 'DataStore::ResultSet';

	return $results;
}


sub execute
{
	my $this = shift;
	my ($sql_text, %params) = @_;
	my $delim = exists $params{'delim'} ? $params{'delim'} : ";";

	my $report = "";
	foreach my $query (split(/\s*$delim\s*\n/, $sql_text))
	{
		next if $query =~ /^\s*$/;										# ignore blank queries

		my $res = $this->do($query);
		return undef unless defined $res;
		if (exists $params{'report'})
		{
			my $rows = $res->rows_affected();
			if ($res->{'sth'}->{'NUM_OF_FIELDS'})
			{
				$rows = 0;
				++$rows while $res->next_row();
			}
			if ($rows >= 0)
			{
				$report .= $params{'report'};
				$report =~ s/%R/$rows/g;
			}
		}
	}

	return $report ? $report : true;
}


sub begin_tran
{
	my $this = shift;

	unless ($this->{'dbh'}->begin_work())
	{
		$this->{'last_err'} = $this->{'dbh'}->errstr;
		croak("cannot start transaction");
	}

	return true;
}


sub commit
{
	my $this = shift;

	unless ($this->{'dbh'}->commit())
	{
		$this->{'last_err'} = $this->{'dbh'}->errstr;
		croak("cannot commit transaction");
	}
}


sub rollback
{
	my $this = shift;

	unless ($this->{'dbh'}->rollback())
	{
		$this->{'last_err'} = $this->{'dbh'}->errstr;
		croak("cannot rollback transaction");
	}

	return true;
}


# the primary difference between load_data and other methods such as do()
# is that load_data returns a DataSet, whereas do() et al return a ResultSet
# with a DataSet, all the data is in memory at once (not so with a ResultSet)
# NOTE: load_table is an alias for load_data
sub load_data
{
	# just pass all parameters straight through to do
	my $res = &do;
	return undef unless $res;

	return DataStore::DataSet->new($res->{'sth'});
}


# for append_table, you need to send it a DataSet
# your best bet is to only use a structure returned from load_data()
sub append_table
{
	my $this = shift;
	my ($table, $data, $empty_set_okay) = @_;
	if ($empty_set_okay and $empty_set_okay != EMPTY_SET_OKAY)
	{
		$this->{'last_err'} = "illegal option sent to append_table";
		return undef;
	}

	# make sure we have at least one row, unless empty sets are okay
	unless (@$data)
	{
		if ($empty_set_okay)
		{
			# looks like they don't care that there's no data; just return
			return true;
		}
		else
		{
			$this->{'last_err'} = "no rows passed to append_table";
			return undef;
		}
	}

	# use ??? feature to insert all rows
	return $this->do(qq{ insert into $table values ??? }, @$data);
}


# replace_table just deletes all rows from the table, then calls append_table for you.  THIS CAN BE VERY
# DESTRUCTIVE! (obviously).  please use with caution.
sub replace_table
{
	my $this = shift;
	my ($table, $data, $empty_set_okay) = @_;

	return undef unless $this->do("delete from $table");

	return $this->append_table($table, $data, $empty_set_okay);
}


sub create_table
{
	my ($this, $table_name, $columns, $opts) = @_;
	$opts ||= {};
	$opts->{'DATADICT'} ||= '';

	my $schema = $opts->{'SCHEMA'} || '';
	my $colinfo = {};

	my $colnum = 0;
	my $column_list = "(";
	$this->{'col_attrs_seen'} = {};										# this is used by _translate_attrs to catch dups
	foreach my $col (@$columns)
	{
		my ($name, $type, @attributes) = @$col;
		my $info = { name => $name, type => $type, attributes => [ @attributes ], order => ++$colnum };

		$type = $this->_translate_type($type);
		$info->{'native_type'} = $type;

		# translate attributes
		my $attributes = $this->_translate_attrs(@attributes);

		$column_list .= ", " if length($column_list) > 1;
		$column_list .= "$name $type $attributes";
		$colinfo->{$name} = $info;
	}
	$column_list .= ")";
	debuggit(3 => "final column list is", $column_list);

	my $table = $schema ? "{~$schema}.$table_name" : $table_name;
	if ($opts->{'OVERWRITE'})
	{
		if ($this->do("select 1 from $table where 1 = 0"))
		{
			$this->do("drop table $table") or return false;
		}
	}

	$this->do("create table $table $column_list") or return false;
	unless ($opts->{'DATADICT'} eq 'DONTSAVE')
	{
		$this->{'datadict'}->{$schema}->{$table_name} = $colinfo;
		debuggit(4 => 'DataStore::create_table: datadict', Dumper($this->{'datadict'}));

		my $data_store_name = $this->{'config'}->{'name'};
		my $dd_filename = "$data_store_dir/$data_store_name.ddict";
		carp("can't save data dictionary") unless store($this->{'datadict'}, $dd_filename);
	}

	return true;
}


sub column_type
{
	my $opts = ref $_[$#_] eq 'HASH' ? pop : {};
	my ($this, $table, $column) = @_;
	my $schema = $opts->{'SCHEMA'} || '';

	my $colinfo = $this->{'datadict'}->{$schema}->{$table};
	debuggit(3 => 'DataStore::column_type: colinfo', Dumper($colinfo));

	if ($colinfo)
	{
		if ($column)
		{
			my $col = $colinfo->{$column};
			return wantarray ? %$col : $col->{'type'} if $col;
		}
		else
		{
			$colinfo = [ sort { $a->{'order'} <=> $b->{'order'} } values %$colinfo ];
			return wantarray ? @$colinfo : $colinfo;
		}
	}

	return wantarray ? () : undef;
}


sub overwrite_table
{
	my $this = shift;
	my ($table_name, $columns) = @_;

	return false unless $table_name and $columns and @$columns;
	return $this->create_table($table_name, $columns, { OVERWRITE => 1, DATADICT => 'DONTSAVE' });
}


sub configure_type
{
	my $this = shift;
	my ($user_type, $base_type) = @_;

	$this->{'config'}->{'user_types'}->{$user_type} = $base_type;
	$this->{'modified'} = true;
}


sub configure_alias
{
	my $this = shift;
	my ($alias, $table_name) = @_;

	$this->{'config'}->{'aliases'}->{$alias} = $table_name;
	$this->{'modified'} = true;
}


sub configure_schema_translation
{
	my $this = shift;
	my ($trans_code) = @_;

	$this->{'config'}->{'schema_translation_code'} = $trans_code;
	$this->_make_schema_trans();
	$this->{'modified'} = true;
}


sub define_var
{
	my $this = shift;
	my ($varname, $value) = @_;

	$this->{'vars'}->{$varname} = $value;
}



###########################################################################
# The DataStore::ResultSet "subclass"
###########################################################################

package DataStore::ResultSet;

use strict;
use warnings;

use Carp;

use Barefoot;
use Barefoot::DataStore::DataRow;


sub _get_colnum
{
	return $_[0]->{'currow'}->_get_colnum($_[1]);
}


sub _get_colval
{
	return $_[0]->{'currow'}->[$_[1]];
}


sub next_row
{
	my $this = shift;

	my $row = $this->{'sth'}->fetchrow_arrayref();
	unless ($row)
	{
		# just ran out of rows?
		return 0 if not $this->{'sth'}->err();

		# no, i guess it's an error
		$this->{'ds'}->{'last_err'} = $this->{'sth'}->errstr();
		return undef;
	}
	$this->{'currow'} = DataStore::DataRow->new(
			$this->{'sth'}->{'NAME'}, $this->{'sth'}->{'NAME_hash'}, $row,
			$this->{'calc_funcs'}, $this->{'ds'}->{'vars'}
	);

	return $this->{'currow'};
}


sub rows_affected
{
	return $_[0]->{'rows'};
}


sub num_cols
{
	return $_[0]->{'sth'}->{'NUM_OF_FIELDS'};
}


sub colnames
{
	return @{ $_[0]->{'sth'}->{'NAME'} };
}


sub col
{
	return $_[0]->{'currow'}->col($_[1]);
}


sub colname
{
	my ($this, $colnum) = @_;

	return $this->{'sth'}->{'NAME'}->[$colnum];
}


sub all_cols
{
	return @{ $_[0]->{'currow'} };
}


sub count
{
	my $this = shift;
	$this->next_row() or return undef;
	return $this->{'currow'}->col(0);
}


###########################
# Return a true value:
###########################

1;
