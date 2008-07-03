	function updateHostlist() {
		var url = '/ui/ajax/get_host_select_list_for_hostgroup_wtr_right?right=write_config&hg_id=' + document.getElementsByName('group')[0].value;

		var errormsg = "<span class='error'>Hostliste kann nicht geladen werden!</span>";

		// lustiges buntes Ladebildchen hinpappen
		document.getElementById('host_select').innerHTML = '<img src="/img/loading.gif" alt="Loading data...">';

		// host_select neu fuellen
		request_data_into_document_element ('host_select', url, errormsg);
	}
