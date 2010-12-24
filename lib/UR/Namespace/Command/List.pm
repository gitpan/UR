package UR::Namespace::Command::List;
use warnings;
use strict;
use UR;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => "UR::Namespace::Command",
    doc => "list objects, classes, modules"
);

sub sub_command_sort_position { 5 }

1;

