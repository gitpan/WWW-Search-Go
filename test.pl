# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use ExtUtils::testlib;

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

# 6 tests without "goto MULTI_RESULT"
BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use WWW::Search::Go;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $iTest = 2;

my $sEngine = 'Go';
my $oSearch = new WWW::Search($sEngine);
print ref($oSearch) ? '' : 'not ';
print "ok $iTest\n";

use WWW::Search::Test;
my $debug = 0;

# This test returns no results (but we should not get an HTTP error):
$iTest++;
$oSearch->native_query($WWW::Search::Test::bogus_query);
@aoResults = $oSearch->results();
$iResults = scalar(@aoResults);
print STDOUT (0 < $iResults) ? 'not ' : '';
print "ok $iTest\n";

# goto MULTI_RESULT;

# This query returns 1 page of results:
$iTest++;
my $sQuery = '+LS'.'AM +replic'.'ation';
$oSearch->native_query(WWW::Search::escape_query($sQuery),
                         { 'search_debug' => $debug, },
                      );
@aoResults = $oSearch->results();
$iResults = scalar(@aoResults);
if (($iResults < 2) || (49 < $iResults))
  {
  print STDERR " --- got $iResults results for $sQuery, but expected 2..49\n";
  print STDOUT 'not ';
  }
print "ok $iTest\n";

goto MULTI_RESULT;

# This query returns 2 pages of results:
$iTest++;
$sQuery = 'simpson';
$oSearch->native_query(WWW::Search::escape_query($sQuery),
                         { 'search_debug' => $debug, },
                      );
@aoResults = $oSearch->results();
$iResults = scalar(@aoResults);
if (($iResults < 51) || (99 < $iResults))
  {
  print STDERR " --- got $iResults results for $sQuery, but expected 51..99\n";
  print STDOUT 'not ';
  }
print "ok $iTest\n";

MULTI_RESULT:
# $debug = 1;

# This query returns 3 pages of results:
$iTest++;
$sQuery = 'internet';
$oSearch->native_query($sQuery,
                         { 'search_debug' => $debug, },
                      );
$oSearch->maximum_to_retrieve(120);
@aoResults = $oSearch->results();
$iResults = scalar(@aoResults);
if ($iResults < 101)
  {
  print STDERR " --- got $iResults results for $sQuery, but expected > 101\n";
  print STDOUT 'not ';
  }
print "ok $iTest\n";
