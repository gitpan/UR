package UR::Object::Command::List;
use strict;
use warnings;

use IO::File;
use Data::Dumper;
require Term::ANSIColor;
use UR;
use UR::Object::Command::List::Style;
use List::Util qw(reduce);

our $VERSION = "0.391"; # UR $VERSION;

class UR::Object::Command::List {
    is => 'Command',
    has => [
        subject_class => {
            is => 'UR::Object::Type',
            id_by => 'subject_class_name',
        },
        filter => {
            is => 'Text',
            is_optional => 1,
            doc => 'Filter results based on the parameters.  See below for how to.',
            shell_args_position => 1,
        },
        show => {
            is => 'Text',
            is_optional => 1,
            doc => 'Specify which columns to show, in order.',
        },
        order_by => {
            is => 'Text',
            is_optional => 1,
            doc => 'Output rows are listed sorted by these named columns in increasing order',
        },
        style => {
            is => 'Text',
            is_optional => 1,
            default_value => 'text',
            doc => 'Style of the list: text (default), csv, pretty, html, xml',
        },
        csv_delimiter => {
           is => 'Text',
           is_optional => 1,
           default_value => ',',
           doc => 'For the csv output style, specify the field delimiter',
        },
        noheaders => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            doc => 'Do not include headers',
        },
        output => {
            is => 'IO::Handle',
            is_optional =>1,
            is_transient =>1,
            default => \*STDOUT,
            doc => 'output handle for list, defauls to STDOUT',
        },
        _fields => {
            is_many => 1,
            is_optional => 1,
            doc => 'Methods which the caller intends to use on the fetched objects.  May lead to pre-fetching the data.',
        },
    ],
    doc => 'lists objects matching specified params',
};

sub sub_command_sort_position { .2 };

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
	#$DB::single = 1;

    # validate style
    $self->error_message(
        sprintf(
            'Invalid style (%s).  Please choose from: %s',
            $self->style,
            join(', ', valid_styles()),
        )
    )
        and return unless grep { $self->style eq $_ } valid_styles();

    if (defined($self->csv_delimiter)
        and ($self->csv_delimiter ne $self->__meta__->property_meta_for_name('csv_delimiter')->default_value)
        and ($self->style ne 'csv')
    ) {
        $self->error_message('--csv-delimiter is only valid when used with --style csv');
        return;
    }

#    my $show = $self->show;
#    my @show = split(',',$show);
#    my $subject_class_name = $self->subject_class_name;
#    foreach my $item ( @show ) {
#        next unless $self->_show_item_is_property_name($item);
#        unless ($subject_class_name->can($item)) {
#            $self->error_message("Parameter $item in the 'show' list is not supported by subject class $subject_class_name");
#            return;
#        }
#    }

    unless ( ref $self->output ){
        my $ofh = IO::File->new("> ".$self->output);
        $self->error_message("Can't open file handle to output param ".$self->output) and die unless $ofh;
        $self->output($ofh);
    }

    return $self;
}

sub _resolve_boolexpr {
    my $self = shift;

    my ($bool_expr,%extra);
    eval {
        ($bool_expr, %extra) = UR::BoolExpr->resolve_for_string(
                                   $self->subject_class_name,
                                   $self->_complete_filter,
                                   $self->_hint_string,
                                   $self->order_by,
                               );
    };
    my $error = $@;

    unless ($bool_expr) {
        eval {
            ($bool_expr, %extra) = UR::BoolExpr->_old_resolve_for_string(
                                   $self->subject_class_name,
                                   $self->_complete_filter,
                                   $self->_hint_string,
                                   $self->order_by,
                           )
        };
        if ($bool_expr) {
            $self->warning_message("Failed to parse your query, but it was recognized by the deprecated filter parser.\n  Try putting quotes around the entire filter expression.\n  Use double quotes if your filter already includes single quotes, and vice-versa.\n  Values containing spaces need quotes around them as well\n  The error from the parser was:\n    $error");
        } else {
            die $error if $error;
        }
    }


    #$self->error_message( sprintf('Unrecognized field(s): %s', join(', ', keys %extra)) )
    $self->error_message( sprintf('Cannot list for class %s because some items in the filter or show were not properties of that class: %s',
                          $self->subject_class_name, join(', ', keys %extra)))
        and return if %extra;

    return $bool_expr;
}


# Used by create() and execute() to distinguish whether an item from the show list
# is likely a property of the subject class or a more complicated expression that needs
# to be eval-ed later
sub _show_item_is_property_name {
    my($self, $item) = @_;

    return $item =~ m/^[\w\.]+$/;
}

