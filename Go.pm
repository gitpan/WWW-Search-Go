#!/usr/local/bin/perl -w
#
# Go.pm
# by Alain Barbet
# Copyright (C) 2000
# $Id: Go.pm,v 0.1 2000/10/14 21:22:32 alian Exp $
#

package WWW::Search::Go;

=head1 NAME

WWW::Search::Go - backend class for searching with go.com

=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Go');

=head1 DESCRIPTION

This class is an Go specialization of WWW::Search.
It handles making and interpreting Go searches
F<http://www.Go.com>, older Infoseek search engine.

This class exports no public interface; all interaction should be done
through WWW::Search objects.

=head1 USAGE EXAMPLE

  use WWW::Search;

  my $oSearch = new WWW::Search('Go');
  $oSearch->maximum_to_retrieve(100);

  #$oSearch ->{_debug}=1;

  my $sQuery = WWW::Search::escape_query("cgi");
  $oSearch->gui_query($sQuery);

  while (my $oResult = $oSearch->next_result())
  {
        print $oResult->url,"\t",$oResult->title,"\n";
  }


=head1 AUTHOR

C<WWW::Search::Go> is written by Alain BARBET,
alian@alianwebserver.com

=cut

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '0.1';

use Carp ();
use strict "vars";
use WWW::Search(generic_option);
require WWW::SearchResult;

# private
sub native_setup_search
	{
    	my($self, $native_query, $native_options_ref) = @_;
    	$self->user_agent('alian');
    	$self->{_next_to_retrieve} = 0;
  	
	if (!defined($self->{_options})) {
	$self->{_options} = {
	    'col' 	=> 'WW',
	    'qt' 	=> $native_query,
	    'pat' 	=> 'ws',
	    'unc' 	=> 30,
	    'st'	=> 0,
	    'fis'	=> 0,
	    'stu'	=> 10,
	    'nh'	=> 10,
	    'svx'	=> WD_next10,
	    'fys'	=> 0,
	    'tid'	=> undef,
	    'ru'	=> 0,
	    'ggoq'	=> $native_query,
	    'oq'	=> $native_query,
	    'search_url' => 'http://www.go.com/Split',
        };}
    	my($options_ref) = $self->{_options};
    	if (defined($native_options_ref)) 
    		{
		# Copy in new options.
		foreach (keys %$native_options_ref) {$options_ref->{$_} = $native_options_ref->{$_};}
    		}
    	# Process the options.
    	# (Now in sorted order for consistency regarless of hash ordering.)
    	my($options) = '';
    	foreach (sort keys %$options_ref) 
    		{
		# printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
		next if (generic_option($_));
		$options .= $_ . '=' . $options_ref->{$_} . '&' if (defined $options_ref->{$_});
    		}

    	# Finally figure out the url.
    	$self->{_base_url} = $self->{_next_url} = $self->{_options}{'search_url'} ."?" . $options;
    	print STDERR $self->{_base_url} . "\n" if ($self->{_debug});
	}

# private
sub create_hit
	{
	my ($self,$url,$titre,$description)=@_;
	my $hit = new WWW::SearchResult;
	$hit->add_url($url);
	$hit->title($titre);
	$hit->description($description);
	push(@{$self->{cache}},$hit);
	return 1;
	}

# private
sub native_retrieve_some
	{
 	my ($self) = @_;      
	my($hits_found) = 0;
	my ($buf,$langue);

 	#fast exit if already done
	return undef if (!defined($self->{_next_url}));    
	print STDERR "WWW::Search::Go::native_retrieve_some: fetching " . $self->{_next_url} . "\n" if ($self->{_debug});
	my($response) = $self->http_request('GET', $self->{_next_url});
	$self->{response} = $response;
	print STDERR "WWW::Search::Go GET  $self->{_next_url} return ",$response->code,"\n"  if ($self->{_debug});
  	if (!$response->is_success) {return undef;};
	$self->{_next_url} = undef; 

    	# parse the output
    	my($HEADER, $WAIT_HIT, $HITS, $INHIT, $TRAILER, $POST_NEXT) = (1..10);  # order matters
    	my($state) = ($HEADER);
    	my($url,$titre,$description);
    	foreach ($self->split_lines($response->content())) {#print $_,"\n";
        next if m@^$@; # short circuit for blank lines
	######
	# HEADER PARSING: find the number of hits
	#
	if ($state == $HEADER && m!<b>No results found.  Please revise your search.</b>!) 
		{
	    	$self->approximate_result_count(0);
	    	$state = $TRAILER;
	    	print STDERR "No result\n"  if ($self->{_debug});
		}
	elsif ($state == $HEADER && m!<b>([\d,]*) matches</b>!) 
		{
	    	my $nb = $1;
	    	$nb=~s/,//g;
	    	$self->approximate_result_count($nb);
	    	$state = $WAIT_HIT;
	    	print STDERR "$nb hits found\n"  if $self->{_debug};
		}
	elsif ($state == $WAIT_HIT && m{<!-- Web results -->}) {$state=$HITS;}
	######
	# HITS PARSING: find each hit
	#
	elsif ($state == $HITS && m!<tr><td class="text-md">!) {$state=$INHIT;}
	elsif ($state == $INHIT && m!<b>\d*. <a href="(.*?)">(.*)</a></b><br />!) {$url=$1;$titre=$2;}
	elsif ($state == $INHIT && m!(.*)<br /><span class="greylink">.*</span></td>!) {$description=$1;}
	elsif ($state == $INHIT && m!<spacer type="block" height="7"></td>!) 
		{
		$hits_found+=$self->create_hit($url,$titre,$description);
		undef $url;
		undef $titre;
		undef $description;
		$state=$HITS;
		}

	######
	# NEXT URL
	#
	elsif ($state == $HITS && m!<a href="([^"]*)">Next&nbsp;10&nbsp;&gt;</a>!) 
		{
		$self->{_next_url} = new URI::URL($1, $self->{_base_url});
		print STDERR "Found next, $1.\n" if $self->{_debug};
		}
	}

	return $hits_found;
	}

1;
