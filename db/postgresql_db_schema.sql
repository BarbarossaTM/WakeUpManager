--
-- The WakeUpManager host-db sql schema
--


--
-- The ethernet/IP networks hosts/agents are conneted to
CREATE TABLE network (
	net_id serial primary key,
	name varchar(42) not null unique,
	net_cidr cidr not null,
	description varchar(256)
);
CREATE INDEX network_net_key ON network using BTREE (net_cidr);


--
-- The WakeUpManager::Agent's
CREATE TABLE agent (
	agent_id serial primary key,
	name varchar(42) not null unique,
	ip_addr inet not null unique,
	description varchar(256)
);


--
-- Which agent is connected to which network(s)?
CREATE TABLE agent_network (
	agent_id integer,
	net_id integer,
	FOREIGN KEY (agent_id) REFERENCES agent (agent_id) ON DELETE CASCADE,
	FOREIGN KEY (net_id) REFERENCES network (net_id)
);

CREATE VIEW v_agent_network
	AS
		SELECT
			a.name as "agent name",
			a.ip_addr as "agent ip",
			n.name as "network name",
			n.net_cidr as "CIDR network"
		FROM
			agent a,
			network n,
			agent_network an
		WHERE
				a.agent_id = an.agent_id
			AND	an.net_id = n.net_id;


--
-- Configuration sets
CREATE TABLE config_set (
	csid serial primary key,
	preset boolean not null default 'false',
	name varchar(42) not null unique,
	administrative boolean default 'false'
);

--
-- The times and actions, a config_set consists of
CREATE TABLE times (
	tid serial primary key,
	csid integer not null,
	day char(3) not null check (day in ('mon','tue','wed','thu','fri','sat','sun')),
	time time not null,
	action varchar(12) not null check (action in ('boot','shutdown')),
	foreign key (csid) REFERENCES config_set (csid) ON DELETE CASCADE
);
CREATE INDEX times_csid_key on times using BTREE (csid);
CREATE UNIQUE INDEX csid_day_time_key on times using BTREE (csid, day, time);


--
-- Hostgroups (Pools, working groups, ...)
CREATE TABLE hostgroup (
	hostgroup_id serial primary key,
	name varchar(42) not null,
	admin_csid integer,
	description varchar(256),
	foreign key (admin_csid) REFERENCES config_set (csid)
);

--
-- Table to specify hostgroup hierarchy
CREATE TABLE hostgroup_tree (
	super_group_id integer not null,
	member_group_id integer not null check (member_group_id != super_group_id),
	FOREIGN KEY (super_group_id) REFERENCES hostgroup (hostgroup_id) ON DELETE CASCADE,
	FOREIGN KEY (member_group_id) REFERENCES hostgroup (hostgroup_id) ON DELETE CASCADE
);
CREATE INDEX hostgroup_tree_super_group_id_key on hostgroup_tree using BTREE (super_group_id);
CREATE UNIQUE INDEX hostgroup_tree_member_group_id_key on hostgroup_tree using BTREE (member_group_id);



--
-- The hosts managed with WakeUpManager
CREATE TABLE host (
	host_id serial primary key,
	csid integer not null,
	name varchar(256) not null unique,
	mac_addr macaddr not null,
	net_id integer not null,
	boot_host boolean not null default true,
	shutdown_host boolean not null default true,
	password varchar(42),
	hostgroup_id integer not null,
	FOREIGN KEY (csid) REFERENCES config_set (csid),
	FOREIGN KEY (net_id) REFERENCES network (net_id),
	FOREIGN KEY (hostgroup_id) REFERENCES hostgroup (hostgroup_id)
);
CREATE INDEX host_csid_key on host using BTREE (csid);
CREATE INDEX host_hostgroup_id_key on host using BTREE (hostgroup_id);

CREATE VIEW v_host
	AS
		SELECT
			h.host_id,
			h.name as "hostname",
			hg.name as "hostgroup",
			cs.name as "config set",
			n.name as "network",
			h.mac_addr as "mac addr",
			h.boot_host,
			h.shutdown_host
		FROM
			host		h,
			hostgroup	hg,
			config_set	cs,
			network		n
		WHERE
				h.csid = cs.csid
			AND	h.net_id = n.net_id
			AND	h.hostgroup_id = hg.hostgroup_id;


CREATE VIEW v_host_times
	AS
		SELECT
			h.name as "hostname",
			day,
			time,
			action
		FROM
			host		h,
			times		t
		WHERE
			h.csid = t.csid
		ORDER BY hostname;


CREATE VIEW v_config_set_with_times
	AS
		SELECT
			cs.name as "config set",
			t.day,
			t.time,
			t.action
		FROM
			config_set	cs,
			times		t
		WHERE
			cs.csid = t.csid;



--
-- ACLs
CREATE TABLE hostgroup_acl (
	hostgroup_id integer not null,
	uid varchar(64) not null,
	allow_boot boolean default false,
	read_config boolean default false,
	write_config boolean default false,
	FOREIGN KEY (hostgroup_id) REFERENCES hostgroup (hostgroup_id) ON DELETE CASCADE
);
CREATE INDEX hostgroup_acl_hostgroup_id_key on hostgroup_acl using BTREE (hostgroup_id);

CREATE VIEW v_hostgroup_acl
	AS
		SELECT
			hg.name,
			hg_acl.uid,
			hg_acl.allow_boot,
			hg_acl.read_config,
			hg_acl.write_config
		FROM
			hostgroup hg,
			hostgroup_acl hg_acl
		WHERE
			hg.hostgroup_id = hg_acl.hostgroup_id;


CREATE TABLE host_acl (
	host_id integer not null,
	uid varchar(64) not null,
	allow_boot boolean default false,
	read_config boolean default false,
	write_config boolean default false,
	FOREIGN KEY (host_id) REFERENCES host (host_id) ON DELETE CASCADE
);
CREATE INDEX host_acl_host_id_key on host_acl using BTREE (host_id);

CREATE VIEW v_host_acl
	AS
		SELECT
			h.name,
			h_acl.uid,
			h_acl.allow_boot,
			h_acl.read_config,
			h_acl.write_config
		FROM
			host h,
			host_acl h_acl
		WHERE
			h.host_id = h_acl.host_id;