sub execute {
    my $self = shift;

    $self->_validate_subject_class
        or return;

    my $bool_expr = $self->_resolve_boolexpr();
    return unless (defined $bool_expr);

    # TODO: instead of using an iterator, get all the results back in a list and
    # have the styler use the list, since it needs all the results to space the columns
    # out properly anyway
    my $iterator;
    unless ($iterator = $self->subject_class_name->create_iterator($bool_expr)) {
        $self->error_message($self->subject_class_name->error_message);
        return;
    }

    # prevent commits due to changes here
    # this can be prevented by careful use of environment variables if you REALLY want to use this to update data
    $ENV{UR_DBI_NO_COMMIT} = 1 unless (exists $ENV{UR_DBI_NO_COMMIT});

    # Determine things to show
    if ( my $show = $self->show ) {
        my @show;
        my $expr;
        for my $item (split(/,/, $show)) {
            if ($self->_show_item_is_property_name($item) and not defined $expr) {
                push @show, $item;
            }
            else {
                if ($expr) {
                    $expr .= ',' . $item;
                }
                else {
                    $expr = '(' . $item;
                }
                my $o;
                if (eval('sub { ' . $expr . ')}')) {
                    push @show, $expr . ')';
                    #print "got: $expr<\n";
                    $expr = undef;
                }
            }
        }
        if ($expr) {
            die "Bad expression: $expr\n$@\n";
        }
        $self->show(\@show);

        #TODO validate things to show??
    }
    else {
        $self->show([ map { $_->property_name } $self->_subject_class_filterable_properties ]);
    }

    my $style_module_name = __PACKAGE__ . '::' . ucfirst $self->style;
    my $style_module = $style_module_name->new(
        iterator => $iterator,
        show => $self->show,
        csv_delimiter => $self->csv_delimiter,
        noheaders => $self->noheaders,
        output => $self->output,
    );
    $style_module->format_and_print;

    return 1;
}

