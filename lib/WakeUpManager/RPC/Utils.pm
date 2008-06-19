#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Wed 14 Nov 2007 02:25:00 AM CET
#

package WakeUpManager::RPC::Utils;

use strict;
use base 'Exporter';
use Carp qw(cluck confess);

use WakeUpManager::RPC::Result;

# Functions to be exporter
our @EXPORT = qw(rpc_return_err rpc_return_ok rpc_result_ok rpc_get_errmsg rpc_get_value);

sub rpc_return_err ($$) { # rpc_return_err (errcode : <int>, errormsg : <string>)  : \WakeUpManager::RPC::Result {{{
	my $errcode = shift;
	my $errormsg = shift;

	if (! defined $errcode) {
		confess __PACKAGE__ . "::rpc_return_err(): No errcode given.\n";
	}

	if ($errcode == 0) {
		confess __PACKAGE__ . "::rpc_return_err(): Argument errorcode has to be non-zero.\n";
	}

	# XXX
	if (! defined $errormsg) {
		return confess "rpc_return_err() called without errormsg.\n";
	}

	return WakeUpManager::RPC::Result->new (retcode => $errcode,
						errormsg => $errormsg,
						retval => undef);
} # }}}

sub rpc_return_ok (;$) { # rpc_return_ok (return value) : \WakeUpManager::RPC::Result {{{
	my $retval = shift;

	return WakeUpManager::RPC::Result->new (retval => $retval,
						retcode => 0,
						errormsg => undef);
} # }}}



sub rpc_result_ok ($) { # rpc_result_ok (\WakeUpManager::RPC::Result) : 0/1 {{{
	my $rpc_result = shift;

	if (! $rpc_result || ref ($rpc_result) ne "WakeUpManager::RPC::Result") {
		confess __PACKAGE__ . "->rpc_get_errmsg called without/with invalid argument.\n";
	}

	return ($rpc_result->{retcode} == 0);
} # }}}


sub rpc_get_errmsg ($) { # rpc_get_errmsg (\WakeUpManager::RPC::Result) : string # {{{
	my $rpc_result = shift;

	if (! $rpc_result || ref ($rpc_result) ne "WakeUpManager::RPC::Result") {
		confess __PACKAGE__ . "->rpc_get_errmsg called without/with invalid argument.\n";
	}

	if (rpc_result_ok ($rpc_result)) {
		cluck "Why do you want an error message if there is no error?!\n";
		return undef;
	}

	if (! defined $rpc_result->{errormsg}) {
		return "Unknown error\n";
	}

	return $rpc_result->{errormsg};
} # }}}

sub rpc_get_value ($) { # rpc_get_value (\WakeUpManager::RPC::Result) : value # {{{
	my $rpc_result = shift;

	if (! $rpc_result || ref ($rpc_result) ne "WakeUpManager::RPC::Result") {
		confess __PACKAGE__ . "->rpc_get_value called without/with invalid argument.\n";
	}

	if (! rpc_result_ok ($rpc_result)) {
		cluck "Can't return a value on errornous RPC result. You might want to check 'rpc_result_ok' before next time...\n";
		return undef;
	}

	return $rpc_result->{retval};
} # }}}

1;

# vim:foldmethod=marker
