#!/usr/bin/env perl

use strict;
use warnings;
use File::Temp;
use Test::More tests => 4;
use IO::File;

my $d = File::Temp::tempdir; #(CLEANUP => 1);
ok($d, "created working directory $d");

mkdir "$d/lib1" or die $!;
mkdir "$d/lib2" or die $!;
IO::File->new(">$d/lib1/Foo.pm")->print('package Foo; 1');
IO::File->new(">$d/lib2/Foo.pm")->print('package Foo; 1');
mkdir "$d/lib1/Foo";
mkdir "$d/lib2/Foo";
eval 'use lib "$d/lib1/"';

chdir "$d/lib2/Foo";
eval "use above 'Foo'";
is(&clean_darwin($INC{"Foo.pm"}), "$d/lib2//Foo.pm",
   "used the expected module");
chdir "$d/" or die "Failed to chdir to $d/: $!";
my $src = q|perl -e 'use above "Foo"; print $INC{"Foo.pm"}'|;
my $v = `$src`; 
is(&clean_darwin($v), "$d/lib2//Foo.pm",
   "Got the original module, not the 2nd one, and not an error."); 

chdir "$d/lib1" or die "Failed to chdir to $d/lib1: $!";
$v = `$src`;
is(&clean_darwin($v), "$d/lib2//Foo.pm",
   "Got the original module, not the 2nd one, and not an error.");

exit(0);

# remove the /private from Mac OS X paths
sub clean_darwin {
    my ($path) = @_;
    return $path unless $^O eq 'darwin';
    $path =~ s{^/private}{};
    return $path;
}
