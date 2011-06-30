package UR::Value::FilePath;

use strict;
use warnings;

require UR;
our $VERSION = "0.33"; # UR $VERSION;

UR::Object::Type->define(
    class_name => 'UR::Value::FilePath',
    is => ['UR::Value::FilesystemPath'],
    english_name => 'file path',
);

1;
#$Header$
