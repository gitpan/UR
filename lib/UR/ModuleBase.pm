# A base class supplying error, warning, status, and debug facilities.

package UR::ModuleBase;

BEGIN {
    use Class::Autouse;
    # the file above now does this, but just in case:
    # subsequent uses of this module w/o the special override should just do nothing...
    $INC{"Class/Autouse_1_99_02.pm"} = 1;
    $INC{"Class/Autouse_1_99_04.pm"} = 1;
    no strict;
    no warnings;
    
    # ensure that modules which inherit from this never fall into the
    # replaced UNIVERSAL::can/isa
    *can = $Class::Autouse::ORIGINAL_CAN;
    *isa = $Class::Autouse::ORIGINAL_ISA;
}

=pod

=head1 NAME

UR::ModuleBase - Methods common to all UR classes and object instances.

=head1 DESCRIPTION

This is a base class for packages, classes, and objects which need to
manage basic functionality in the UR framework such as inheritance, 
AUTOLOAD/AUTOSUB methods, error/status/warning/etc messages.

UR::ModuleBase is in the @ISA list for UR::Object, but UR::ModuleBase is not
a formal UR class.

=head1 METHODS

=over 4

=cut

# set up package
require 5.006_000;
use warnings;
use strict;
our $VERSION = "0.38"; # UR $VERSION;;

# set up module
use Carp;
use IO::Handle;
use UR::Util;

=pod

=item C<class>

  $class = $obj->class;

This returns the class name of a class or an object as a string.
It is exactly equivalent to:

    (ref($self) ? ref($self) : $self)

=cut

sub class
{
    my $class = shift;
    $class = ref($class) if ref($class);
    return $class;
}

=pod

=item C<super_class>

  $obj->super_class->super_class_method1();
  $obj->super_class->super_class_method2();

This returns the super-class name of a class or an object.
It is exactly equivalent to:
    $self->class . "::SUPER"

Note that MyClass::SUPER is specially defined to include all
of the items in the classes in @MyClass::ISA, so in a multiple
inheritance scenario:

  $obj->super_class->super_class_method1();
  $obj->super_class->super_class_method2();

...could have super_class_method1() in one parent class
and super_class_method2() in another parent class.

=cut

sub super_class { shift->class . "::SUPER" }

=pod 

=item C<super_can>

  $sub_ref = $obj->super_can('func');

This method determines if any of the super classes of the C<$obj>
object can perform the method C<func>.  If any one of them can,
reference to the subroutine that would be called (determined using a
depth-first search of the C<@ISA> array) is returned.  If none of the
super classes provide a method named C<func>, C<undef> is returned.

=cut

sub super_can
{
    my $super_class = shift->super_class;
    
    # Handle the case in which the super_class has overridden
    # UNIVERSAL::can()
    my $super_can = $super_class->can("can");
    
    # Call the correct can() on the super_class with the normal params.
    return $super_can->($super_class,@_);
    
    #no strict;
    #foreach my $parent_class (@{$class . '::ISA'})
    #{
    #    my $code = $parent_class->can(@_);
    #    return $code if $code;
    #}
    #return;
}

=pod

=item C<inheritance>

  @classes = $obj->inheritance;

This method returns a depth-first list of all the classes (packages)
that the class that C<$obj> was blessed into inherits from.  This
order is the same order as is searched when searching for inherited
methods to execute.  If the class has no super classes, an empty list
is returned.  The C<UNIVERSAL> class is not returned unless explicitly
put into the C<@ISA> array by the class or one of its super classes.

=cut

sub inheritance {
    my $self = $_[0];    
    my $class = ref($self) || $self;
    return unless $class;
    no strict;
    my @parent_classes = @{$class . '::ISA'};

    my @ordered_inheritance;
    foreach my $parent_class (@parent_classes) {
        push @ordered_inheritance, $parent_class, ($parent_class eq 'UR' ? () : inheritance($parent_class) );
    }

    return @ordered_inheritance;
}

=pod

=item C<parent_classes>

  MyClass->parent_classes;

This returns the immediate parent class, or parent classes in the case
of multiple inheritance.  In no case does it follow the inheritance
hierarchy as ->inheritance() does.

=cut

