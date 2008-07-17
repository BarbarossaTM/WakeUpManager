#!/usr/bin/perl -WT
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Sun 18 Nov 2007 04:01:58 PM CET
#

package WakeUpManager::DB::HostDB;

use strict;
use Carp qw(cluck confess);

use DBI;

use WakeUpManager::Common::Utils qw(:time);

my $true  = (1 == 1);
my $false = (1 != 1);

##
# Little bit of magic to simplify debugging
sub _options(@) { # _options (@) : \% {{{
	my %ret = @_;

	if ( $ret{debug} ) {
		foreach my $opt (keys %ret) {
			print STDERR __PACKAGE__ . "->_options: $opt => $ret{$opt}\n";
		}
	}

	return \%ret;
} #}}}

sub new () { # new () : WakeUpManager::DB::HostDB {{{
	my $self = shift;
	my $class = ref ($self) || $self;

	# Make life easy
	my $args = &_options (@_);

	# Verbosity
	my $debug = (defined $args->{debug}) ? $args->{debug} : 0;
	my $verbose = (defined $args->{verbose}) ? $args->{verbose} : $debug;

	#
	# Database connectivity
	my $dbi_param = $args->{dbi_param};
	if (! defined $dbi_param || ref ($dbi_param) ne 'ARRAY') {
		die __PACKAGE__ . "->new(): Missing or invalid dbi_param option!\n";
	}

	my $db_h = undef;
	eval { $db_h = DBI->connect (@{$dbi_param}); };
	if (! $db_h) {
		cluck __PACKAGE__ . "->new(): Failed to connect to databse, check your dbi_param's!\n";
		return undef;
	}

	#
	# Create object
	my $obj = bless {
		debug => $debug,
		verbose => $verbose,

		db_h => $db_h,
	}, $class;

	# Disconnect at program end
	END {
		if ($db_h) {
			$db_h->disconnect ();
		}
	};

	return $obj;
} #}}}


################################################################################
#			General Host / Hostgroup stuff			       #
################################################################################

#
# Get hostid for given hostname
sub get_host_id ($) { # get_host_id (hostname) : host_id # {{{
	my $self = shift;

	my $hostname = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! defined $hostname);

	my $sth = $self->{db_h}->prepare ("SELECT host_id from host where name = :name");
	$sth->bind_param (":name", $hostname) or confess;
	$sth->execute () or confess;
	my @rowdata = $sth->fetchrow ();

	return $rowdata[0];
} # }}}

sub get_host_name ($) { # get_host_name (host_id : hostname # {{{
	my $self = shift;

	my $host_id = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! $self->is_valid_host ($host_id));

	my $sth = $self->{db_h}->prepare ("
		SELECT	name
		FROM	host
		WHERE	host_id = :host_id") or confess ();
	$sth->bind_param (":host_id", $host_id) or confess ();
	$sth->execute () or confess ();
	my @rowdata = $sth->fetchrow ();

	return $rowdata[0];
} # }}}

#
# Check if the host with the given ID exists in database
sub is_valid_host ($) { # is_valid_host (host_id) : 0/1 # {{{
	my $self = shift;

	my $host_id = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! defined $host_id || $host_id =~ m/[^0-9]/);

	my $sth = $self->{db_h}->prepare ("
		SELECT	host_id
		FROM	host
		WHERE	host_id = :host_id") or confess ();
	$sth->bind_param (":host_id", $host_id) or confess ();
	$sth->execute () or confess ();

	return ($sth->rows () == 1);
} # }}}


sub get_host_state ($) { # get_host_state (host_id) : { boot_host => 0/1, shutdown_host => 0/1 } # {{{
	my $self = shift;

	my $host_id = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! defined $host_id || $host_id =~ m/[^0-9]/);

	my $sth = $self->{db_h}->prepare ("
		SELECT	boot_host, shutdown_host
		FROM	host
		WHERE	host_id = :host_id") or confess ();
	$sth->bind_param (":host_id", $host_id) or confess ();
	$sth->execute () or confess ();

	return $sth->fetchrow_hashref ();
} # }}}

sub set_host_state ($$$) { # set_host_state (host_id, boot_host, shutdown_host) :  {{{
	my $self = shift;

	my $host_id = shift;

	my $boot_host = shift;
	my $shutdown_host = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! $self->is_valid_host ($host_id));

	# Only return undef if *both* states are unset
	return undef if (! defined $boot_host && ! defined $shutdown_host);

	my $boot_host_str = (defined $boot_host) ? "boot_host = :boot_host" : "";
	my $shutdown_host_str = (defined $shutdown_host) ? ",shutdown_host = :shutdown_host" : "";

	my $sth = $self->{db_h}->prepare ("
		UPDATE	host
		SET	$boot_host_str
			$shutdown_host_str
		WHERE	host_id = :host_id") or confess ();
	$sth->bind_param (":host_id", $host_id) or confess ();

	if (defined $boot_host) {
		$boot_host = ($boot_host) ? 't' : 'f';
		$sth->bind_param (":boot_host", $boot_host) or confess ();
	}

	if (defined $shutdown_host) {
		$shutdown_host = ($shutdown_host) ? 't' : 'f';
		$sth->bind_param (":shutdown_host", $shutdown_host) or confess ();
	}

	$sth->execute () or confess ();
} # }}}

#
# Get all information necessary to boot the given host
sub get_host_boot_info ($) { # get_network_id_of_host (host_id) : { net_id => int, mac_addr => MAC, net_cidr => CIDR }  {{{
	my $self = shift;

	my $host_id = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! $self->is_valid_host ($host_id));

	my $sth = $self->{db_h}->prepare ("
		SELECT	h.net_id, mac_addr, net_cidr
		FROM	host h,
			network n
		WHERE		h.host_id = :host_id
			AND	h.net_id = n.net_id") or confess ();
	$sth->bind_param (":host_id", $host_id) or confess ();
	$sth->execute () or confess ();

	return $sth->fetchrow_hashref ();
} # }}}


#
# Get the hostgroup_id for the given hostgroup_name
sub get_hostgroup_id ($) { # get_hostgroup_id (hostgroup_name) : id {{{
	my $self = shift;

	my $hostgroup_name = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! $hostgroup_name);

	my $sth_grp_id = $self->{db_h}->prepare ("
		SELECT	hostgroup_id
		FROM	hostgroup
		WHERE	name = :name") or confess ();
	$sth_grp_id->bind_param (":name", $hostgroup_name) or confess();
	$sth_grp_id->execute () or confess ();

	my @rowdata = $sth_grp_id->fetchrow ();
	return $rowdata[0];
} # }}}

