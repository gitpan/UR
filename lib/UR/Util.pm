
package UR::Util;

use warnings;
use strict;
use Data::Dumper;

sub null_sub { }

sub used_libs {
    my @extra;
    for my $i (@INC) {
        last if ($ENV{'PERL5LIB'} and $ENV{'PERL5LIB'} =~ /^$i\:/);
        push @extra, $i;
    }
    return @extra;
}

sub used_libs_perl5lib_prefix {
    my $prefix = "";
    for my $i (used_libs()) {
        $prefix .= "$i:";    
    }
    return $prefix;
}


sub deep_copy { 
    require Data::Dumper;
    local $Data::Dumper::Purity = 1;
    my $original = $_[0];
    # FIXME - this will cause Data::Dumper to emit a warning if $original contains a coderef...
    my $src = "no strict; no warnings;\n" . Data::Dumper::Dumper($original) . "\n\$VAR1;";
    my $copy = eval($src);
    return $copy;
}

sub value_positions_map {
    my ($array) = @_;
    my %value_pos;
    my $a;
    for (my $pos = 0; $pos < @$array; $pos++) {
        my $value = $array->[$pos];
        if (exists $value_pos{$value}) {
            die "Array has duplicate values, which cannot unambiguously be given value positions!"
                . Data::Dumper::Dumper($array);
        }
        $value_pos{$value} = $pos;
    }
    return \%value_pos;
}

sub positions_of_values {
    # my @pos = positions_of_values(\@unordered_crap, \@correct_order);
    # my @fixed = @unordered_crap[@pos];
    my ($unordered_array,$ordered_array) = @_;
    my $map = value_positions_map($unordered_array);
    my @translated_positions;
    $#translated_positions = $#$ordered_array;
    for (my $pos = 0; $pos < @$ordered_array; $pos++) {
        my $value = $ordered_array->[$pos];
        my $unordered_position = $map->{$value};
        $translated_positions[$pos] = $unordered_position;
    }
    # self-test:
    #    my @now_ordered = @$unordered_array[@translated_positions];
    #    unless ("@now_ordered" eq "@$ordered_array") {
    #        Carp::confess()
    #    }
    return @translated_positions;
}

# generate a method
sub _define_method {
    my $class = shift;
    my (%opts) = @_;

    # create method name
    my $method = $opts{pkg} . '::' . $opts{property};

    # determine return value type
    my $retval;
    if (defined($opts{value}))
    {
        my $refval = ref($opts{value});
        $retval = ($refval) ? $refval : 'SCALAR';
    }
    else
    {
        $retval = 'SCALAR';
    }

    # start defining method
    my $substr = "sub $method { my \$self = shift; ";

    # set default value
    $substr .= "\$self->{$opts{property}} = ";
    my $dd = Data::Dumper->new([ $opts{value} ]);
    $dd->Terse(1); # do not print ``$VAR1 =''
    $substr .= $dd->Dump; 
    $substr .= " unless defined(\$self->{$opts{property}}); ";

    # array or scalar?
    if ($retval eq 'ARRAY') {
        if ($opts{access} eq 'rw') {
            # allow setting of array
            $substr .= "\$self->{$opts{property}} = [ \@_ ] if (\@_); ";
        }

        # add return value
        $substr .= "return \@{ \$self->{$opts{property}} }; ";
    }
    else { # scalar
        if ($opts{access} eq 'rw') {
            # allow setting of scalar
            $substr .= "\$self->{$opts{property}} = \$_[0] if (\@_); ";
        }

        # add return value
        $substr .= "return \$self->{$opts{property}}; ";
    }

    # end the subroutine definition
    $substr .= "}";

    # actually define the method
    no warnings qw(redefine);
    eval($substr);
    if ($@) {
        # fatal error since this is like a failed compilation
        die("failed to defined method $method {$substr}:$@");
    }
    return 1;
}

=over

=item generate_readwrite_methods

  UR::Util->generate_readwrite_methods
  (
      some_scalar_property = 1,
      some_array_property = []
  );

