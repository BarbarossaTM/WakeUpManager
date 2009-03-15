#!/usr/bin/perl -WT
#
#   WakeUpManager suite
#
#   Copyright (C) 2007-2009 Maximilian Wilhelm <max@rfc2324.org>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along
#   with this program; if not, write to the Free Software Foundation, Inc.,
#   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Generic RPC Wrapper for any WakeUpManager class which needs to be callable
# from somewhere else.
#
# The class which should be wrapped only has to provide a 'get_methods'
# function which returns a hashref containing functionname -> \&sub
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Sun 09 Dec 2007 02:08:38 AM CET
#

package WakeUpManager::RPC::Wrapper;

use strict;
use Carp;

use WakeUpManager::RPC::Utils;

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

	my $wrapped_obj = $args->{wrapper_obj};
	# Check for potential badness
	# If there is no reference or one to a usual data structure this is not good...
	if (! defined $wrapped_obj || ! ref ($wrapped_obj) || grep { /^(ARRAY|HASH|CODE)$/ } ref ($wrapped_obj)) {
		confess __PACKAGE__ . "->new(): Required parameter wrapper_obj missing or invalid.\n";
	}

	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		wrapped_obj => $wrapped_obj,

		methods => {},
	}, $class;

	$obj->setup_methods_hash ();

	return $obj;
} #}}}

#
# Wrap all method calls with _rpc_wrap
#
# This method has to be called again in case of $wrapper_obj->get_methods()
# changed it's contents and you want to publish the changes.
sub setup_methods_hash () { # setup_methods_hash () :
	my $self = shift;

	my $obj_methods = $self->{wrapped_obj}->get_methods ();
	if (ref ($obj_methods) ne 'HASH') {
		confess __PACKAGE__ . "->setup_methods_hash(): get_methods() on object did not return a hash_ref\n";
	}

	# Wrap each function in _rpc_wrap, to make things easy and generic
	foreach my $method_name (keys %{$obj_methods}) {
		$self->{methods}->{$method_name} = sub { _rpc_wrap ($self->{wrapped_obj}, $obj_methods->{$method_name}, @_); };
	}
}


#
# Return the methods hash
sub get_methods () { # get_methods() : \%methods
	my $self = shift;

	return $self->{methods};
}


#
# Main magic of this class
#
# This function wraps all RPC calls and makes sure that any function called
# via RPC will return a WakeUpManager::RPC::Result object, to make this easier
# on client side as the expected data format is unique.
sub _rpc_wrap ($$@) { # _rpc_wrap ($class_ref, $function_ref, @args) : \WakeUpManager::RPC::Result
	my $obj_ref = shift;
	my $func_ref = shift;
	my @arg = @_;

	my $result = &$func_ref (@arg);
	if ($obj_ref->get_error_no ()) {
		return rpc_return_err ($obj_ref->get_error_no (), $obj_ref->get_error_msg ());
	} else {
		return rpc_return_ok ($result);
	}
}

1;

# vim:foldmethod=marker
