#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Fri May 30 03:24:46 2008
#

package WakeUpManager::WWW::Params;

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

	# Retrieve and check http_params
	my $http_params = $args->{http_params};
	if (! $http_params || ref ($http_params) ne 'HASH') {
		confess __PACKAGE__ . "->new(): No or invalid 'http_params' argument.\n";
	}

	# Check for page entry
	if (! $http_params->{page}) {
		confess __PACKAGE__ . "->new(): No 'page' entry in 'http_params' found, but is required.\n";
	}

	# Retrieve and check 'auth' information
	my $auth = $args->{auth};
	if (! $auth || ref ($auth) ne 'HASH') {
		confess __PACKAGE__ . "->new(): No or invalid 'auth' argument.\n";
	}

	# Retrieve and check 'lang' attribute
	my $lang = $args->{lang};
	if (! $lang || $lang =~ m/[^a-z]/) {
		confess __PACKAGE__ . "->new(): No or invalid 'lang' arguments.\n";
	}

	# Retrieve and check 'lang' attribute
	my $env = $args->{env};
	if (! $env || ref ($env) ne 'HASH' ) {
		confess __PACKAGE__ . "->new(): No or invalid 'env' arguments.\n";
	}

	my $cookies = $args->{cookies};
	if (! $cookies || ref ($cookies) ne 'HASH') {
		confess __PACAKGE__ . "->new(): No or invalid 'cookies' argument.\n";
	}

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		http_params => $http_params,
		page => $http_params->{page},
		lang => $lang,
		env => $env,
		cookies => $cookies,

		auth => $auth,
	}, $class;

	return $obj;
} #}}}


sub get_page_name () { # get_page_name () : page_name {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_page_name(): Has to be called on bless'ed object.\n";
	}

	return $self->{page};
} # }}}

sub get_http_params () { # get_http_params () : \%htt_params {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_page_name(): Has to be called on bless'ed object.\n";
	}

	return $self->{http_params};
} # }}}

sub get_auth_info () { # get_auth_info () : \%auth_info {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_page_name(): Has to be called on bless'ed object.\n";
	}

	return $self->{auth};
} # }}}

sub get_user() { # get_user () : user_name {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_page_name(): Has to be called on bless'ed object.\n";
	}

	return $self->{auth}->{user};
} # }}}

sub get_lang () { # get_lang () : lang {{{
	my $self = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_page_name(): Has to be called on bless'ed object.\n";
	}

	return $self->{lang};
} # }}}

sub get_http_param ($) { # get_http_param (param_name) : param_value {{{
	my $self = shift;

	my $param_name = shift;

	if (! $self || ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_http_params(): Has to be called on bless'de object.\n";
	}

	if (! $param_name) {
		return undef;
	}

	return $self->{http_params}->{$param_name};
} # }}}

sub get_env_var ($) { # get_env_var (env_key) : ENV_value {{{
	my $self = shift;

	my $env_var_name = shift;

	if (! $self || ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_env_var(): Has to be called on bless'ed object.\n";
	}

	if (! $env_var_name) {
		return undef;
	}

	return $self->{env}->{$env_var_name};
} # }}}

sub get_cookies ($) { # get_cookie (cookies_name) : cookie_value {{{
	my $self = shift;

	my $cookie_name = shift;

	if (! $self || ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_env_var(): Has to be called on bless'ed object.\n";
	}

	if (! defined $cookie_name) {
		return undef;
	}

	return $self->{cookies}->{$env_var_name};
} # }}}


1;

# vim:foldmethod=marker
