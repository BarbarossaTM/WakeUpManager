	function updateHostlist() {
		var url = '/ui/ajax/get_host_select_list_for_hostgroup_wtr_right?right=read_config&hg_id=' + document.getElementsByName('group')[0].value;

		var errormsg = "<span class='error'>Hostliste kann nicht geladen werden!</span>";

		// lustiges buntes Ladebildchen hinpappen
		document.getElementById('host_select').innerHTML = '<img src="/img/loading.gif" alt="Loading data...">';

		// Ergebnis box (so vorhanden) blank machen
		document.getElementById('result').innerHTML = '';

		// host_select neu fuellen
		request_data_into_document_element ('host_select', url, errormsg);
	}

	function loadHostState(){
		var url = '/ui/ajax/get_host_state?host_id=' + document.getElementsByName('host')[0].value;

		var errormsg = "<span class='error'>Rechnerkonfiguration konnte nicht geladen werden!</span>";

		var option_index = document.forms.host_state.elements.host.selectedIndex;
		var hostname = document.forms.host_state.host.options[option_index].text;

		// Ergebnisbox mit <div id='result_box'> malen und mit Ladebildchen bestuecken
		document.getElementById('result').innerHTML = "<div class='box'><div class='box_head'>&raquo; Aktivierungsstatus f&uuml;r Rechner " + hostname + "</div><div class='box_content' id='result_box'>" +
								"<img src='/img/loading-bar.gif' alt='Booting host...'>" + "</div></div>";

		// 'result_box_ mit echten Daten fuellen
		request_data_into_document_element ('result_box', url, errormsg);
	}

	function setHostState(){
		var boot_host = document.forms.host_state_form2.elements.boot_host.checked;
		var shutdown_host = document.forms.host_state_form2.elements.shutdown_host.checked;

		var url = '/ui/ajax/set_host_state?host_id=' + document.getElementsByName('host')[0].value + '&boot_host=' + boot_host + '&shutdown_host=' + shutdown_host;

		var errormsg = "<span class='error'>Rechnerkonfiguration konnte nicht gespeichert werden!</span>";

		// Ergebnisbox mit <div id='result_box'> malen und mit Ladebildchen bestuecken
		document.getElementById('host_state_update_result').innerHTML = "<img src='/img/loading.gif' alt='Updating host state...'>";

		// 'result_box_ mit echten Daten fuellen
		request_data_into_document_element ('host_state_update_result', url, errormsg);
	}

