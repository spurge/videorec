var videorec = {
	pattern: '*[data_videorec]',
	swf: 'videorec.swf',

	init: function () {
		if (typeof (window ['swfobject']) != 'undefined' && typeof (window ['jQuery']) != 'undefined') {
			$(document).ready (videorec.hook);
		}
	},

	hook: function () {
		$(videorec.pattern).ready (videorec.generate);
	},

	generate: function () {
		var jElm = $(videorec.pattern);

		var id = new String (jElm.attr ('id'));
		if (id.length <= 0 || id == 'undefined') {
			var count = 0;
			id = 'videorec' + count;
			while (document.getElementById (id)) {
				count++;
				id = 'videorec' + count;
			}
		}

		var width = jElm.width ();
		var height = jElm.height ();

		var params = {
			config: jElm.attr ('data_config')
		};

		jElm.replaceWith ('<div id="' + id + '"></div>');
		swfobject.embedSWF (videorec.swf, id, width, height, '10.0.0', null, params);

		if (params.callback != null) {
			eval (params.callback + '("started", {id:"' + id + '"});');
		}
	}
}

videorec.init ();