sub _filter_doc {
    my $class = shift;

    my $doc = <<EOS;
Filtering:
----------
 Create filter equations by combining filterable properties with operators and
     values.
 Combine and separate these 'equations' by commas.
 Use single quotes (') to contain values with spaces: name='genome institute'
 Use percent signs (%) as wild cards in like (~).
 Use backslash or single quotes to escape characters which have special meaning
     to the shell such as < > and &

Relational Properties:
----------------------

Relational properties are properties that point to other objects. Each type of
object has its own set of filterable properties and even its own set of
relational properties. The objects's properties can be addressed using "dot
notation", e.g. employee.name where "name" is a property of the "employee"
object/property. Refer to the relational property's own lister, or if not
available to `ur show properties`, for help on its filterable properties.

Operators:
----------
 =  (exactly equal to)
 ~  (like the value)
 :  (in the list of several values, slash "/" separated)
    (or between two values, dash "-" separated)
 >  (greater than)
 >= (greater than or equal to)
 <  (less than)
 <= (less than or equal to)

Examples:
---------
EOS
    if (my $help_synopsis = $class->help_synopsis) {
        $doc .= " $help_synopsis\n";
    } else {
        $doc .= <<EOS
 list-cmd --filter name=Bob --show id,name,address --order name
 list-cmd --filter name='something with space',employees\>200,job~%manager
 list-cmd --filter cost:20000-90000
 list-cmd --filter answer:yes/maybe
 list-cmd --filter employee.name=Bob
 list-cmd --filter employee.address.city='St. Louis'

Extended Syntax:
----------------
The filter expression may also use a more free-form syntax with arbitrary
nesting of parentheses and 'and' or 'or' clauses.  This syntax accepts the
words 'in', 'like' and 'between' in place of the above ':' and '~' operators.
In addition, the in-list of values must begin with a left bracket, end with
a right bracket and the values are separated with commas.

This extended syntax expression will most likely contain spaces or other
characters having special meaning to the shell, so they will need to be
escaped with literal backslashes or enclosed in quotes of some kind.

Extended Syntax Examples:
-------------------------
 list-cmd --filter 'name=Bob or address like "%main st"'
 list-cmd --filter 'name="something with space" and (score < 10 or score > 100)'
 list-cmd --filter 'cost between 20000-90000'
 list-cmd --filter 'answer in [yes,maybe]'
EOS
    }

    # Try to get the subject class name
    my $self = $class->create;
    if ( not $self->subject_class_name
            and my $subject_class_name = $self->_resolved_params_from_get_options->{subject_class_name} ) {
        $self = $class->create(subject_class_name => $subject_class_name);
    }

    my @properties = $self->_subject_class_filterable_properties;
    my @filterable_properties   = grep { ! $_->data_type or index($_->data_type, '::') == -1 } @properties;
    my @relational_properties = grep {   $_->data_type and index($_->data_type, '::') >=  0 } @properties;

    my $longest_name = 0;
    foreach my $property ( @properties ) {
        my $name_len = length($property->property_name);
        $longest_name = $name_len if ($name_len > $longest_name);
    }

    my @data;
    if ( ! $self->subject_class_name ) {
        $doc .= " Can't determine the list of properties without a subject_class_name.\n";
    } elsif ( ! @properties ) {
        $doc .= sprintf(" %s\n", $self->error_message);
    } else {
        if (@filterable_properties) {
            push @data, 'Filterable Properties:';
            for my $property ( @filterable_properties ) {
                push @data, [$property->property_name, $self->_doc_for_property($property, $longest_name)];
            }
        }

        if (@relational_properties) {
            push @data, 'Relational Properties:';
            for my $property ( @relational_properties ) {
                push @data, [$property->property_name, $self->_doc_for_property($property, $longest_name)];
            }
        }
    }
    my @lines = $class->_format_property_doc_data(@data);
    $doc .= join("\n", @lines);

    $self->delete;
    return $doc;
}

sub _doc_for_property {
    my $self = shift;
    my $property = shift;
    my $longest_name = shift;

    my $doc;

    my $property_doc = $property->doc;
    unless ($property_doc) {
        eval {
            foreach my $ancestor_class_meta ( $property->class_meta->ancestry_class_metas ) {
                my $ancestor_property_meta = $ancestor_class_meta->property_meta_for_name($property->property_name);
                if ($ancestor_property_meta and $ancestor_property_meta->doc) {
                    $property_doc = $ancestor_property_meta->doc;
                    last;
                }
            }
        };
    }
    $property_doc ||= '(undocumented)';
    $property_doc =~ s/\n//gs;   # Get rid of embeded newlines

    my $data_type = $property->data_type || '';
    $data_type = (index($data_type, '::') == -1) ? ucfirst(lc $data_type) : $data_type;

    # include the data type in the doc so it can be reformatted
    $property_doc = sprintf('(%s): %s', $data_type, $property_doc);

    return $property_doc;
}

sub _format_property_doc_data {
    my ($class, @data) = @_;

    my @names = map { $_->[0] } grep { ref $_ } @data;
    my $longest_name = reduce { length($a) > length($b) ? $a : $b } @names;
    my $w = length($longest_name);

    my @lines;
    for my $data (@data) {
        if (ref $data) {
            push @lines, sprintf(" %${w}s  %s", $data->[0], $data->[1]);
        } else {
            push @lines, '', $data, '-' x length($data);
        }
    }

    return @lines;
}

sub _validate_subject_class {
    my $self = shift;

    my $subject_class_name = $self->subject_class_name;
    $self->error_message("No subject_class_name indicated.")
        and return unless $subject_class_name;

    $self->error_message(
        sprintf(
            'This command is not designed to work on a base UR class (%s).',
            $subject_class_name,
        )
    )
        and return if $subject_class_name =~ /^UR::/;

    UR::Object::Type->use_module_with_namespace_constraints($subject_class_name);

    my $subject_class = $self->subject_class;
    $self->error_message(
        sprintf(
            'Can\'t get class meta object for class (%s).  Is this class a properly declared UR::Object?',
            $subject_class_name,
        )
    )
        and return unless $subject_class;

    $self->error_message(
        sprintf(
            'Can\'t find method (all_property_metas) in %s.  Is this a properly declared UR::Object class?',
            $subject_class_name,
        )
    )
        and return unless $subject_class->can('all_property_metas');

    return 1;
}

sub _subject_class_filterable_properties {
    my $self = shift;

    $self->_validate_subject_class
        or return;

    my %props = map { $_->property_name => $_ }
                    $self->subject_class->property_metas;

    return map { $_->[1] }                   # These maps are to get around a bug in perl 5.8 sort
           sort { $a->[0] cmp $b->[0] }      # involving method calls inside the sort sub that may
           map { [ $_->property_name, $_ ] } # do sorts of their own
           grep { substr($_->property_name, 0, 1) ne '_' }  # Skip 'private' properties starting with '_'
           values %props;
}

sub _base_filter {
    return;
}

sub _complete_filter {
    my $self = shift;
    return join(',', grep { defined $_ } $self->_base_filter,$self->filter);
}

sub help_detail {
    my $self = shift;
    return join(
        "\n",
        $self->_style_doc,
        $self->_filter_doc,
    );
}

sub _style_doc {
    return <<EOS;
Listing Styles:
---------------
 text - table like
 csv - comma separated values
 tsv - tab separated values
 pretty - objects listed singly with color enhancements
 html - html table
 xml - xml document using elements

EOS
}

sub valid_styles {
    return (qw/text csv tsv pretty html xml newtext/);
}

sub _hint_string {
    my $self = shift;

    my @show_parts = grep { $self->_show_item_is_property_name($_) }
                          split(',',$self->show);
    return join(',',@show_parts);
}


1;
