#!/usr/bin/perl -WT
#
# ##############################################################################
#
# Copyright (c) 2007,2008 Lars Michelsen http://www.vertical-visions.de
# Copyright (C) 2009 by Maximilian Wilhelm <max@rfc2324.org>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# ##############################################################################
#
# Initial script author: Lars Michelsen
# Perl modules created by: Maximilian Wilhelm <max@rfc2324.orgY
#
# DECRIPTION:   Sends a HTTP(S)-GET to the nagios web server to
#	              enter a downtime for a host or service.
# CHANGES IN 0.4:
# 19.05.2008    - Some code formating
#               - The downtime type is now automaticaly detected on given params
#               - Changed case of the parameters
#               - Added proxy configuration options
#               - User Agent is now "nagios_downtime.pl / <version>"
#               - Added parameter -S and -p for setting server options via param
#
# ##############################################################################

package WakeUpManager::Ext::Nagios;

use strict;
use warnings;
use Carp;

use Net::Ping;
use LWP 5.64;
use Sys::Hostname;
use Switch;

use constant HOST_DOWNTIME => 1;
use constant SERVICE_DOWNTIME => 2;

#
# Some reasoable defaults
my $defaults = { # {{{
	# Protocol for the GET Request, In most cases "http", "https" is also possible
	nagiosWebProto => "http",

	# IP or FQDN of Nagios server (example: nagios.domain.de)
	nagiosServer => "localhost",

	# Port of Nagios webserver (If $nagiosWebProto is set to https, this should be
	# SSL Port 443)
	nagiosWebPort => 80,

	# Web path to Nagios cgi-bin (example: /nagios/cgi-bin) (NO trailing slash!)
	nagiosCgiPath => "/nagios/cgi-bin",

	# User to take for authentication and author to enter the downtime (example:
	# nagiosadmin)
	nagiosUser => "nagiosadmin",

	# Password for above user
	nagiosUserPw => "",

	# Name of authentication realm, set in the Nagios .htaccess file
	# (example: "Nagios Access")
	nagiosAuthName => "",

	# Nagios date format (same like set in value "date_format" in nagios.cfg)
	nagiosDateFormat => "euro",

	# When you have to use a proxy server for access to the nagios server, set the
	# URL here. The proxy will be set for this script for the choosen web protocol
	# When this is set to 'env', the proxy settings will be read from the env.
	proxyAddress => '',

	# Some default options (Usualy no changes needed below this)

	# Default Downtime duration in minutes
	downtimeDuration => 10,

	# Default Downtime text
	downtimeComment => "Nagios::Downtime",
}; # }}}

my @params = qw(nagiosWebProto nagiosServer nagiosWebPort nagiosCgiPath nagiosUser nagiosUserPw nagiosAuthName nagiosDateFormat proxyAddress downtimeDuration downtimeComment);

# Script version
my $version = "0.4";


#
# Little bit of magic to simplify debugging
sub _options(@) { #{{{
	my %ret = @_;

	if ( $ret{debug} ) {
		foreach my $opt (keys %ret) {
			print STDERR __PACKAGE__ . "->_options: $opt => $ret{$opt}\n";
		}
	}

	return \%ret;
} #}}}

#
# new ()
sub new () { # new () : Nagios::Downtime  {{{
	my $self = shift;
	my $class = ref ($self) || $self;

	# Make life easy
	my $args = &_options (@_);

	# Verbosity
	my $debug = (defined $args->{debug}) ? $args->{debug} : 0;
	my $verbose = (defined $args->{verbose}) ? $args->{verbose} : $debug;

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

	}, $class;

	# Get parameters
	foreach my $param (@params) {
		$obj->{$param} = (defined $args->{$param}) ? $args->{$param} : $defaults->{$param};
	}

	return $obj;
} # }}}


sub gettime { # gettime (timestamp) : formated_timestamp {{{
	my $self = shift;

	my $timestamp = shift;

	if ($timestamp eq "") {
		$timestamp = time ();
	}

	my ($sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst) = localtime ($timestamp);
	# correct values
	$year += 1900;
	$month += 1;

	# add leading 0 to values lower than 10
	$month = $month < 10 ? $month = "0".$month : $month;
	$mday = $mday < 10 ? $mday = "0".$mday : $mday;
	$hour = $hour < 10 ? $hour = "0".$hour : $hour;
	$min = $min < 10 ? $min = "0".$min : $min;
	$sec = $sec < 10 ? $sec = "0".$sec : $sec;

	switch ($self->{nagiosDateFormat}) {
		case "euro" {
			return $mday."-".$month."-".$year." ".$hour.":".$min.":".$sec;
		}

		case "us" {
			return $month."-".$mday."-".$year." ".$hour.":".$min.":".$sec;
		}

		case "iso8601" {
			return $year."-".$month."-".$mday." ".$hour.":".$min.":".$sec;
		}

		case "strict-iso8601" {
			return $year."-".$month."-".$mday."T".$hour.":".$min.":".$sec;
		}

		else {
			die __PACKAGE__ . "->gettime(): No valid date format given in \$nagiosDateFormat";
		}
	}
} # }}}


