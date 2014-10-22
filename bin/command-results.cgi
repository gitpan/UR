#!/usr/bin/env perl

use FindBin '$Bin';
use lib "$Bin/../lib";
use JSON;

# this "job status/result checker" really just lets you pick some file in the job's directory and dump it back
# http://mysite/cgi-bin/command-check.cgi?job_id=12345.ABCDE&key=stdout

use Command;
use CGI;
use IO::File;
use File::Temp;

my $cgi = CGI->new();
my $job_id = $cgi->param('job_id');

print $cgi->header();

my $job_dir = $job_id;
unless (-d $job_dir) {
    print "Job not found!\n";
    exit 1;
}

my ($pid) = ($job_id =~ /(\d+)\./);

my @files = sort glob("$job_id/*");

my %results;
for my $file (@files) {
    my ($name) = ($file =~ /^$job_id\/(.*)/);
    my $content = join('',IO::File->new($file)->getlines);
    $results{$name} = $content;
}

print to_json(\%results);
