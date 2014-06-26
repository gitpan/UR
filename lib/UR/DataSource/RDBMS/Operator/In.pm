use strict;
use warnings;

package UR::DataSource::RDBMS::Operator::In;

# This allows the size of an autogenerated IN-clause to be adjusted.
# The limit for Oracle is 1000, and a bug requires that, in some cases
# we drop to 250.
use constant IN_CLAUSE_SIZE_LIMIT => 250;

our @CARP_NOT = qw( UR::DataSource::RDBMS );

sub _negation_clause { '' }

sub generate_sql_for {
    my($class, $expr_sql, $val, $escape) = @_;

    unless (ref($val) eq 'ARRAY') {
        $val = [$val];
    }

    unless (@$val) {
    # an empty list was passed-in.
        # since "in ()", like "where 1=0", is self-contradictory,
        # there is no data to return, and no SQL required
        Carp::carp("Null in-clause");
        return;
    }

    my @list = do { no warnings 'uninitialized';
                    sort @$val; };
    my $has_null = _list_contains_null(\@list);
    my $wrap = ($has_null or @$val > IN_CLAUSE_SIZE_LIMIT ? 1 : 0);
    my $cnt = 0;
    my $sql = '';
    $sql .= "\n(\n   " if $wrap;
    while (my @set = splice(@list,0,IN_CLAUSE_SIZE_LIMIT))
    {
        $sql .= "\n   or " if $cnt++;
        $sql .= $expr_sql
            . $class->_negation_clause
            . " in (" . join(",",map { UR::Util::sql_quote($_) } @set) . ")";
    }
    if ($has_null) {
        $sql .= "\n  or $expr_sql is "
            . $class->_negation_clause
            . ' null';
    }
    $sql .= "\n)\n" if $wrap;

    return ($sql);
}

sub _list_contains_null {
    my $list = shift;

    foreach my $elt ( @$list ) {
        if (! defined($elt)
            or
            length($elt) == 0
        ) {
            return 1;
        }
    }
    return '';
}

1;