sub get_hostgroup_name ($) { # get_hostgroup_name (hostgroup_id) : name {{{
	my $self = shift;

	my $hostgroup_id = shift;

	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! $hostgroup_id);

	my $sth_grp_id = $self->{db_h}->prepare ("
		SELECT	name
		FROM	hostgroup
		WHERE	hostgroup_id = :hg_id") or confess ();
	$sth_grp_id->bind_param (":hg_id", $hostgroup_id) or confess();
	$sth_grp_id->execute () or confess ();

	my @rowdata = $sth_grp_id->fetchrow ();
	return $rowdata[0];
} # }}}


#
# Get a list of all hosts associated with the given hostgroup
#
# The list will be returned as a reference to a hash containing the host ids
# as keys and the according names as values.
sub get_hosts_in_hostgroup ($) { # get_hosts_in_hostgroup (hostgroup_id) : \%host_list  {{{
	my $self = shift;

	my $hostgroup_id = shift;

	my $host_list =  {};

	return undef if (ref ($self) ne __PACKAGE__);

	# In case of no or non-numeric value, there's no chance for us
	return undef if (! $hostgroup_id || $hostgroup_id =~ m/[^[0-9]]/);

	# Prepare hostgroup tree query
	my $sth_grp_hosts = $self->{db_h}->prepare ("
		SELECT	host.host_id, name, boot_host, shutdown_host
		FROM	hostgroup_host, host
		WHERE		hostgroup_id = :id
			AND	hostgroup_host.host_id = host.host_id") or confess ();
	$sth_grp_hosts->bind_param (":id", $hostgroup_id) or confess ();
	$sth_grp_hosts->execute () or confess ();

	while (my @rowdata = $sth_grp_hosts->fetchrow ()) {
		$host_list->{$rowdata[0]} = {
			id => $rowdata[0],
			name => $rowdata[1],
			boot_host => $rowdata[2],
			shutdown_host => $rowdata[3],
		};
	}

	return $host_list;

} # }}}

#
# Get a list of all member hostgroups and their member hostgroups (...)
# of the given group.
#
# The list will be returned as a reference to a hash containing the hostgroup
# ids as keys and the according names as values.
sub get_hostgroups_below_group ($) { # get_hostgroups_below_group (hostgroup_id) : \%hostgroup_list {{{
	my $self = shift;

	my $hostgroup_id = shift;

	my $hostgroup_list = {};

	return undef if (ref ($self) ne __PACKAGE__);

	# In case of no or non-numeric value, there's no chance for us
	return undef if (! $hostgroup_id || $hostgroup_id =~ m/[^0-9]/);

	# Prepare hostgroup tree query
	my $sth_grp_tree = $self->{db_h}->prepare ("
		SELECT	member_group_id
		FROM	hostgroup_tree
		WHERE	super_group_id = :id") or confess ();

	my $sth_grp_name = $self->{db_h}->prepare ("
		SELECT	name
		FROM	hostgroup
		WHERE	hostgroup_id = :id") or confess ();


	$sth_grp_name->bind_param (":id", $hostgroup_id);
	$sth_grp_name->execute () or confess;
	my @rowdata = $sth_grp_name->fetchrow ();

	# Walk down hostgroup tree and remeber visited hostgroups (beware of cycles...)
	$sth_grp_tree->bind_param (":id", $hostgroup_id) or confess;
	$sth_grp_tree->execute() or confess;

	my @hostgroups = ();
	while (@rowdata = $sth_grp_tree->fetchrow ()) {
		push @hostgroups, $rowdata[0];
	}

	while (@hostgroups) {
		my $group_id = shift @hostgroups;

		# Group already known, go on
		if (exists $hostgroup_list->{$group_id}) {
			next;
		}

		# XXX Superflous?!
#		$hostgroup_list->{$group_id} = 1;

		# Get name of group
		$sth_grp_name->bind_param (":id", $group_id) or confess ();
		$sth_grp_name->execute() or confess;
		@rowdata = $sth_grp_name->fetchrow ();
		$hostgroup_list->{$group_id} = $rowdata[0];

		# Get all member groups
		$sth_grp_tree->bind_param (":id", $group_id) or confess;
		$sth_grp_tree->execute() or confess;
		while (@rowdata = $sth_grp_tree->fetchrow ()) {
			if (! exists $hostgroup_list->{$rowdata[0]}) {
				push @hostgroups, $rowdata[0];
			}
		}
	}

	return $hostgroup_list;
} # }}}

#
# Get the hostgroup tree below the given group represented in a hash
#
# XXX TODO doc
sub get_hostgroup_tree_below_group ($) { # get_hostgroup_tree_below_group (hostgroup_id) : \%hostgroup_tree {{{
	my $self = shift;

	my $hostgroup_id = shift;

	my $hostgroup_tree = {};

	return undef if (ref ($self) ne __PACKAGE__);

	# In case of no or non-numeric value, there's no chance for us
	return undef if (! $hostgroup_id || $hostgroup_id =~ m/[^0-9]/);

	# Prepare hostgroup tree query
	my $sth_grp_tree = $self->{db_h}->prepare ("
		SELECT	member_group_id
		FROM	hostgroup_tree
		WHERE	super_group_id = :id") or confess ();

	my $sth_grp_name = $self->{db_h}->prepare ("
		SELECT	name
		FROM	hostgroup
		WHERE	hostgroup_id = :id") or confess ();

	# Walk down hostgroup tree and remeber visited hostgroups (beware of cycles...)
	my $hostgroups_visited;

	$sth_grp_name->bind_param (":id", $hostgroup_id);
	$sth_grp_name->execute () or confess;
	my @rowdata = $sth_grp_name->fetchrow ();

	$hostgroup_tree = {
		id => $hostgroup_id,
		name => $rowdata[0],
		members => {},
	};
	$hostgroups_visited->{$hostgroup_id} = 1;

	$sth_grp_tree->bind_param (":id", $hostgroup_id) or confess;
	$sth_grp_tree->execute() or confess;

	# Recursion is the key...
	# ... but as we want to push the $sth_grp_tree handle into the recursion
	# we have to save all data here and loop then
	my $rows = $sth_grp_tree->fetchall_arrayref ();
	foreach my $row (@{$rows}) {
		$hostgroup_tree->{members}->{$row->[0]} = {};

		$self->_get_hostgroup_tree_below_group_worker (
			$row->[0],
			$hostgroups_visited,
			$hostgroup_tree->{members}->{$row->[0]},
			$sth_grp_tree,
			$sth_grp_name);
	}

	return $hostgroup_tree;
} # }}}

sub _get_hostgroup_tree_below_group_worker ($$$$$) { # _get_hostgroup_tree_below_group_worker (hostgroup, \%hostgroups_visited, \%hostgroup_tree_subhash, $sth_grp_tree, $sth_grp_name) :  {{{
	my $self = shift;

	my $hostgroup_id = shift;
	my $hostgroups_visited = shift;
	my $hostgroup_tree_subhash = shift;
	my $sth_grp_tree = shift;
	my $sth_grp_name = shift;

	if (! $hostgroup_id ||
	    ! $hostgroups_visited || ref ($hostgroups_visited) ne 'HASH' ||
	    ! $hostgroup_tree_subhash || ref ($hostgroup_tree_subhash) ne 'HASH' ||
	    ! $sth_grp_tree || ! $sth_grp_name ){
		return undef;
	}

	# Setup subhash
	$hostgroup_tree_subhash->{id} = $hostgroup_id;

	$sth_grp_name->bind_param (":id", $hostgroup_id) or confess ();
	$sth_grp_name->execute () or confess ();
	my @rowdata = $sth_grp_name->fetchrow ();
	$hostgroup_tree_subhash->{name} = $rowdata[0];

	$hostgroups_visited->{$hostgroup_id} = 1;

	$sth_grp_tree->bind_param (":id", $hostgroup_id) or confess;
	$sth_grp_tree->execute() or confess;

	# Recursion is the key...
	# ... but as we want to push the $sth_grp_tree handle into the recursion
	# we have to save all data here and loop then
	my $rows = $sth_grp_tree->fetchall_arrayref ();
	foreach my $row (@{$rows}) {
		if (! defined $hostgroups_visited->{$row->[0]}) {
			$hostgroup_tree_subhash->{members}->{$row->[0]} = {};

			$self->_get_hostgroup_tree_below_group_worker (
				$row->[0],
				$hostgroups_visited,
				$hostgroup_tree_subhash->{members}->{$row->[0]},
				$sth_grp_tree,
				$sth_grp_name);
		}
	}
} # }}}

################################################################################
#			Host / Hostgroup ACL (queris)			       #
################################################################################

#
# Check if $user has a specific right at $host.
sub _user_has_right_on_host ($$$) { # _user_has_right_on_host (uid, host_id, right) : 0/1 {{{
	my $self = shift;

	my $uid = shift;
	my $host_id = shift;
	my $right = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	# Do we know about the requested right?
	if (! $right =~ m/^(allow_boot|read_config|write_config)$/) {
		return undef;
	}

	# No (valid) host, no access
	return undef if (! $self->is_valid_host ($host_id));

	# No user, no access
	return undef if (! defined $uid);

	#
	# Check for ACL entry explicit for this host
	my $sth_acl = $self->{db_h}->prepare ("
		SELECT	host_id
		FROM	host_acl
		WHERE		host_id = :host_id
			AND	uid = :uid
			AND	$right = 't'");
	$sth_acl->bind_param (":host_id", $host_id);
	$sth_acl->bind_param (":uid", $uid);
	$sth_acl->execute () or confess;

	# If there is an entry, you win.
	if ($sth_acl->rows () > 0) {
		return $true;
	}

	#
	# No match, check hostgroups
	my $sth_grp = $self->{db_h}->prepare ("
		SELECT	hostgroup_id
		FROM	hostgroup_host
		WHERE		host_id = $host_id");
	$sth_grp->execute () or confess;

	#
	# If this host isn't in any hostgroups, game over
	return $false if ($sth_grp->rows () == 0);

	#
	# Check all hostgroups where this host is in and walk hostgroup_tree
	# upwards until a match was found or no other hostgroup exists
	my @hostgroups;
	while (my @rowdata = $sth_grp->fetchrow ()) {
		push @hostgroups, $rowdata[0];
	}
	return $self->_user_has_right_on_hostgroup ($uid, $right, \@hostgroups);

	# Last but not least...
	return $false;
} # }}}

# Functions to be called from outside
sub user_can_boot_host ($$) { # user_can_boot_host (uid, host_id) : 0/1 {{{
	my $self = shift;

	my $uid = shift;
	my $host_id = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_user_has_right_on_host ($uid, $host_id, "allow_boot");
} # }}}

sub user_can_read_host_config ($$) { # user_can_read_host_config (uid, host_id) : 0/1 # {{{
	my $self = shift;

	my $uid = shift;
	my $host_id = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_user_has_right_on_host ($uid, $host_id, "read_config");
} # }}}

sub user_can_write_host_config ($$) { # user_can_write_host_config (uid, host_id) : 0/1  {{{
	my $self = shift;

	my $uid = shift;
	my $host_id = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_user_has_right_on_host ($uid, $host_id, "write_config");
} # }}}


#
# Query DB if $user has right $right at given hostgroup(s)
sub _user_has_right_on_hostgroup ($$$) { # _user_has_right_on_hostgroup (uid, right, $hostgroup or \@hostgroup) : 0/1 {{{
	my $self = shift;

	my $uid = shift;
	my $right = shift;
	my $hostgroup = shift;


	# This piece of magic allow passing of single argument or
	# a reference to an array, so multiple hostgroups could be
	# checked at once
	my @hostgroups;
	if (ref ($hostgroup) eq 'ARRAY') {
		@hostgroups = @{$hostgroup};
	} else {
		@hostgroups = ( $hostgroup );
	}

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	# Do we know about the requested right?
	if (! $right =~ m/^(allow_boot|read_config|write_config)$/) {
		return undef;
	}

	# No user, no access
	return undef if (! defined $uid);

	# No hostgroups, no access
	return undef if (! @hostgroups);


	# Preprare hostgroup ACL query
	my $sth_acl = $self->{db_h}->prepare ("
		SELECT	hostgroup_id
		FROM	hostgroup_acl
		WHERE		hostgroup_id = :id
			AND	uid = :uid
			AND	$right = 't'");

	# Prepare hostgroup tree query
	my $sth_grp = $self->{db_h}->prepare ("
		SELECT	super_group_id
		FROM	hostgroup_tree
		WHERE	member_group_id = :id");

	# Walk up hostgroup tree and remeber visited hostgroups
	my %hostgroups_visited;
	my @rowdata;
	while (@hostgroups) {
		my $group_id = shift @hostgroups;

		# Check for ACL of $group_id
		$sth_acl->bind_param (":id", $group_id) or confess ();
		$sth_acl->bind_param (":uid", $uid) or confess ();
		$sth_acl->execute() or confess;
		if ($sth_acl->rows() > 0) {
			return $true;
		}

		$hostgroups_visited{$group_id} = 1;

		$sth_grp->bind_param (":id", $group_id) or confess;
		$sth_grp->execute() or confess;
		while (@rowdata = $sth_grp->fetchrow ()) {
			if (! defined $hostgroups_visited{$rowdata[0]}) {
				push @hostgroups, $rowdata[0];
			}
		}
	}

	# Nothing found, no luck
	return $false;
} # }}}

# Functions to be called from outside
sub user_can_boot_hostgroup ($$) { # user_can_boot_hostgroup (uid, $hostgroup | \@hostgroups) : 0/1 {{{
	my $self = shift;

	my $uid = shift;
	my $hostgroup = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_user_has_right_on_hostgroup ($uid, "allow_boot", $hostgroup);
} # }}}

sub user_can_read_hostgroup_config ($$) { # user_can_read_hostgroup_config (uid, $hostgroup | \@hostgroups) : 0/1 {{{
	my $self = shift;

	my $uid = shift;
	my $hostgroup = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_user_has_right_on_hostgroup ($uid, "read_config", $hostgroup);
} # }}}

sub user_can_write_hostgroup_config ($$) { # user_can_write_hostgroup_config (uid, $hostgroup | \@hostgroups) : 0/1 {{{
	my $self = shift;

	my $uid = shift;
	my $hostgroup = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_user_has_right_on_hostgroup ($uid, "write_config", $hostgroup);
} # }}}

#
# Get all hosts where $user has $right on
#
# The return value is a reference to a hash including all hosts, the given user
# has the given right on, with being the host_id the hash-key and the hostname
# being the value.
sub _hosts_user_has_right_on ($$) { # _hosts_user_has_right_on (uid, right) : \%hosts {{{
	my $self = shift;

	my $uid = shift;
	my $right = shift;

	my $hosts = {};

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	# Do we know about the requested right?
	if (! $right =~ m/^(allow_boot|read_config|write_config)$/) {
		return undef;
	}

	# No user, no hosts
	return undef if (! defined $uid);

	#
	# Check for ACL entry explicit for this host
	my $sth_acl = $self->{db_h}->prepare ("
		SELECT	host.host_id, name, boot_host, shutdown_host
		FROM	host_acl, host
		WHERE		uid = :uid
			AND	$right = 't'
			AND	host_acl.host_id = host.host_id");
	$sth_acl->bind_param (":uid", $uid);
	$sth_acl->execute () or confess;

	# Put all hosts as keys into the hosts hash
	while (my (@rowdata) = $sth_acl->fetchrow()) {
		$hosts->{$rowdata[0]} = {
			id => $rowdata[0],
			name => $rowdata[1],
			boot_host => $rowdata[2],
			shutdown_host => $rowdata[3]
		};
	}

	#
	# Check for rights on hostgroups and add the hosts of these groups accordingly
	my $hostgroups = $self->_hostgroups_user_has_right_on ($uid, $right);

	foreach my $hostgroup (keys %{$hostgroups}) {
		my $host_loop_hash = $self->get_hosts_in_hostgroup ($hostgroup);

		foreach my $host_loop (keys %{$host_loop_hash}) {
			$hosts->{$host_loop} = $host_loop_hash->{$host_loop};
		}
	}

	return $hosts;
} # }}}

sub hosts_user_can_boot ($) { # hosts_user_can_boot (uid) : \%hosts {{{
	my $self = shift;

	my $uid = shift;;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_hosts_user_has_right_on ($uid, "allow_boot");
} # }}}

sub hosts_user_can_read_config ($) { # hosts_user_can_read_config (uid) : \%hosts {{{
	my $self = shift;

	my $uid = shift;;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_hosts_user_has_right_on ($uid, "read_config");
} # }}}

sub hosts_user_can_write_config ($) { # hosts_user_can_write_config (uid) : \%hosts {{{
	my $self = shift;

	my $uid = shift;;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_hosts_user_has_right_on ($uid, "write_config");
} # }}}



sub _hosts_of_hostgroup_user_has_right_on ($$) { # _hosts_user_has_right_on (hostgroup_id, uid, right) : \%hosts {{{
	my $self = shift;

	my $hostgroup_id = shift;
	my $uid = shift;
	my $right = shift;


	my $hosts = {};

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	if (! defined $hostgroup_id || $hostgroup_id =~ m/[^0-9]/) {
		return undef;
	}

	# Do we know about the requested right?
	if (! $right =~ m/^(allow_boot|read_config|write_config)$/) {
		return undef;
	}

	# No user, no hosts
	return undef if (! defined $uid);

	#
	# If user has $right on the entire hostgroup or a super_group, just return all the host of it.
	if ($self->_user_has_right_on_hostgroup ($uid, $right, $hostgroup_id)) {
		return $self->get_hosts_in_hostgroup ($hostgroup_id);
	}


	#
	# Check for ACL entry explicit for this host
	my $sth_acl = $self->{db_h}->prepare ("
		SELECT	DISTINCT host_id, name
		FROM	host
		WHERE	host_id in (

			SELECT	host_acl.host_id
			FROM	hostgroup_host, host_acl
			WHERE		hostgroup_host.hostgroup_id = :hg_id
				AND	hostgroup_host.host_id = host_acl.host_id
				AND	uid = :uid
				AND	$right = 't'

			UNION

			SELECT	host_id
			FROM	hostgroup_host, hostgroup_acl
			WHERE	hostgroup_acl.hostgroup_id = :hg_id
				AND	uid = :uid
				AND	$right = 't'
				AND	hostgroup_acl.hostgroup_id = hostgroup_host.hostgroup_id
			)");
	$sth_acl->bind_param (":hg_id", $hostgroup_id);
	$sth_acl->bind_param (":uid", $uid);
	$sth_acl->execute () or confess;

	# Put all hosts as keys into the hosts hash
	while (my (@rowdata) = $sth_acl->fetchrow()) {
		$hosts->{$rowdata[0]} = $rowdata[1];
	}

	return $hosts;
} # }}}

#
# Get all hostgroups where $user has $right on
#
# The return value is a reference to a hash including all hostgroups, the given
# user has the given right on, with the hostgroup_id being the hash-key and the
# hostgroup name being the value
#
sub _hostgroups_user_has_right_on ($$) { # _hostgroups_user_has_right_on (uid, right) : \@hostsgroups {{{
	my $self = shift;

	my $uid = shift;
	my $right = shift;

	my $hostgroups = {};

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	# Do we know about the requested right?
	if (! $right =~ m/^(allow_boot|read_config|write_config)$/) {
		return undef;
	}

	# No user, no hosts
	return undef if (! defined $uid);

	#
	# Check for ACL entry explicit for this host
	my $sth_acl = $self->{db_h}->prepare ("
		SELECT	DISTINCT hostgroup.hostgroup_id, name
		FROM	hostgroup_acl, hostgroup
		WHERE		uid = :uid
			AND	$right = 't'
			AND	hostgroup_acl.hostgroup_id = hostgroup.hostgroup_id");
	$sth_acl->bind_param (":uid", $uid);
	$sth_acl->execute () or confess;

	# Put all hosts as keys into the hosts hash
	while (my (@rowdata) = $sth_acl->fetchrow()) {
		$hostgroups->{$rowdata[0]} = {
			id => $rowdata[0],
			name => $rowdata[1],
			boot_host => $rowdata[2],
			shutdonw_host => $rowdata[3],
		};

		my $below_groups = $self->get_hostgroups_below_group ($rowdata[0]);
		foreach my $below_group_id (keys %{$below_groups}) {
			$hostgroups->{$below_group_id} = $below_groups->{$below_group_id};
		}
	}

	return $hostgroups;
} # }}}

sub hostgroups_user_can_boot ($) { # hostgroups_user_can_boot (uid) : \%hostgroups {{{
	my $self = shift;

	my $uid = shift;;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_hostgroups_user_has_right_on ($uid, "allow_boot");
} # }}}

sub hostgroups_user_can_read_config ($) { # hostgroups_user_can_read_config (uid) : \%hostgroups {{{
	my $self = shift;

	my $uid = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_hostgroups_user_has_right_on ($uid, "read_config");
} # }}}

sub hostgroups_user_can_write_config ($) { # hostgroups_user_can_write_config (uid) : \%hostgroups {{{
	my $self = shift;

	my $uid = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return $self->_hostgroups_user_has_right_on ($uid, "write_config");
} # }}}

################################################################################
#			Host / Hostgroup ACL (updates)			       #
################################################################################

sub give_user_rights_on_host ($$$) { # give_user_rights_on_host (uid, host_id, \@right_list) : 0/1 {{{
	my $self = shift;

	my $uid = shift;
	my $host_id = shift;
	my $right_list = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	if (! defined $uid || $uid =~ m/^[^-[:alnum:]]+$/) {
		die "Invalid user id \"$uid\".\n";
	}
	if (! $self->is_valid_host ($host_id)) {
		die "Invalid host id \"$host_id\".\n";
	}
	if (ref ($right_list) ne 'ARRAY' || scalar (@{$right_list}) != 3) {
		die "Invalid right list.\n";
	}

	my $rights_boolean = [];
	foreach my $right_elem (@{$right_list}) {
		push @{$rights_boolean}, ($right_elem) ? 't' : 'f';
	}

	# Preprare host ACL query
	my $sth_query = $self->{db_h}->prepare ("
		SELECT	allow_boot, read_config, write_config
		FROM	host_acl
		WHERE		host_id = :host_id
			AND	uid = :uid
	") or die;
	$sth_query->bind_param (":uid", $uid) or die;
	$sth_query->bind_param (":host_id", $host_id) or die;
	$sth_query->execute () or die;

	# Check for existing rights in DB
	my @db_rights = $sth_query->fetchrow ();

	# Found right entry, update it.
	if (@db_rights) {
		my $sth_update = $self->{db_h}->prepare ("
			UPDATE	host_acl
			SET	allow_boot = :boot,
				read_config = :read,
				write_config = :write
			WHERE		host_id = :host_id
				AND	uid = :uid
		") or die;

		$sth_update->bind_param (":uid", $uid) or die;
		$sth_update->bind_param (":host_id", $host_id) or die;

		for (my $n = 0; $n <= 2; $n++) {
			if (defined $right_list->[$n]) {
				$db_rights[$n] = $rights_boolean->[$n];
			} else {
				$db_rights[$n] = ($db_rights[$n]) ? 't' : 'f';
			}
		}

		$sth_update->bind_param (":boot", $rights_boolean->[0]) or die;
		$sth_update->bind_param (":read", $rights_boolean->[1]) or die;
		$sth_update->bind_param (":write", $rights_boolean->[2]) or die;

		$sth_update->execute () or die;
	}

	# No entry there, insert one
	else {
		my $sth_insert = $self->{db_h}->prepare ("
			INSERT INTO	host_acl
					(host_id, uid, allow_boot, read_config, write_config)
				values  (:host_id, :uid, :boot, :read, :write)
		") or die;

		$sth_insert->bind_param (":uid", $uid) or die;
		$sth_insert->bind_param (":host_id", $host_id) or die;
		$sth_insert->bind_param (":boot", $rights_boolean->[0]) or die;
		$sth_insert->bind_param (":read", $rights_boolean->[1]) or die;
		$sth_insert->bind_param (":write", $rights_boolean->[2]) or die;

		$sth_insert->execute () or die;
	}
} # }}}

sub give_user_rights_on_hostgroup ($$$) { # give_user_rights_on_hostgroup (uid, hostgroup_id, \@right_list) : 0/1 {{{
	my $self = shift;

	my $uid = shift;
	my $hg_id = shift;
	my $right_list = shift;

	return undef if (ref ($self) ne __PACKAGE__);

	if (! defined $uid || $uid =~ m/^[^-[:alnum:]]+$/) {
		die "Invalid uid.\n";
	}
	if (ref ($hg_id) || $hg_id =~ m/^[^[:digit:]]+$/) {
		die "Invalid hostgroup id.\n";
	}
	if (ref ($right_list) ne 'ARRAY' || scalar (@{$right_list}) != 3) {
		die "Invalid right list\n";
	}

	my $rights_boolean = [];
	foreach my $right_elem (@{$right_list}) {
		push @{$rights_boolean}, ($right_elem) ? 't' : 'f';
	}

	# Preprare hostgroup ACL query
	my $sth_query = $self->{db_h}->prepare ("
		SELECT	allow_boot, read_config, write_config
		FROM	hostgroup_acl
		WHERE		hostgroup_id = :hg_id
			AND	uid = :uid
	") or die;
	$sth_query->bind_param (":uid", $uid) or die;
	$sth_query->bind_param (":hg_id", $hg_id) or die;
	$sth_query->execute () or die;

	# Check for existing rights in DB
	my @db_rights = $sth_query->fetchrow ();

	# Found right entry, update it.
	if (@db_rights) {
		my $sth_update = $self->{db_h}->prepare ("
			UPDATE	hostgroup_acl
			SET	allow_boot = :boot,
				read_config = :read,
				write_config = :write
			WHERE		hostgroup_id = :hg_id
				AND	uid = :uid
		") or die;
		$sth_update->bind_param (":uid", $uid) or die;
		$sth_update->bind_param (":hg_id", $hg_id) or die;

		for (my $n = 0; $n <= 2; $n++) {
			if (defined $right_list->[$n]) {
				$db_rights[$n] = $rights_boolean->[$n];
			} else {
				$db_rights[$n] = ($db_rights[$n]) ? 't' : 'f';
			}
		}
		$sth_update->bind_param (":boot", $rights_boolean->[0]) or die;
		$sth_update->bind_param (":read", $rights_boolean->[1]) or die;
		$sth_update->bind_param (":write", $rights_boolean->[2]) or die;

		$sth_update->execute () or die;
	}

	# No entry there, insert one
	else {
		my $sth_insert = $self->{db_h}->prepare ("
			INSERT INTO	hostgroup_acl
					(hostgroup_id, uid, allow_boot, read_config, write_config)
				values  (:hg_id, :uid, :boot, :read, :write)
		") or die;

		$sth_insert->bind_param (":uid", $uid) or die;
		$sth_insert->bind_param (":hg_id", $hg_id) or die;
		$sth_insert->bind_param (":boot", $rights_boolean->[0]) or die;
		$sth_insert->bind_param (":read", $rights_boolean->[1]) or die;
		$sth_insert->bind_param (":write", $rights_boolean->[2]) or die;

		$sth_insert->execute () or die;
	}

	return 1;
} # }}}

################################################################################
#			    Agent / network stuff			       #
################################################################################

#
# Get a list with all Agent in given network
sub get_agents_for_network ($) { # get_agents_for_network (network_id) : [ agent1, ... ] {{{
	my $self = shift;

	my $network_id = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);
	return undef if (! defined $network_id);

	my $sth = $self->{db_h}->prepare ("
		SELECT	agent_id
		FROM	agent_network
		WHERE	net_id = :id") or confess;
	$sth->bind_param (":id", $network_id) or confess;
	$sth->execute () or confess;

	my @agent_list;
	while (my @rowdata = $sth->fetchrow ()) {
		push @agent_list, $rowdata[0];
	}

	# If the caller want's a list, he should ask for one
	if (wantarray) {
		return @agent_list;
	} else {
		# XXX
		return \@agent_list;
	}
} # }}}

#
# Check if the given agent_id is valid
sub is_valid_agent_id ($) { # is_valid_agent_id (agent_id) : 0/1 {{{
	my $self = shift;

	my $agent_id = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	# No input?
	return undef if (! defined $agent_id || ref ($agent_id));

	my $sth = $self->{db_h}->prepare ("SELECT agent_id from agent where agent_id = :id");
	$sth->bind_param (":id", $agent_id) or confess;
	$sth->execute () or confess;

	return ($sth->rows () == 1);
} # }}}

#
# Get the IP address of the given agent (if set)
sub get_agent_ip ($) { # get_agent_ip (agent_id) : IP {{{
	my $self = shift;

	my $agent_id = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	return undef if (! $self->is_valid_agent_id ($agent_id));

	my $sth = $self->{db_h}->prepare ("
		SELECT	ip_addr
		FROM	agent
		WHERE	agent_id = :id") or confess;
	$sth->bind_param (":id", $agent_id) or confess;
	$sth->execute () or confess;

	my @rowdata = $sth->fetchrow ();

	return $rowdata[0];
} # }}}



################################################################################
#			Config set / times related			       #
################################################################################

sub get_times_of_host ($) { # get_times_of_host (host_id) : \%times->{day}->{time} {{{
	my $self = shift;

	my $host_id = shift;

	# Called on blessed instance?
	return undef if (ref ($self) ne __PACKAGE__);

	if (! $self->is_valid_host ($host_id)) {
		return undef;
	}

	my $sth = $self->{db_h}->prepare ("
		SELECT	day, time, action
		FROM	host h,
			times t
		WHERE		h.host_id = :host_id
			AND	h.csid = t.csid");

	$sth->bind_param (":host_id", $host_id) or confess;
	$sth->execute() or confess;

	return $sth->fetchall_hashref (['day', 'time']);
} # }}}

sub get_hosts_to_start_within_next_window ($) { # get_hosts_to_start_within_next_window (time_window) : \@hosts {{{
	my $self = shift;

	my $window_width = shift;

	# Called on blessed instance?
	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_hosts_to_start_within_next_window(): Has to be called on bless'ed object.\n";
	}

	if (! $window_width || ! ($window_width =~ m/^[0-5][0-9]:[0-5][0-9]$/)) {
		confess __PACKAGE__ . "->get_hosts_to_start_within_next_window(): No or invalid 'window_width' parameter.\n";
	}
	my @window_width_list = split (':', $window_width);
	my $window_width_minutes = $window_width_list[0] * 60 + $window_width_list[1];

	my @localtime = localtime (time);
	my $dow = $localtime[6];
	my $day = WakeUpManager::Common::Utils::dow_to_day ($dow);
	if (! $day) {
		return undef;
	}

	my $sth;
	if ($localtime[2] * 60 + $localtime[1] + $window_width_minutes <= 24 * 60) {
		$sth = $self->{db_h}->prepare ("
			SELECT  DISTINCT host_id, name
			FROM    host h,
				times t
			WHERE           t.action = 'boot'
				AND	t.day = :day
				AND     t.time::interval >= now()::time
				AND     t.time::interval <= now()::time + :window_width::interval
				AND     h.csid = t.csid
				AND	h.boot_host = 't'
			ORDER BY h.host_id
		");

		$sth->bind_param (":day", $day) or confess ();
		$sth->bind_param (":window_width", $window_width) or confess ();

	} else {
		my $window_width_day1 = 24 * 60 - ($localtime[2] * 60 + $localtime[1]);
		my $window_width_day2_minutes = $window_width_minutes - $window_width_day1;
		my $window_width_day2_minutes_hour_part;
		{
			use integer;
			$window_width_day2_minutes_hour_part = $window_width_day2_minutes / 60
		};
		my $window_width_day2 = "$window_width_day2_minutes_hour_part:" . ($window_width_day2_minutes - ($window_width_day2_minutes_hour_part * 60));

		my $day2 = WakeUpManager::Common::Utils::dow_to_day (($dow + 1) % 7);
		if (! $day2) {
			return undef;
		}

		$sth = $self->{db_h}->prepare ("
			SELECT  DISTINCT host_id, name
			FROM    host h,
				times t
			WHERE           t.action = 'boot'
				AND	(
						t.day = :day
					AND     t.time >= now()::time
					AND     t.time <= now()::time + :window_width_day1::interval
					)
				OR	(
						t.day = :day2
					AND     t.time >= '00:00:00'::time
					AND     t.time <= :window_width_day2

					)
				AND     h.csid = t.csid
				AND	h.boot_host = 't'
			ORDER BY h.host_id
		");
		$sth->bind_param (":day", $day) or confess ();
		$sth->bind_param (":day2", $day2) or confess ();
		$sth->bind_param (":window_width_day1", $window_width_day1) or confess ();
		$sth->bind_param (":window_width_day2", $window_width_day2) or confess ();
	}

	$sth->execute () or confess ();

	return $sth->fetchall_arrayref ();
} # }}}



sub get_hosts_to_start_within_next_window_admin ($) { # get_hosts_to_start_within_next_window_admin (time_window) : \@hosts {{{
	my $self = shift;

	my $window_width = shift;

	# Called on blessed instance?
	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_hosts_to_start_within_next_window_admin(): Has to be called on bless'ed object.\n";
	}

	if (! $window_width || ! ($window_width =~ m/^[0-5][0-9]:[0-5][0-9]$/)) {
		confess __PACKAGE__ . "->get_hosts_to_start_within_next_window_admin(): No or invalid 'window_width' parameter.\n";
	}
	my @window_width_list = split (':', $window_width);
	my $window_width_minutes = $window_width_list[0] * 60 + $window_width_list[1];

	my @localtime = localtime (time);
	my $dow = $localtime[6];
	my $day = WakeUpManager::Common::Utils::dow_to_day ($dow);
	if (! $day) {
		return undef;
	}

	my $sth;
	if ($localtime[2] * 60 + $localtime[1] + $window_width_minutes <= 24 * 60) {
		$sth = $self->{db_h}->prepare ("
			SELECT  DISTINCT c.csid
			FROM    times t,
				config_set c
			WHERE           t.action = 'boot'
				AND	t.day = :day
				AND     t.time::interval >= now()::time
				AND     t.time::interval <= now()::time + :window_width::interval
				AND     t.csid = c.csid
				AND	c.administrative = 't'
		");

		$sth->bind_param (":day", $day) or confess ();
		$sth->bind_param (":window_width", $window_width) or confess ();

	} else {
		my $window_width_day1 = 24 * 60 - ($localtime[2] * 60 + $localtime[1]);
		my $window_width_day2_minutes = $window_width_minutes - $window_width_day1;
		my $window_width_day2_minutes_hour_part;
		{
			use integer;
			$window_width_day2_minutes_hour_part = $window_width_day2_minutes / 60
		};
		my $window_width_day2 = "$window_width_day2_minutes_hour_part:" . ($window_width_day2_minutes - ($window_width_day2_minutes_hour_part * 60));

		my $day2 = WakeUpManager::Common::Utils::dow_to_day (($dow + 1) % 7);
		if (! $day2) {
			return undef;
		}

		$sth = $self->{db_h}->prepare ("
			SELECT  DISTINCT c.csid
			FROM    times t,
				config_set c
			WHERE           t.action = 'boot'
				AND	(
						t.day = :day
					AND     t.time >= now()::time
					AND     t.time <= now()::time + :window_width_day1::interval
					)
				OR	(
						t.day = :day2
					AND     t.time >= '00:00:00'::time
					AND     t.time <= :window_width_day2

					)
				AND     t.csid = c.csid
				AND	c.administrative = 't'
		");
		$sth->bind_param (":day", $day) or confess ();
		$sth->bind_param (":day2", $day2) or confess ();
		$sth->bind_param (":window_width_day1", $window_width_day1) or confess ();
		$sth->bind_param (":window_width_day2", $window_width_day2) or confess ();
	}

	$sth->execute () or confess ();

	my @config_set_list;
	while (my @row = $sth->fetchrow ()) {
		push @config_set_list, $row[0];
	}

	#
	# Get all hosts to be booted via admin config set
	my $hosts;
	my $hostgroups = $self->get_hostgroups_using_admin_config_set (\@config_set_list);
	foreach my $hg_id (@{$hostgroups}) {
		my $hg_hosts_hash = $self->get_hosts_in_hostgroup ($hg_id);

		foreach my $host_id (keys %{$hg_hosts_hash}) {
			$hosts->{$host_id} = $hg_hosts_hash->{$host_id}->{name};
		}
	}

	#
	# Prepare output list
	my @host_list;
	foreach my $key (sort {$a <=> $b } keys %{$hosts}) {
		push @host_list, [ $key, $hosts->{$key} ];
	}

	return \@host_list;
} # }}}

sub get_hostgroups_using_admin_config_set ($) { # get_hostgroups_using_admin_config_set (\@config_set_list) : \@hosts # {{{
	my $self = shift;

	my $config_set_list = shift;

	# Called on blessed instance?
	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_hosts_using_config_set(): Has to be called on bless'ed object.\n";
	}

	if (ref ($config_set_list) ne 'ARRAY') {
		confess __PACKAGE__ . "->get_hosts_using_config_set(): No or invalid config set id.\n";
	}

	my $config_set_hash = {};
	foreach my $csid (@{$config_set_list}) {
		$config_set_hash->{$csid} = 1;
	}

	#
	# Get all hosts to be booted by admin config set
	my $hg_ALL_id = $self->get_hostgroup_id ('ALL');
	if (! $hg_ALL_id) {
		confess __PACKAGE__ . "->get_hosts_using_config_set(): Hostgroup 'ALL' does not exist!\n";
	}

	my $hg_tree = $self->get_hostgroup_tree_below_group ($hg_ALL_id);
	if (! $hg_tree) {
		confess __PACKAGE__ . "->get_hosts_using_config_set(): Could not get hostgroup tree.\n";
	}

	my $sth = $self->{db_h}->prepare ("
		SELECT	admin_csid
		FROM	hostgroup
		WHERE	hostgroup_id = :hg_id
	") or die;

	my $hostgroups = {};
	my $active = 0;

	# Check 'ALL' hostgroup (tree root)
	my $hg_id = $hg_tree->{id};
	if (! $hg_id) {
		confess __PACKAGE__ . "->get_hosts_using_admin_config_set(): Invalid hash. No 'id' found.\n";
	}
	$sth->bind_param (":hg_id", $hg_id);
	$sth->execute ();
	my @row = $sth->fetchrow ();
	if (@row && $row[0] && $config_set_hash->{$row[0]}) {
		$active = 1;
		$hostgroups->{$hg_id} = 1;
	}

	$self->_get_hostgroups_using_admin_config_set_worker ($config_set_hash, $hg_tree->{members}, $sth, $hostgroups, $active);

	my @hg_list = keys %{$hostgroups};

	return \@hg_list;
} # }}}

sub _get_hostgroups_using_admin_config_set_worker ($$$$$) { # get_hostgroupss_using_admin_config_set ($config_set_hash, hg_tree, sth, \%hosts, active) : {{{
	my $self = shift;

	my $config_set_hash = shift;
	my $hostgroup_tree_subhash = shift;
	my $sth = shift;
	my $hostgroup_hash = shift;
	my $active = shift;

	# Called on blessed instance?
	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->get_hosts_using_config_set(): Has to be called on bless'ed object.\n";
	}

	if (! $config_set_hash || ref ($config_set_hash) ne 'HASH' ||
	    ! $hostgroup_tree_subhash || ref ($hostgroup_tree_subhash) ne 'HASH' ||
	    ! $sth ||
	    ! $hostgroup_hash || ref ($hostgroup_hash) ne 'HASH') {
		return undef;
	}

	foreach my $key (keys %{$hostgroup_tree_subhash}) {
		$sth->bind_param (":hg_id", $key) or die;
		$sth->execute () or die;

		my @row = $sth->fetchrow ();
		if (@row && $row[0]) {
			if ($config_set_hash->{$row[0]}) {
				$active = 1;
			} else {
				$active = 0;
			}
		}

		if ($active) {
			$hostgroup_hash->{$key} = 1;

		}

		if ($hostgroup_tree_subhash->{$key}->{members}) {
			$self->_get_hostgroups_using_admin_config_set_worker (
				$config_set_hash,
				$hostgroup_tree_subhash->{$key}->{members},
				$sth,
				$hostgroup_hash,
				$active);
		}
	}
} # }}}


sub update_timetable_of_host ($$) { # update_timetable_of_host (host_id, \%times_list) {{{
	my $self = shift;

	my $host_id = shift;
	my $times_list = shift;

	if (ref ($self) ne __PACKAGE__) {
		confess __PACKAGE__ . "->update_timetable_of_host(): Has to be called on bless'ed object.\n";
	}

	return -1 if (! $self->is_valid_host ($host_id));
	return -2 if (ref ($times_list) ne 'HASH');

	#
	# Start TRANSACTION here as we may do harmful things
	$self->{db_h}->begin_work ();

	my $sth_cs = $self->{db_h}->prepare ("
		SELECT
			host_id, h.csid
		FROM	host h,
			config_set c
		WHERE		h.host_id = :host_id
			AND	h.csid = c.csid
			AND	c.preset = 'f'
			AND	c.administrative = 'f'
	");
	$sth_cs->bind_param (":host_id", $host_id);
	$sth_cs->execute ();

	my $row_count = $sth_cs->rows ();
	my @row = $sth_cs->fetchrow ();
	my $csid = $row[1];

	# If the result only contains one row, this has to be the host...
	# ...but who knows... better check it twice.
	if ($row_count == 1 && $row[0] == $host_id) {

		# Delete all entries from the times table
		my $sth_drop_times = $self->{db_h}->prepare ("
			DELETE FROM	times
			WHERE		csid = :csid
		");
		$sth_drop_times->bind_param (":csid", $csid);
		$sth_drop_times->execute ();
	} else {
		# XXX FIXME XXX
		#
		# Why ever does this not work when using parameters...
		my $sth_cs_new = $self->{db_h}->prepare ("
			INSERT INTO config_set
					(name)
			VALUES		('CS for #$host_id')
		") or die;
#		$sth_cs_new->bind_param (":name", "CS for #$host_id");
		$sth_cs_new->execute ();
		@row = $sth_cs_new->fetchrow ();

		if (! $row[0]) {
			$self->{db_h}->rollback ();
			return -3;
		}

		$csid = $row[0];
	}

	my $sth_insert_time = $self->{db_h}->prepare ("
		INSERT INTO	times
			(csid, day, time, action)
		VALUES	(:csid, :day, :time, :action)
	");
	$sth_insert_time->bind_param (":csid", $csid);

	for (my $n = 1; $n <= 7; $n++) {
		my $day_name = dow_to_day ($n);
		my $day_list = $times_list->{$day_name};

		if ($day_list && scalar (@{$day_list})) {
			$sth_insert_time->bind_param (":day", $day_name);

			foreach my $item (@{$day_list}) {
				foreach my $type (qw(boot shutdown)) {
					my $valid = 0;

					my $value = $item->{$type};
					if ($value =~ m/^[0-2]?[0-9]:[0-5][0-9]:[0-2]?[0-9]$/) {
						# Strip seconds
						$value =~ s/:[0-9]{2}$//;
					}
					if ($value =~ m/^([0-2]?[0-9]):([0-5]?[0-9])$/) {
						if ($1 >= 0 && $1 < 24 && $2 >= 0 && $2 <= 59) {
							$valid = 1;
						}
					}

					if (! $valid) {
						$self->{db_h}->rollback ();
						return -4;
					}

					# Insert entry
					$sth_insert_time->bind_param (":time", $item->{$type});
					$sth_insert_time->bind_param (":action", $type);
					$sth_insert_time->execute ();
				}
			}
		}
	}

	my $sth_update_host = $self->{db_h}->prepare ("
		UPDATE	host
		SET	csid = :csid
		WHERE	host_id = :host_id
	");
	$sth_update_host->bind_param (":csid", $csid);
	$sth_update_host->bind_param (":host_id", $host_id);
	$sth_update_host->execute ();

	$self->{db_h}->commit ();
} # }}}


1;

# vim:foldmethod=marker
