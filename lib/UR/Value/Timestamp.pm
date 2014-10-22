package UR::Value::Timestamp;
use strict;
use warnings;
require UR;
our $VERSION = "0.392"; # UR $VERSION;

UR::Object::Type->define(
    class_name => 'UR::Value::Timestamp',
    is => ['UR::Value::DateTime'],
);

1;
#$Header$