This method generates accessor/set methods named after the keys of its
hash argument.  The type of function generated depends on the default
value provided as the hash key value.  If the hash key is a scalar, a
scalar method is generated.  If the hash key is a reference to an
array, an array method is generated.

This method does not overwrite class methods that already exist.

=cut

sub generate_readwrite_methods
{
    my $class = shift;
    my %properties = @_;

    # get package of caller
    my $pkg = caller;

    # loop through properties
    foreach my $property (keys(%properties)) {
        # do not overwrite defined methods
        next if $pkg->can($property);

        # create method
        $class->_define_method
        (
            pkg => $pkg,
            property => $property,
            value => $properties{$property},
            access => 'rw'
        );
    }

    return 1;
}

=pod

=item generate_readwrite_methods_override

  UR::Util->generate_readwrite_methods_override
  (
      some_scalar_property = 1,
      some_array_property = []
  );

Same as generate_readwrite_function except that we force the functions
into the namespace even if the function is already defined

=cut

sub generate_readwrite_methods_override
{
    my $class = shift;
    my %properties = @_;

    # get package of caller
    my $pkg = caller;

    # generate the methods for each property
    foreach my $property (keys(%properties)) {
        # create method
        $class->_define_method
        (
            pkg => $pkg,
            property => $property,
            value => $properties{$property},
            access => 'rw'
        );
    }

    return 1;
}

=pod

=item generate_readonly_methods

  UR::Util->generate_readonly_methods
  (
      some_scalar_property = 1,
      some_array_property = []
  );

This method generates accessor methods named after the keys of its
hash argument.  The type of function generated depends on the default
value provided as the hash key value.  If the hash key is a scalar, a
scalar method is generated.  If the hash key is a reference to an
array, an array method is generated.

This method does not overwrite class methods that already exist.

=cut

sub generate_readonly_methods
{
    my $class = shift;
    my %properties = @_;

    # get package of caller
    my ($pkg) = caller;

    # loop through properties
    foreach my $property (keys(%properties)) {
        # do no overwrite already defined methods
        next if $pkg->can($property);

        # create method
        $class->_define_method
        (
            pkg => $pkg,
            property => $property,
            value => $properties{$property},
            access => 'ro'
        );
    }

    return 1;
}

=pod 

=item mapreduce_grep

    my @matches = UR::Util->map_reduce_grep { shift->some_test } @candidates;

Works similar to the Perl C<grep> builtin, but in a possibly-parallel fashion.
If the environment variable UR_NR_CPU is set to a number greater than one, it
will fork off child processes to perform the test on slices of the input
list, collect the results, and return the matching items as a list.

The test function is called with a single argument, an item from the list to
be tested, and should return a true of false value.

=cut

