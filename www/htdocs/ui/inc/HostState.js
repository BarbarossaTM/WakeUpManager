	function updateHostlist() {
		var url = '/ui/ajax/get_host_select_list_for_hostgroup_wtr_right?right=read_config&hg_id=' + document.getElementsByName('group')[0].value;

		var errormsg = "<span class='error'>Hostliste kann nicht geladen werden!</span>";

		// lustiges buntes Ladebildchen hinpappen
		document.getElementById('host_select').innerHTML = '<img src="/img/loading.gif" alt="Loading data...">';

		// Ergebnis box (so vorhanden) blank machen
		document.getElementById('result').innerHTML = '';

		// host_select neu fuellen
		request_data_into_document_element ('host_select', url, 'host_select', errormsg);
	}

	function loadHostState(){
		var url = '/ui/ajax/get_host_state?host_id=' + document.getElementsByName('host_id')[0].value;

		var errormsg = "<span class='error'>Could not load host state!</span>";

		var option_index = document.forms.host_state.elements.host_id.selectedIndex;

		// Ergebnisbox mit <div id='result_box'> malen und mit Ladebildchen bestuecken
		document.getElementById('result').innerHTML = "<div class='box'><div class='box_head'>&nbsp;<br></div><div class='box_content' id='result_box'>" +
								"<img src='/img/loading-bar.gif' alt='Loading host state...'>" + "</div></div>";

		// 'result_box_ mit echten Daten fuellen
		request_data_into_document_element ('result', url, 'result_box', errormsg);
	}

	function setHostState(){
		var boot_host = document.forms.host_state_form2.elements.boot_host.checked;
		var shutdown_host = document.forms.host_state_form2.elements.shutdown_host.checked;

		var url = '/ui/ajax/set_host_state?host_id=' + document.getElementsByName('host_id')[0].value + '&boot_host=' + boot_host + '&shutdown_host=' + shutdown_host;

		var errormsg = "<span class='error'>Could not save host state!</span>";

		// Ergebnisbox mit <div id='result_box'> malen und mit Ladebildchen bestuecken
		document.getElementById('host_state_update_result').innerHTML = "<img src='/img/loading.gif' alt='Updating host state...'>";

		// 'result_box_ mit echten Daten fuellen
		request_data_into_document_element ('host_state_update_result', url, 'host_state_update_result', errormsg);
	}

