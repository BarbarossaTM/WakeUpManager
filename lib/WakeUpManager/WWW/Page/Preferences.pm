#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Mon 02 Jun 2008 11:16:40 AM CEST
#

package WakeUpManager::WWW::Page::Preferences;

use strict;
use Carp;

my $names = {
	de => {
		horizontal => 'Horizontal',
		vertical => 'Vertikal',
	},

	en => {
		horizontal => 'horizontal',
		vertical => 'vertical',
	},
};

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
		confess __PACKAGE__ . "->new(): No or invalid 'params' argument.";
	}

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		params => $params,
	}, $class;

	return $obj;
} #}}}

sub get_content_elements() {
	my $self = shift;

	my $lang_hash = $names->{en};

	my $lang = $self->{params}->get_lang ();
	if ($lang eq 'de') {
		$lang_hash = $names->{de};
	}

	my $content_elements = {};

	my $orientation = $self->{params}->get_cookie (timetable_orientation);
	if (! defined $orientation) {
		$orientation = 'horizontal';
	}

	if ($orientation eq 'vertical') {
		$content_elements->{timetable_orientation_radio} = "<input type=\"radio\" name=\"timetable_orientation\" value=\"horizontal\"> $lang_hash->{horizontal} <br> <input type=\"radio\" name=\"timetable_orientation\" value=\"vertical\" checked> $lang_hash->{vertical}\n";
	} else {
		$content_elements->{timetable_orientation_radio} = "<input type=\"radio\" name=\"timetable_orientation\" value=\"horizontal\" checked> $lang_hash->{horizontal} <br> <input type=\"radio\" name=\"timetable_orientation\" value=\"vertical\"> $lang_hash->{vertical} \n";
	}

	return $content_elements;
}

sub get_header_elements () {
	my $self = shift;

	my $h2 = 'Preferences';
	if ($self->{params}->get_lang() eq 'de') {
		$h2 = 'Einstellungen';
	}

	return { header_opt => "<script src=\"/ui/inc/Preferences.js\" type=\"text/javascript\"></script>",
	         h2 => $h2,  };
}



1;

# vim:foldmethod=marker
