package UR::Value::REF;

use strict;
use warnings;

require UR;
our $VERSION = "0.41_04"; # UR $VERSION;

UR::Object::Type->define(
    class_name => 'UR::Value::REF',
    is => ['UR::Value::PerlReference'],
);

1;
#$Header$
