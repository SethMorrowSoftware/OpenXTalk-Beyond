#!/usr/bin/env perl

# Prints the version in a file of prebuilt/versions (for example 78.3 from
# prebuilt/versions/icu), or with --major only its first component (78), for
# gyp's <!(...) expansions: prebuilt/libicu.gyp names ICU's data file
# icudt<major>l.dat after it.
#
#   perl decode_prebuilt_version.pl [--major] <versions file>

use strict;
use warnings;

my $major = 0;
if (@ARGV && $ARGV[0] eq '--major')
{
	$major = 1;
	shift @ARGV;
}
die "usage: decode_prebuilt_version.pl [--major] <versions file>\n" unless @ARGV == 1;

open(my $file, '<', $ARGV[0]) || die "Can't open $ARGV[0]: $!\n";
my $version = <$file>;
close($file);
die "$ARGV[0] is empty\n" unless defined $version;

$version =~ s/^\s+|\s+$//g;
die "$ARGV[0] holds no version\n" unless $version =~ /^[0-9]/;
$version =~ s/\..*$// if $major;
print $version;
