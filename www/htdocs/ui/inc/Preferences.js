	function savePreferences() {
		// Ergebnisbox mit <div id='result_box'> malen und mit Ladebildchen bestuecken
		document.getElementById('result').innerHTML = "<div class='box'><div class='box_head'>&raquo; Ergebnis</div><div class='box_content' id='result_box'>" +
		                                              "<img src='img/loading-bar.gif' alt='Saving preferences...'>" + "</div></div>";
		var timetable_orientation;
		if (document.forms.Preferences.elements.timetable_orientation[0].checked) {
			timetable_orientation = 'horizontal';
			document.forms.Preferences.elements.timetable_orientation[1].disabled = true;
		} else {
			document.forms.Preferences.elements.timetable_orientation[0].disabled = true;
			timetable_orientation = 'vertical';
		}

		document.cookie = "timetable_orientation=" + timetable_orientation + ";";

		document.getElementById('result_box').innerHTML = "Ok";

	}
