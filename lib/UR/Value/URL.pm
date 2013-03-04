package UR::Value::URL;

use strict;
use warnings;

require UR;
our $VERSION = "0.41_02"; # UR $VERSION;

UR::Object::Type->define(
    class_name => 'UR::Value::URL',
    is => ['UR::Value::Text'],
);

1;
#$Header$