sub mapreduce_grep($&@) {
    my $class = shift;
    my $subref = shift;
$DB::single=1;

my $total_start_time = Time::HiRes::time();
    # First check fast... should we do parallel at all?
    if (!$ENV{'UR_NR_CPU'} or $ENV{'UR_NR_CPU'} < 2) {
        #return grep { $subref->($_) } @_;
        my @ret = grep { $subref->($_) } @_;
my $total_end_time = Time::HiRes::time();
print "Serial grep took ",$total_end_time - $total_start_time ," sec\n";
        return @ret;
    }

    my(@read_handles, @child_pids);
    my $cleanup = sub {
        foreach my $handle ( @read_handles ) {
            $handle->close();
        }

        kill 'TERM', @child_pids;

        foreach my $pid ( @child_pids ) {
            waitpid($pid,0);
        }
    };

    my @things_to_check = @_;
    my($children, $length,$parent_last);
    if ($ENV{'UR_NR_CPU'}) {
        $length = POSIX::ceil(scalar(@things_to_check) / $ENV{'UR_NR_CPU'});
        $children = $ENV{'UR_NR_CPU'} - 1;
    } else {
        $children = 0;
        $parent_last = $#things_to_check;
    }

    # FIXME - There needs to be some code in here to disconnect datasources
    # Oracle in particular (maybe all DBs?), stops working right unless you
    # disconnect before forking

    my $start = $length;  # First child starts checking after parent's range
    $parent_last = $length - 1;
    while ($children-- > 0) {
        my $pipe = IO::Pipe->new();
        unless ($pipe) {
            Carp::carp("pipe() failed: $!\nUnable to create pipes to communicate with child processes to verify transact+ion, falling back to serial verification");
            $cleanup->();
            $parent_last = $#things_to_check;
            last;
        }

        my $pid = fork();
        if ($pid) {
            $pipe->reader();
            push @read_handles, $pipe;
            $start += $length;

        } elsif (defined $pid) {
            $pipe->writer();
            my $last = $start + $length;
            $last = $#things_to_check if ($last > $#things_to_check);

print "PID $$ checking from $start to $last\n";
my $start_time = Time::HiRes::time();
            #my @objects = grep { $subref->($_) } @things_to_check[$start .. $last];
            my @matching;
            for (my $i = $start; $i <= $last; $i++) {
                if ($subref->($things_to_check[$i])) {
                    push @matching, $i;
                }
            }
my $end_time = Time::HiRes::time();
print "PID $$ found ".scalar(@matching). " matching objects in ",$end_time - $start_time ," sec\n";
            # FIXME - when there's a more general framework for passing objects between
            # processes, use that instead
#print "The matches are:\n"; printf("%s  %s\n", $_->class ,$_->id) foreach @objects;
            #$pipe->printf("%s\n%s\n",$_->class, $_->id) foreach @objects;
            $pipe->print("$_\n") foreach @matching;


            exit;

        } else {
            Carp::carp("fork() failed: $!\nUnable to create child processes to ver+ify transaction, falling back to seri+al verification");
            $cleanup->();
            $parent_last = $#things_to_check;
        }
    }
print "Parent pid $$ checking 0 to $parent_last\n";
my $start_time = Time::HiRes::time();
    my @matches = grep { $subref->($_) } @things_to_check[0 .. $parent_last];
my $end_time = Time::HiRes::time();
print "Parent pid $$ found ".scalar(@matches). " matching objects in ",$end_time - $start_time ," sec\n";

    foreach my $handle ( @read_handles ) {
        READ_FROM_CHILD:
        while(1) {
            my $match_idx = $handle->getline();
            last READ_FROM_CHILD unless $match_idx;
            chomp $match_idx;

            push @matches, $things_to_check[$match_idx];
            #my $match_class = $handle->getline();
            #last READ_FROM_CHILD unless $match_class;
            #chomp($match_class);

            #my $match_id = $handle->getline();
            #unless (defined $match_id) {
            #    Carp::carp("Protocol error.  Tried to get object ID for class $match_class while verifying transaction"+);
            #    last READ_FROM_CHILD;
            #}
            #chomp($match_id);

            #push @objects, $match_class->get($match_id);
        }
        $handle->close();
    }

    $cleanup->();
my $total_end_time = Time::HiRes::time();
print "Parallel grep took ",$total_end_time - $total_start_time ," sec\n";

    return @matches;
}


# Used in several places when printing out hash-like parameters
# to the user, such as in error messages
sub display_string_for_params_list {
    my $class = shift;

    my %params;
    if (ref($_[0]) =~ 'HASH') {
        %params = %{$_[0]};
    } else {
        %params = @_;
    }

    my @strings;
    foreach my $key ( keys %params ) {
        my $val = $params{$key};
        $val = defined($val) ? "'$val'" : '(undef)';
        push @strings, "$key => $val";
    }
    return join(', ', @strings);
}


1;

=pod

=head1 NAME

UR::Util - Collection of utility subroutines and methods

=head1 DESCRIPTION

This package contains subroutines and methods used by other parts of the 
infrastructure.  These subs are not likely to be useful to outside code.

=cut