sub parent_classes
{
    my $self = $_[0];
    my $class = ref($self) || $self;
    no strict;
    no warnings;
    my @parent_classes = @{$class . '::ISA'};
    return (wantarray ? @parent_classes : $parent_classes[0]);
}

=pod

=item C<base_dir>

  MyModule->base_dir;

This returns the base directory for a given module, in which the modules's 
supplemental data will be stored, such as config files and glade files,
data caches, etc.

It uses %INC.

=cut

sub base_dir
{
    my $self = shift;
    my $class = ref($self) || $self;    
    $class =~ s/\:\:/\//g;
    my $dir = $INC{$class . '.pm'} || $INC{$class . '.pl'};
    die "Failed to find module $class in \%INC: " . Data::Dumper(%INC) unless ($dir);
    $dir =~ s/\.p[lm]\s*$//;
    return $dir;
}

=pod

=item methods

Undocumented.

=cut

sub methods
{
    my $self = shift;
    my @methods;
    my %methods;
    my ($class, $possible_method, $possible_method_full, $r, $r1, $r2);
    no strict; 
    no warnings;

    for $class (reverse($self, $self->inheritance())) 
    { 
        print "$class\n"; 
        for $possible_method (sort grep { not /^_/ } keys %{$class . "::"}) 
        {
            $possible_method_full = $class . "::" . $possible_method;
            
            $r1 = $class->can($possible_method);
            next unless $r1; # not implemented
            
            $r2 = $class->super_can($possible_method);
            next if $r2 eq $r1; # just inherited
            
            {
                push @methods, $possible_method_full; 
                push @{ $methods{$possible_method} }, $class;
            }
        } 
    }
    print Dumper(\%methods);
    return @methods;
}

=pod

=item C<context_return>

  return MyClass->context_return(@return_values);

Attempts to return either an array or scalar based on the calling context.
Will die if called in scalar context and @return_values has more than 1
element.

=cut

sub context_return {
    my $class = shift;
    return unless defined wantarray;
    return @_ if wantarray;
    if (@_ > 1) {
        my @caller = caller(1);
        Carp::croak("Method $caller[3] on $class called in scalar context, but " . scalar(@_) . " items need to be returned");
    }
    return $_[0];
}

=pod

=back

=head1 C<AUTOLOAD>

This package impliments AUTOLOAD so that derived classes can use
AUTOSUB instead of AUTOLOAD.

When a class or object has a method called which is not found in the
final class or any derived classes, perl checks up the tree for
AUTOLOAD.  We impliment AUTOLOAD at the top of the tree, and then
check each class in the tree in order for an AUTOSUB method.  Where a
class implements AUTOSUB, it will recieve a function name as its first
parameter, and it is expected to return either a subroutine reference,
or undef.  If undef is returned then the inheritance tree search will
continue.  If a subroutine reference is returned it will be executed
immediately with the @_ passed into AUTOLOAD.  Typically, AUTOSUB will
be used to generate a subroutine reference, and will then associate
the subref with the function name to avoid repeated calls to AUTOLOAD
and AUTOSUB.

Why not use AUTOLOAD directly in place of AUTOSUB?

On an object with a complex inheritance tree, AUTOLOAD is only found
once, after which, there is no way to indicate that the given AUTOLOAD
has failed and that the inheritance tree trek should continue for
other AUTOLOADS which might impliment the given method.

Example:

    package MyClass;
    our @ISA = ('UR');
    ##- use UR;    
    
    sub AUTOSUB
    {
        my $sub_name = shift;        
        if ($sub_name eq 'foo')
        {
            *MyClass::foo = sub { print "Calling MyClass::foo()\n" };
            return \&MyClass::foo;
        }
        elsif ($sub_name eq 'bar')
        {
            *MyClass::bar = sub { print "Calling MyClass::bar()\n" };
            return \&MyClass::bar;
        }
        else
        { 
            return;
        }
    }

    package MySubClass;
    our @ISA = ('MyClass');
    
    sub AUTOSUB
    {
        my $sub_name = shift;
        if ($sub_name eq 'baz')
        {
            *MyClass::baz = sub { print "Calling MyClass::baz()\n" };
            return \&MyClass::baz;
        }
        else
        { 
            return;
        }
    }

    package main;
    
    my $obj = bless({},'MySubClass');    
    $obj->foo;
    $obj->bar;
    $obj->baz;

