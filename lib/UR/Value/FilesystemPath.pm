package UR::Value::FilesystemPath;

use strict;
use warnings;
require UR;
our $VERSION = "0.33"; # UR $VERSION;

UR::Object::Type->define(
    class_name => 'UR::Value::FilesystemPath',
    is => 'UR::Value',
);

1;
