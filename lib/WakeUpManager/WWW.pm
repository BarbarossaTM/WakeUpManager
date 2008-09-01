#!/usr/bin/perl -WT
#
# This class is part of the WakeUpManager suite.
#
# WakeUpManager::WWW is the main WWW presentation logic class gathering all
# input data (CGI parameters, username retrieverd via some auth mechanism)
# and so on...
#
# Maximilian Wilhelm <max@rfc2324.org>
#  -- Thu, 29 May 2008 02:13:55 +0200
#


package WakeUpManager::WWW;

use strict;
use Carp;

use CGI;

use WakeUpManager::WWW::Params;

my $supported_languages = {
	'en'    => 'en',
	'en-us' => 'en',

	'de'    => 'de',
	'de-de' => 'de',
	'de-at' => 'de',
	'de-ch' => 'de',
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

	my $cgi_h = CGI->new ();
	if (! $cgi_h || ref ($cgi_h) ne 'CGI') {
		print "Internal error. Please contact the system administrator\n";
		exit 0;
	}

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		cgi_h => $cgi_h,
	}, $class;

	#
	# init
	$obj->{http_params} = $obj->_get_all_cgi_params ($cgi_h);
	if (! $obj->{http_params}) {
		confess __PACKAGE__ . "->new(): Failed to get http_params hash.\n";
	}

	$obj->{params} = WakeUpManager::WWW::Params->new (
		http_params => $obj->{http_params},
		auth => $obj->_get_user_info (),
		lang => $obj->_get_lang (),
		env => $obj->_get_all_ENV_vars (),
		cookies => $obj->_get_all_cookies ($obj->{cgi_h}),
	);

	if (! $args->{no_header}) {
		print $cgi_h->header ('text/html');
	}

	if (! $args->{contentless_mode}) {
		if ($args->{ajax_mode}) {
			require WakeUpManager::WWW::AJAX;
			$obj->{page} = WakeUpManager::WWW::AJAX->new (
				params => $obj->{params},
				ajax_page_name => $args->{ajax_page_name},
				ajax_func_name => $args->{ajax_func_name},
			);
		} else {
			require WakeUpManager::WWW::Page;
			$obj->{page} = WakeUpManager::WWW::Page->new (params => $obj->{params});
		}
	}

	return $obj;
} #}}}

sub get_page () { # get_page () : page_contents {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_page(): Has to be called on bless'ed object\n";
	}

	return $self->{page}->get_page ();
} # }}}

sub get_params () { # {{{
	my $self = shift;

	if (! $self || ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_params(): Has to be called on bless'ed object.\n";
	}

	return $self->{http_params};
} # }}}

################################################################################
#			internal helper functions			       #
################################################################################

#
# Retrieve all arguments from CGI and put them into useful data structure
sub _get_all_cgi_params ($) { # _get_all_cgi_params (\CGI) : \%params {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_get_all_cgi_params(): Has to be called on bless'ed object.\n";
	}

	my $cgi_h = shift;
	if (! $cgi_h || ref ($cgi_h) ne 'CGI') {
		confess __PACKAGE__ . "->_get_all_cgi_params(): No or invalid 'cgi_h' parameter given.\n";
	}
	# Prepare empty parameter hashref
	my $params_hash = {};

	# Put all parameters into hash
	my @param_names = $cgi_h->param ();
	foreach my $param_name (@param_names) {
		my @values = $cgi_h->param ($param_name);

		# If it's a single value, just push it into the hash
		if (scalar (@values) == 1) {
			$params_hash->{$param_name} = $values[0];

		# If there's more than one value, push the arrayref into
		# the hash for convenience.
		} else {
			$params_hash->{$param_name} = \@values;
		}
	}

	if (! $params_hash->{page}) {
		$params_hash->{page} = 'Default';
	}

	return $params_hash;
} # }}}

sub _get_all_cookies ($) { # _get_all_cookies (\CGI) : \%cookies {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_get_all_cookies(): Has to be called on bless'ed object.\n";
	}

	my $cgi_h = shift;
	if (! $cgi_h || ref ($cgi_h) ne 'CGI') {
		confess __PACKAGE__ . "->_get_all_cookies(): No or invalid 'cgi_h' parameter given.\n";
	}
	# Prepare empty parameter hashref
	my $cookies_hash = {};

	my @cookie_names = $cgi_h->cookie ();
	foreach my $cookie_name (@cookie_names) {
		$cookies_hash->{$cookie_name} = $cgi_h->cookie ($cookie_name);
	}

	return $cookies_hash;
} # }}}

sub _get_user_info () { # _get_user_info () : \%user_info {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_get_all_params(): Has to be called on bless'ed object.\n";
	}

	my $user = $ENV{'REMOTE_USER'};
	if (defined $user) {
		$user =~ s/@.*$//;
	} else {
		$user = "";
	}

	return { user => $user };
} # }}}

sub _get_lang () { # _get_lang () : <lang> {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_get_all_params(): Has to be called on bless'ed object.\n";
	}

	my $HTTP_ACCEPT_LANGUAGE = $ENV{'HTTP_ACCEPT_LANGUAGE'};

	# Default to 'en' if no Content-Language is set
	if (! defined $HTTP_ACCEPT_LANGUAGE) {
		return 'en';
	}

	$HTTP_ACCEPT_LANGUAGE =~ s/;q=[0-9.]+//;
	my @HTTP_ACCEPT_LANGUAGE_LIST = split (',', $HTTP_ACCEPT_LANGUAGE);
	foreach my $lang (@HTTP_ACCEPT_LANGUAGE_LIST) {
		if (defined $supported_languages->{$lang}) {
			return $supported_languages->{$lang};
		}
	}

	return 'en';
} # }}}

sub _get_all_ENV_vars () { # {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_get_all_params(): Has to be called on bless'ed object.\n";
	}

	my $env = {};

	foreach my $key (keys %ENV) {
		$env->{$key} = $ENV{$key};
	}

	return $env;
} # }}}

sub _get_POST_data () { # {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->_get_all_params(): Has to be called on bless'ed object.\n";
	}

	return $self->{cgi_h}->param('POSTDATA');
} # }}}

1;

# vim:foldmethod=marker