sub schedule_downtime ($$$) { # schedule_downtime (hostname, service, duration) : 0/1 {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->schedule_downtime() has to be called on a blessed object.\n";
	}

	my $hostname = shift;
	my $duration = shift;
	my $service = shift;

	# When a service name is set, this will be a service downtime
	my $downtimeType = (defined $service && length ($service) != 0) ? SERVICE_DOWNTIME : HOST_DOWNTIME;

	if (! $hostname || length ($hostname) == 0) {
		confess __PACKAGE__ . "->schedule_downtime(): No or invalid hostname argument.\n";
	}

	my $nagiosServer = $self->{nagiosServer};
	my $nagiosWebProto = $self->{nagiosWebProto};
	my $nagiosWebPort = $self->{nagiosWebPort};
	my $nagiosCgiPath = $self->{nagiosCgiPath};

	my $proxyAddress = $self->{proxyAddress};

	my $nagiosAuthName = $self->{nagiosAuthName};
	my $nagiosUser = $self->{nagiosUser};
	my $nagiosUserPw = $self->{nagiosUserPw};

	my $downtimeComment = $self->{downtimeComment};


	# Calculate the start of the downtime
	my $start_time = $self->gettime (time);

	# Calculate the end of the downtime
	my $end_time = $self->gettime (time + $duration * 60);


	# If configured, check if Nagios web server is reachable via ping, if not, die.
	if ($self->{ping_check_server}) {
		my $p = Net::Ping->new ();
		if (! $p->ping ($nagiosServer)) {
			# Nagios web server is not pingable
			die "ERROR: Given Nagios web server \"" . $nagiosServer . "\" not reachable via ping\n";
		}
	}

	# initialize browser
	my $oBrowser = LWP::UserAgent->new (keep_alive => 1,timeout => 10);
	$oBrowser->agent (__PACKAGE__ . " (v$version)");

	# Set the proxy address depending on the configured option
	if ($proxyAddress eq 'env') {
		$oBrowser->env_proxy = 1;
	} else {
		$oBrowser->proxy ([$nagiosWebProto], $proxyAddress);
	}

	my $url;
	if ($downtimeType == SERVICE_DOWNTIME) {
		# Schedule Service Downtime
		$url = $nagiosWebProto . "://" . $nagiosServer . ":" . $nagiosWebPort . $nagiosCgiPath . "/cmd.cgi?cmd_typ=56&cmd_mod=2" .
			"&host=" . $hostname . "&service=" . $service .
			"&com_author=" . $nagiosUser . "&com_data=" . $downtimeComment .
			"&trigger=0&start_time=" . $start_time . "&end_time=" . $end_time .
			"&fixed=1&btnSubmit=Commit";

		if ($self->{debug} == 1) {
			print "HTTP-GET: " . $url;
		}
	}

	else {
		# Schedule Host Downtime
		$url = $nagiosWebProto . "://" . $nagiosServer . ":" . $nagiosWebPort . $nagiosCgiPath . "/cmd.cgi?cmd_typ=55&cmd_mod=2" .
			"&host=" . $hostname .
			"&com_author=" . $nagiosUser . "&com_data=" . $downtimeComment .
			"&trigger=0&start_time=" . $start_time . "&end_time=" . $end_time .
			"&fixed=1&childoptions=1&btnSubmit=Commit";

		if ($self->{debug} == 1) {
			print "HTTP-GET: " . $url;
		}

	}

	# Only try to auth if auth informations given
	if ($self->{nagiosAuthName} ne "" && $self->{nagiosUserPw} ne "") {
		# submit auth informations
		$oBrowser->credentials ($nagiosServer . ':' . $nagiosWebPort, $nagiosAuthName, $nagiosUser => $nagiosUserPw);
	}

	# Send the get request to the web server
	my $oResponse = $oBrowser->get ($url);

	if($self->{debug} == 1) {
		print "HTTP-Response: " . $oResponse->content ();
	}

	# Handle response code, not in detail, only first char
	switch (substr ($oResponse->code () ,0 ,1)) {
		# 2xx response code is OK
		case 2 {
			# Do some basic handling with the response content
			switch ($oResponse->content ()) {
				case /Your command request was successfully submitted to Nagios for processing/ {
					return 1;
#					print "OK: Downtime was submited successfully\n";
				}

				case /Sorry, but you are not authorized to commit the specified command\./ {
					return 0;
					die "ERROR: Maybe not authorized or wrong host- or servicename\n";
				}

				case /Author was not entered/ {
					return 0;
					die "ERROR: No Author entered, define Author in \$nagiosUser var\n";
				}

				else {
					return 0;
					die "ERROR: Some undefined error occured, turn debug mode on to view what happened\n";
				}
			}
		}

		case 3 {
			die "ERROR: HTTP Response code 3xx says \"moved url\" (" . $oResponse->code () . ")\n";
		}

		case 4 {
			die "ERROR: HTTP Response code 4xx says \"client error\" (" . $oResponse->code () . ")\n";
		}

		case 5 {
			die "ERROR: HTTP Response code 5xx says \"server error\" (" . $oResponse->code () . " => " . $oResponse->content () . ")\n";
		}

		else {
			die "ERROR: HTTP Response code unhandled by script (" . $oResponse->code (). ")\n";
		}
	}
} # }}}


1;