=cut

our $AUTOLOAD;
sub AUTOLOAD {
    
    my $self = $_[0];
    
    # The debugger can't see $AUTOLOAD.  This is just here for debugging.
    my $autoload = $AUTOLOAD; 
    
    $autoload =~ /(.*)::([^\:]+)$/;            
    my $package = $1;
    my $function = $2;

    return if $function eq 'DESTROY';

    unless ($package) {
        Carp::confess("Failed to determine package name from autoload string $autoload");
    }

    # switch these to use Class::AutoCAN / CAN?
    no strict;
    no warnings;
    my @classes = grep {$_} ($self, inheritance($self) );
    for my $class (@classes) {
        if (my $AUTOSUB = $class->can("AUTOSUB"))
            # FIXME The above causes hard-to-read error messages if $class isn't really a class or object ref
            # The 2 lines below should fix the problem, but instead make other more impoartant things not work
            #my $AUTOSUB = eval { $class->can('AUTOSUB') };
        #if ($AUTOSUB) {
        {                    
            if (my $subref = $AUTOSUB->($function,@_)) {
                goto $subref;
            }
        }
    }

    if ($autoload and $autoload !~ /::DESTROY$/) {
        my $subref = \&Carp::confess;
        @_ = ("Can't locate object method \"$function\" via package \"$package\" (perhaps you forgot to load \"$package\"?)");
        goto $subref;
    }
}


=pod

=head1 MESSAGING

UR::ModuleBase implements several methods for sending and storing error, warning and
status messages to the user.  

  # common usage

  sub foo {
      my $self = shift;
      ...
      if ($problem) {
          $self->error_message("Something went wrong...");
          return;
      }
      return 1;
  }

  unless ($obj->foo) {
      print LOG $obj->error_message();
  }

=head2 Messaging Methods

=over 4

=item message_types

  @types = UR::ModuleBase->message_types;
  UR::ModuleBase->message_types(@more_types);

With no arguments, this method returns all the types of messages that
this class handles.  With arguments, it adds a new type to the
list.

Standard message types are error, status, warning, debug and usage.

Note that the addition of new types is not fully supported/implemented
yet.

=back

=cut

our @message_types = qw(error status warning debug usage);
sub message_types
{
    my $class = shift;
    if (@_)
    {
        push(@message_types, @_);
    }
    return @message_types;
}

#
# Implement error_mesage/warning_message/status_message in a way
# which handles object-specific callbacks.
#
# Build a set of methods for getting/setting/printing error/warning/status messages
# $class->dump_error_messages(<bool>) Turn on/off printing the messages to STDERR
#     error and warnings default to on, status messages default to off
# $class->queue_error_messages(<bool>) Turn on/off queueing of messages
#     defaults to off
# $class->error_message("blah"): set an error message
# $class->error_message() return the last message
# $class->error_messages()  return all the messages that have been queued up
# $class->error_messages_arrayref()  return the reference to the underlying
#     list messages get queued to.  This is the method for truncating the list
#     or altering already queued messages
# $class->error_messages_callback(<subref>)  Specify a callback for when error
#     messages are set.  The callback runs before printing or queueing, so
#     you can alter @_ and change the message that gets printed or queued
# And then the same thing for status and warning messages

# The filehandle to print these messages to.  In normal operation this'll just be
# STDERR, but the test case can change it to capture the messages to somewhere else

our $stderr = \*STDERR;
our $stdout = \*STDOUT;

our %msgdata;

sub _get_msgdata {
    my $self = $_[0];

    if (ref($self)) {
        no strict 'refs';
        my $class_msgdata = ref($self)->_get_msgdata;
        my $object_msgdata = $class_msgdata->{'__by_id__'}->{$self->id} ||= {};

        while (my ($k,$v) = each(%$class_msgdata)) {
            # Copy class' value for this config item unless it's already set on the object
            $object_msgdata->{$k} = $v unless (exists $object_msgdata->{$k});
        }

        return $object_msgdata;

    } elsif ($self eq 'UR::Object') {
        $UR::Object::msgdata ||= {};
        return $UR::Object::msgdata;
    }
    else {
        no strict 'refs';
        my $class_msgdata = ${ $self . '::msgdata' } ||= {};

        # eval since some packages aren't forman UR classes with metadata
        my $parent_class = eval { @{$self->__meta__->is}[0]; };  # yeah, ignore multiple inheritance :(
        my $parent_msgdata;
        if ($parent_class) {
            $parent_msgdata = $parent_class->_get_msgdata();
        } else {
            $parent_msgdata = UR::Object->_get_msgdata();
        }

        while (my ($k,$v) = each(%$parent_msgdata)) {
            # Copy class' value for this config item unless it's already set on the object
            $class_msgdata->{$k} = $v unless (exists $class_msgdata->{$k});
        }
        return $class_msgdata;
    }
}

