package UR::Value::Text;

use strict;
use warnings;

require UR;
our $VERSION = "0.36"; # UR $VERSION;

UR::Object::Type->define(
    class_name => 'UR::Value::Text',
    is => ['UR::Value'],
);

1;
#$Header$
