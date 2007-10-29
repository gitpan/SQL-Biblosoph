package SQL::Bibliosoph::Query; {
	use Object::InsideOut;
	use strict;
    use utf8;
	use Carp;
	use Package::Constants;
	use Data::Dumper;
	use DBI;


	our $DEBUG = 1;

	my @dbh		:Field 
				:Arg(Name=> 'dbh', Mandatory=> 1) 
				:Std(dbh);

	my @sth	 		:Fields;		# Statement handler
	my @bind_links 	:Fields;		# Links in bind parameters
	my @bind_params	:Fields;		# Count of bind parameters

    my %init_args :InitArgs = (
                st => {
                    Mandatory => 1,
                },
	);

	#------------------------------------------------------------------

	# Constuctor
	sub init :Init {
		my ($self,$args) = @_;
		print STDERR "Q#"."$$self," if $DEBUG; 

		my $st = $args->{st};


		# Process bb language
		my $numeric_fields  = $self->parse(\$st);

		$sth[$$self] = $dbh[$$self]->prepare_cached($st) 
					or croak "error preparing :  $st";

		# Set numeric bind variables
		foreach (@$numeric_fields) {
			$sth[$$self]->bind_param($_,100,DBI::SQL_INTEGER);
		}
	}

	#------------------------------------------------------------------
	sub select_many {
		my ($self, $values) = @_;
		return $self->pexecute($values)->fetchall_arrayref()
	}


	#------------------------------------------------------------------
    # with sql_calc_found_rows
	sub select_many2 {
		my ($self, $values) = @_;
		return ( 
            $self->pexecute($values)->fetchall_arrayref(),
            $dbh[$$self]->selectrow_array('SELECT FOUND_ROWS()'),
        )
	}

	#------------------------------------------------------------------
	# It's good to return [] if not found in order to allow
	# to do @{xxxx} in the caller
	sub select_row {
		my ($self,$values) = @_;
		return $self->pexecute($values)->fetchrow_arrayref() || [];
	}

	#------------------------------------------------------------------
	sub select_do {
		my ($self, $values) = @_;
		return $self->pexecute($values);
	}

	#------------------------------------------------------------------
	# Private
	#------------------------------------------------------------------
	
	# Replaces #? bind variables to ?
	# and retuns 
	sub parse {
		my ($self,$st)  = @_;
		my @nums;

		my @m = ($$st =~ m/(\#?\d*?\?)/g );
        my $numbered =0;

		my $total=0;
		foreach (@m)  {

			# Numeric field?
			/\#/ && do {
				push @nums, $total+1;
			};

			# Linked field?
			/(\d+)/ && do {
				$bind_links[$$self]->[$total]= int($1);
                $numbered++;
			};
			$total++;
		}
		$bind_params[$$self] = $total;

        croak "Bad statament use ALL numbered bind variables, or NONE, but don't mix them in $$st " 
            if $numbered && $numbered != $total;


		# Replaces nums
		$$st =~ s/\#?\d*?\?/?/g;

		return \@nums;
	}

	#------------------------------------------------------------------

	sub pexecute {
		my ($self,$values) = @_;

		# Completes the input array
		# TODO -> IF fix_param_list
		if (@$values < $bind_params[$$self]) {
			$values->[$bind_params[$$self]-1] = undef;
		}


		#say(Dumper($values));

		# Use links
		eval {
			# Has Links?
			if ( my $l = $bind_links[$$self] ) {
				#say("start:".Dumper($values), Dumper($l));

				my @v;
				foreach (@$l) {
					push @v, $values->[$_-1];
				}
				#say(Dumper(\@v));

				$sth[$$self]->execute (@v);
			}

			# No links, direct param mapping
			else {
				# TODO -> IF fix_param_list
				$sth[$$self]->execute (@$values[0..$bind_params[$$self]-1]);
			}
		};

         if ($@) {
               # $sth->err and $DBI::err will be true if error was from DBI
               carp __PACKAGE__." ERROR  $@"; # print the error
         }
		return $sth[$$self];
	}

	#------------------------------------------------------------------

    sub _destroy :Destroy {
		my $self= shift;
        $sth[$$self]->finish() if  $sth[$$self];
   	}

	#------------------------------------------------------------------
	sub say {
		print STDERR __PACKAGE__." : @_\n" if $DEBUG; 
	}


}

1;

__END__

=head1 NAME

SQL::Bibliosoph::Query

=head1 VERSION

1.0

=head1 DESCRIPTION

	Implements one prepared statement

=head1 METHODS
		
=head2 new

	Constructor: Parameters are:

=item dbh 

	a DB handler

=item st 

The SQL statement string, using BB syntax (SEE SQL::Biblosoph::CatalogFile)

=head2 destroy

Release the prepared statement.

=head1 AUTHORS

SQL::Biblosoph by Matias Alejo Garcia (matias at confronte.com) and Lucas Lain (lucas at confronte.com).

=head1 COPYRIGHT

Copyright (c) 2007 Matias Alejo Garcia. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SUPPORT / WARRANTY

The SQL::Bibliosoph is free Open Source software. IT COMES WITHOUT WARRANTY OF ANY KIND.


=head1 SEE ALSO
	
SQL::Bibliosoph::CatalogFile

At	http://nits.com.ar/bibliosoph you can find:
	* Examples
	* VIM syntax highlighting definitions for bb files
	* CTAGS examples for indexing bb files.


=head1 ACKNOWLEDGEMENTS

To Confronte.com and its associates to support the development of this module.