=pod

For each message type, several methods are created for sending and retrieving messages,
registering a callback to run when messages are sent, controlling whether the messages
are printed on the terminal, and whether the messages are queued up.

For example, for the "error" message type, these methods are created:

=over 4

=item error_message

    $obj->error_message("Something went wrong...");
    $msg = $obj->error_message();

When called with one argument, it sends an error message to the object.  The 
error_message_callback will be run, if one is registered, and the message will
be printed to the terminal.  When called with no arguments, the last message
sent will be returned.  If the message is C<undef> then no message is printed
or queued, and the next time error_message is run as an accessor, it will
return undef.

=item dump_error_messages

    $obj->dump_error_messages(0);
    $flag = $obj->dump_error_messages();

Get or set the flag which controls whether messages sent via C<error_message()>
is printed to the terminal.  This flag defaults to true for warning and error
messages, and false for others.

=item queue_error_messages

    $obj->queue_error_messages(0);
    $flag = $obj->queue_error_messages();

Get or set the flag which control whether messages send via C<error_message()>
are saved into a list.  If true, every message sent is saved and can be retrieved
with L<error_messages()> or L<error_messages_arrayref()>.  This flag defaults to
false for all message types.

=item error_messages_callback

    $obj->error_messages_callback($subref);
    $subref = $obj->error_messages_callback();

Get or set the callback run whenever an error_message is sent.  This callback
is run with two arguments: The object or class error_message() was called on,
and a string containing the message.  This callback is run before the message
is printed to the terminal or queued into its list.  The callback can modify
the message (by writing to $_[1]) and affect the message that is printed or
queued.  If $_[1] is set to C<undef>, then no message is printed or queued,
and the last recorded message is set to undef as when calling error_message
with undef as the argument.

=item error_messages

    @list = $obj->error_messages();

If the queue_error_messages flag is on, then this method returns the entire list
of queued messages.

=item error_messages_arrayref

    $listref = $obj->error_messages_arrayref();

If the queue_error_messages flag is on, then this method returns a reference to
the actual list where messages get queued.  This list can be manipulated to add
or remove items.

=item error_message_source

    %source_info = $obj->error_message_source

Returns a hash of information about the most recent call to error_message.
The key "error_message" contains the message.  The keys error_package,
error_file, error_line and error_subroutine contain info about the location
in the code where error_message() was called.

=item error_package

=item error_file

=item error_line

=item error_subroutine

These methods return the same data as $obj->error_message_source().

=back

=cut

