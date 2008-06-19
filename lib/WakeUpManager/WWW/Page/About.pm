#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Mon 02 Jun 2008 11:16:40 AM CEST
#

package WakeUpManager::WWW::Page::About;

use strict;
use Carp;

##
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

sub new () { # new () :  {{{
	my $self = shift;
	my $class = ref ($self) || $self;

	# Make life easy
	my $args = &_options (@_);

	# Verbosity
	my $debug = (defined $args->{debug}) ? $args->{debug} : 0;
	my $verbose = (defined $args->{verbose}) ? $args->{verbose} : $debug;

	my $params = $args->{params};
	if (! $params || ref ($params) ne 'WakeUpManager::WWW::Params') {
		confess __PACKAGE__ . "->new (): No or invalid 'params' parameter.\n";
	}

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		params => $params,
	}, $class;

	return $obj;
} #}}}

sub get_content_elements() {
	return {};
}

sub get_header_elements () {
	my $self = shift;

	my $lang = $self->{params}->get_lang ();
	if ($lang eq 'de') {
		return { h2 => "&Uuml;ber WUM" };
	} else {
		return { h2 => "About WUM" };
	}
}



1;

# vim:foldmethod=marker
