	function request_init () {
		var req = false;

		try {
			// First check for the cool ones (Gecko based, Opera, ...)
			if (window.XMLHttpRequest) {
				req = new XMLHttpRequest ();

			// But maybe ...
			} else if (window.ActiveXObject) {
				try {
					// Internet Explorer 6.0
					req = new ActiveXObject("Msxml2.XMLHTTP");
				} catch (e) {
					// Internet Explorer 5.x
					req= new ActiveXObject("Microsoft.XMLHTTP");
				}
			}

		return req;

		} catch (e) {
			return false;
		}
	}


	function request_data_into_document_element (document_element, url, error_element, errormsg) {
		var req = request_init ();
		if (req == null)
			return;

		var value_elem = document.getElementById (document_element);
		var error_elem = document.getElementById (error_element);

		req.open("GET", url, true)

		// Run this function at reqeust end
		 req.onreadystatechange = function() {
			switch(req.readyState) {
				case 4:
					if (req.status == 200) {
						value_elem.innerHTML = req.responseText;
					} else {
						error_elem.innerHTML = errormsg;
					}
					break;

				default:
					return false;
					break;
			}
		};

		req.setRequestHeader ("Content-Type","application/x-www-form-urlencoded");
                req.send (null);
	}