for my $type (@message_types) {

    for my $method_base (qw/_messages_callback queue_ dump_ _package _file _line _subroutine/) {
        my $method = (substr($method_base,0,1) eq "_"
            ? $type . $method_base
            : $method_base . $type . "_messages"
        );
        my $method_subref = sub {
            my $self = shift;
            my $msgdata = $self->_get_msgdata;
            $msgdata->{$method} = pop if @_;
            return $msgdata->{$method};
        };
        no strict;
        no warnings;
        *$method = $method_subref;
    }

    my $logger_subname = $type . "_message";
    my $logger_subref = sub {
        my $self = shift;
        my @messages = @_;

        my $msgdata = $self->_get_msgdata();

        if (@messages > 1) {
            Carp::carp("More than one string passed to ".$type."_message; only using the first one");
        }
        if (@messages) {
            my $msg = shift @messages;
            chomp $msg if defined $msg;

            unless (defined ($msgdata->{'dump_' . $type . '_messages'})) {
                my $do_dump;
                if ($type eq "status" 
                    and
                    exists $ENV{'UR_COMMAND_DUMP_STATUS_MESSAGES'}
                    and
                    $ENV{'UR_COMMAND_DUMP_STATUS_MESSAGES'}
                ) {
                    $do_dump = 1;
                } elsif ($type eq 'debug'
                    and
                    exists $ENV{'UR_DUMP_DEBUG_MESSAGES'}
                    and
                    $ENV{'UR_DUMP_DEBUG_MESSAGES'}
                ) {
                    $do_dump = 1;
                } elsif ($type eq 'warning' or $type eq 'error') {
                    $do_dump = 1;
                } else {
                    $do_dump = 0;
                }

                $msgdata->{'dump_' . $type . '_messages'} = $do_dump;
            }

            if (my $code = $msgdata->{ $type . "_messages_callback"}) {
                $code->($self,$msg);
            } else {
                # To support the deprecated non-command messaging API
                my $deprecated_msgdata = UR::Object->_get_msgdata();
                my $code = $deprecated_msgdata->{ $type . "_messages_callback"};
                if ($code) {
                    $code->($self,$msg) if ($code);
                }
            }

            $msgdata->{ $type . "_message" } = $msg;

            # If the callback set $msg to undef with "$_[1] = undef", then they didn't want the message
            # processed further
            return unless defined($msg);

            if (my $fh = $msgdata->{ "dump_" . $type . "_messages" }) {
                if ( $type eq 'usage' ) {
                    (ref($fh) ? $fh : $stdout)->print((($type eq "status" or $type eq 'usage') ? () : (uc($type), ": ")), (defined($msg) ? $msg : ""), "\n");
                }
                else {
                    (ref($fh) ? $fh : $stderr)->print((($type eq "status" or $type eq 'usage') ? () : (uc($type), ": ")), (defined($msg) ? $msg : ""), "\n");
                }
            }
            if ($msgdata->{ "queue_" . $type . "_messages"}) {
                my $a = $msgdata->{ $type . "_messages_arrayref" } ||= [];
                push @$a, $msg;
            }

            my ($package, $file, $line, $subroutine) = caller;
            $msgdata->{ $type . "_package" } = $package;
            $msgdata->{ $type . "_file" } = $file;
            $msgdata->{ $type . "_line" } = $line;
            $msgdata->{ $type . "_subroutine" } = $subroutine;
        }

        return $msgdata->{ $type . "_message" };
    };

    my $messageinfo_subname = $type . "_message_source";
    my $messageinfo_subref = sub {
        my $self = shift;
        my $msgdata = $self->_get_msgdata;
        my %return;
        my @keys = map { $type . $_ } qw( _message _package _file _line _subroutine );
        @return{@keys} = @$msgdata{@keys};
        return %return;
    };

    my $arrayref_subname = $type . "_messages_arrayref";
    my $arrayref_subref = sub {
        my $self = shift;
        my $msgdata = $self->_get_msgdata;
        $msgdata->{$type . "_messages_arrayref"} ||= [];
        return $msgdata->{$type . "_messages_arrayref"};
    };


    my $array_subname = $type . "_messages";
    my $array_subref = sub {
        my $self = shift;

        my $msgdata = $self->_get_msgdata;
        return ref($msgdata->{$type . "_messages_arrayref"}) ?
               @{ $msgdata->{$type . "_messages_arrayref"} } :
               ();
    };

    no strict;
    no warnings;

    *$logger_subname      = $logger_subref;
    *$messageinfo_subname = $messageinfo_subref;
    *$arrayref_subname    = $arrayref_subref;
    *$array_subname       = $array_subref;
}


sub _current_call_stack
{
    my @stack = reverse split /\n/, Carp::longmess("\t");

    # Get rid of the final line from carp, showing the line number
    # above from which we called it.
    pop @stack;

    # Get rid any other function calls which are inside of this
    # package besides the first one.  This allows wrappers to
    # get_message to look at just the external call stack.
    # (i.e. AUTOSUB above, set_message/get_message which called this,
    # and AUTOLOAD in UniversalParent)
    pop(@stack) while ($stack[-1] =~ /^\s*(UR::ModuleBase|UR)::/ && $stack[-2] && $stack[-2] =~ /^\s*(UR::ModuleBase|UR)::/);

    return \@stack;
}


1;
__END__

=pod

=back

=head1 SEE ALSO

UR(3)

=cut

# $Header$
