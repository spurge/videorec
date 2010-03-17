var videorec = {
	pattern: '*[data_videorec]',
	swf: 'videorec.swf',
	width: 600,
	height: 400,

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

		jElm.width (videorec.width);
		jElm.height (videorec.height);

		var params = {
			filename: jElm.attr ('data_filename'),
			connectionurl: jElm.attr ('data_connection_url'),
			recordtime: jElm.attr ('data_recordtime'),
			callback: jElm.attr ('data_callback'),
			recordsrc: jElm.attr ('data_record_src'),
			recordx: jElm.attr ('data_record_x'),
			recordy: jElm.attr ('data_record_y'),
			stopsrc: jElm.attr ('data_stop_src'),
			stopx: jElm.attr ('data_stop_x'),
			stopy: jElm.attr ('data_stop_y'),
			finishsrc: jElm.attr ('data_finish_src'),
			finishx: jElm.attr ('data_finish_x'),
			finishy: jElm.attr ('data_finish_y'),
			playsrc: jElm.attr ('data_play_src'),
			playx: jElm.attr ('data_play_x'),
			playy: jElm.attr ('data_play_y'),
			info1src: jElm.attr ('data_info1_src'),
			info1x: jElm.attr ('data_info1_x'),
			info1y: jElm.attr ('data_info1_y'),
			info2src: jElm.attr ('data_info2_src'),
			info2x: jElm.attr ('data_info2_x'),
			info2y: jElm.attr ('data_info2_y'),
			info3src: jElm.attr ('data_info3_src'),
			info3x: jElm.attr ('data_info3_x'),
			info3y: jElm.attr ('data_info3_y')
		};

		jElm.replaceWith ('<div id="' + id + '"></div>');
		swfobject.embedSWF (videorec.swf, id, videorec.width, videorec.height, '10.0.0', null, params);

		if (params.callback != null) {
			eval (params.callback + '("started", {id:"' + id + '"});');
		}
	}
}

videorec.init ();