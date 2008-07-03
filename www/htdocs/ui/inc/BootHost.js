	function updateHostlist() {
		var url = '/ui/ajax/get_host_select_list_for_hostgroup_wtr_right?right=allow_boot&hg_id=' + document.getElementsByName('group')[0].value;

		var errormsg = "<span class='error'>Hostliste kann nicht geladen werden!</span>";

		// lustiges buntes Ladebildchen hinpappen
		document.getElementById('host_select').innerHTML = '<img src="/img/loading.gif" alt="Loading data...">';

		// Ergebnis box (so vorhanden) blank machen
		document.getElementById('result').innerHTML = '';

		// host_select neu fuellen
		request_data_into_document_element ('host_select', url, errormsg);
	}

	function bootHost(){
		var url = '/ui/ajax/boot_host?host_id=' + document.getElementsByName('host_id')[0].value;

		var errormsg = "<span class='error'>Es ist ein Fehler aufgetreten!</span>";

		// Ergebnisbox mit <div id='result_box'> malen und mit Ladebildchen bestuecken
		document.getElementById('result').innerHTML = "<div class='box'><div class='box_head'>&raquo; Ergebnis</div><div class='box_content' id='result_box'>" +
								"<img src='/img/loading-bar.gif' alt='Booting host...'>" + "</div></div>";

		// 'result_box_ mit echten Daten fuellen
		request_data_into_document_element ('result_box', url, errormsg);
	}
