package {

	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.external.ExternalInterface;
	import flash.net.NetConnection;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	import net.hires.debug.Stats;
	import org.red5.flash.bwcheck.events.BandwidthDetectEvent;
	import se.klandestino.flash.config.ConfigLoader;
	import se.klandestino.flash.controlpanel.ControlPanel;
	import se.klandestino.flash.controlpanel.ControlPanelSetup;
	import se.klandestino.flash.debug.Debug;
	import se.klandestino.flash.debug.loggers.NullLogger;
	import se.klandestino.flash.debug.loggers.TraceLogger;
	import se.klandestino.flash.events.ControlPanelEvent;
	import se.klandestino.flash.events.VideoplayerEvent;
	import se.klandestino.flash.events.VideorecEvent;
	import se.klandestino.flash.red5utils.R5MC;
	import se.klandestino.flash.red5utils.Red5BwDetect;
	import se.klandestino.flash.utils.LoaderInfoParams;
	import se.klandestino.flash.utils.StringUtil;
	import se.klandestino.flash.videoplayer.Videoplayer;
	import se.klandestino.flash.videorec.Videorec;

	/**
	 *	Sprite sub class description.
	 *
	 *	@langversion ActionScript 3.0
	 *	@playerversion Flash 10.0
	 *
	 *	@author spurge
	 *	@since  2010-09-02
	 */
	public class Main extends Sprite {

		//--------------------------------------
		// CLASS CONSTANTS
		//--------------------------------------

		[Embed(source="../assets/loader.swf")]
		private var loaderMovieClass:Class;

		public static const CALLBACK_RESIZE:String = 'resize';
		public static const CONFIG_XML_FILE:String = 'videorec.xml';
		public static const CONFIG_ZIP_FILE:String = 'videorec.zip';
		public static const CONNECTION_RETRIES:int = 3;
		public static const CONNECTION_RETRY_TIMEOUT:int = 200;

		//--------------------------------------
		//  CONSTRUCTOR
		//--------------------------------------

		/**
		 *	@constructor
		 */
		public function Main () {
			super ();

			Debug.addLogger (new TraceLogger ());
			//Debug.addLogger (new NullLogger ());

			this.loadConfig ();

			this.setupConnectionControls ();

			this.recplayContainer = new Sprite ();
			this.addChild (this.recplayContainer);

			this.recorder = new Videorec ();
			this.recorder.addEventListener (Event.RESIZE, this.recorderResizeHandler, false, 0, true);
			this.recorder.addEventListener (VideorecEvent.DISCONNECTED, this.recorderDisconnectHandler, false, 0, true);
			this.recorder.addEventListener (VideorecEvent.RECORD, this.recorderRecordHandler, false, 0, true);
			this.recorder.addEventListener (VideorecEvent.STOP, this.recorderStopHandler, false, 0, true);

			this.player = new Videoplayer ();
			this.player.addEventListener (Event.RESIZE, this.playerResizeHandler, false, 0, true);
			this.player.addEventListener (VideoplayerEvent.BUFFER_EMPTY, this.playerBufferEmptyHandler, false, 0, true);
			this.player.addEventListener (VideoplayerEvent.BUFFER_FULL, this.playerBufferFullHandler, false, 0, true);
			this.player.addEventListener (VideoplayerEvent.DISCONNECTED, this.playerDisconnectHandler, false, 0, true);
			this.player.addEventListener (VideoplayerEvent.LOADED, this.playerLoadedHandler, false, 0, true);
			this.player.addEventListener (VideoplayerEvent.STOP, this.playerStopHandler, false, 0, true);

			this.panel = new ControlPanel ();
			this.panel.addEventListener (ControlPanelEvent.SETUP_CHANGE, this.panelSetupChangeHandler, false, 0, true);
			this.panel.recorder = this.recorder;
			this.panel.player = this.player;
			this.addChild (this.panel);

			this.stage.scaleMode = StageScaleMode.NO_SCALE;
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.addEventListener (Event.RESIZE, this.stageResizeHandler, false, 0, true);

			this.stage.dispatchEvent (new Event (Event.RESIZE));
		}

		//--------------------------------------
		//  PRIVATE VARIABLES
		//--------------------------------------

		private var autosize:Boolean = false;
		private var bandwidthOverride:int = 0;
		private var bwDetect:Red5BwDetect;
		private var bwDetectFail:Boolean = false;
		private var config:ConfigLoader;
		private var connected:Boolean = false;
		private var connection:NetConnection;
		private var connectionRetries:int = 0;
		private var connectionRetryTimeout:int;
		private var jsCallback:String;
		private var loader:Sprite;
		private var messages:Object;
		private var missionControl:R5MC;
		private var panel:ControlPanel;
		private var player:Videoplayer;
		private var recplayContainer:Sprite;
		private var r5mcProject:String = '';
		private var r5mcSecret:String = '';
		private var recorder:Videorec;

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		//--------------------------------------
		//  EVENT HANDLERS
		//--------------------------------------

		private function configCompleteHandler (event:Event):void {
			Debug.debug ('Config file loaded, adding params to config object');
			this.setParamsToConfig ();
			this.stage.dispatchEvent (new Event (Event.RESIZE));
			this.start ();
		}

		private function configErrorHandler (event:Event):void {
			Debug.warn ('Error while loading config file, adding params to config object');
			this.setParamsToConfig ();
			this.stage.dispatchEvent (new Event (Event.RESIZE));
			this.start ();
		}

		private function missionControlCompleteHandler (event:Event):void {
			Debug.debug ('Mission Control Complete');
			this.start ();
		}

		private function missionControlErrorHandler (event:ErrorEvent):void {
			Debug.debug ('Mission Control Error');
			this.sendErrorMessage (messages.connectionError);
		}

		private function connectionNetStatusHandler (event:NetStatusEvent): void {
			Debug.debug ('NetConnection status: ' + event.info.code);

			switch (event.info.code) {
				case 'NetConnection.Connect.Success':
					this.connectionRetries = 0;
					this.start ();
					break;
				case 'NetConnection.Connect.Failed':
					if (!this.retryConnection ()) {
						this.sendErrorMessage (messages.connectionError);
					}
					break;
				case 'NetConnection.Connect.Closed':
					if (!this.retryConnection ()) {
						this.sendErrorMessage (messages.connectionLost);
					}
					break;
			}
		}

		private function connectionSecurityErrorHandler (event:SecurityErrorEvent): void {
			Debug.error ('NetConnection security error');
			this.sendErrorMessage (messages.connectionError)
		}

		private function bwCheckCompleteHandler (event:Event):void {
			Debug.debug ('Bandwidth detection complete');
			this.bwDetectFail = false;
			this.start ();
		}

		private function bwCheckFailedHandler (event:ErrorEvent):void {
			Debug.debug ('Bandwidth detection failed');
			this.bwDetectFail = true;
			this.start ();
		}

		private function stageResizeHandler (event:Event):void {
			if (!this.autosize) {
				this.recorder.width = this.stage.stageWidth;
				this.recorder.height = this.stage.stageHeight;
				this.player.width = this.stage.stageWidth;
				this.player.height = this.stage.stageHeight;
			}

			this.setupVideoPositions ();
			this.setupLoaderPositions ();
		}

		private function playerBufferEmptyHandler (event:VideoplayerEvent):void {
			Debug.debug ('Buffer empty, setting up loader');
			this.setupLoader ();
		}

		private function playerBufferFullHandler (event:VideoplayerEvent):void {
			Debug.debug ('Buffer full, removing loader');
			this.removeLoader ();
		}

		private function playerDisconnectHandler (event:VideoplayerEvent):void {
			Debug.debug ('Player got disconnected');
			this.sendErrorMessage (messages.connectionLost);
		}

		private function playerLoadedHandler (event:VideoplayerEvent):void {
			Debug.debug ('Video loaded, removing loader');
			this.removeLoader ();
		}

		private function playerResizeHandler (event:Event):void {
			if (this.autosize) {
				Debug.debug ('New size from video player and autosize is enabled');
				this.sendCallback (Main.CALLBACK_RESIZE, this.player.videoWidth, this.player.videoHeight);
			} else {
				Debug.debug ('New size from video player but autosize is not enabled');
			}

			this.setupVideoPositions ();
			this.setupLoaderPositions ();
		}

		private function playerStopHandler (event:VideoplayerEvent):void {
			Debug.debug ('Video player stopped');
			this.removeLoader ();
		}

		private function recorderDisconnectHandler (event:VideorecEvent):void {
			Debug.debug ('Recorder got disconnected');
			this.sendErrorMessage (messages.connectionLost);
		}

		private function recorderRecordHandler (event:VideorecEvent):void {
			Debug.debug ('Video recorder is recording');
			this.removeLoader ();
		}

		private function recorderStopHandler (event:VideorecEvent):void {
			Debug.debug ('Video recorder stopped');
			this.removeLoader ();
		}

		private function recorderResizeHandler (event:Event):void {
			if (this.autosize) {
				Debug.debug ('New size from video recorder and autosize is enabled');
				this.sendCallback (Main.CALLBACK_RESIZE, this.recorder.width, this.recorder.height);
			} else {
				Debug.debug ('New size from video recorder but autosize is not enabled');
			}

			this.setupVideoPositions ();
			this.setupLoaderPositions ();
		}

		private function panelSetupChangeHandler (event:ControlPanelEvent):void {
			Debug.debug ('Control panel setup changed to ' + event.setup);

			switch (event.setup) {
				case ControlPanelSetup.START:
				case ControlPanelSetup.PREVIEW:
				case ControlPanelSetup.RECORD:
					this.setupRecorder ();
					break;
				case ControlPanelSetup.PLAY:
					this.setupPlayer ();
					break;
				case ControlPanelSetup.FINISH:
					this.removeRecorder ();
					this.removePlayer ();
					this.sendMessage (messages.finish);
					break;
			}
		}

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

		private function start ():void {
			if (!this.missionControl.loaded) {
				this.setupLoader ();
				this.setupMissionControl ();
			} else if (!this.connection.connected) {
				this.setupLoader ();
				this.setupConnection ();
			} else if (!this.bwDetect.detected && this.bwDetectFail) {
				this.setupLoader ();
				this.setupBwDetect ();
			} else {
				this.removeLoader ();
				this.panel.setup (ControlPanelSetup.START);
			}
		}

		private function reset ():void {
			this.removeConnectionControls ();
			this.setupConnectionControls ();
			this.start ();
		}

		private function loadConfig ():void {
			if (this.config == null) {
				this.config = new ConfigLoader ();
				this.config.addEventListener (Event.COMPLETE, this.configCompleteHandler, false, 0, true);
				this.config.addEventListener (ErrorEvent.ERROR, this.configErrorHandler, false, 0, true);

				var config:String = LoaderInfoParams.getParam (this.stage.loaderInfo, 'config', '');

				if (!StringUtil.isEmpty (config)) {
					this.config.load (config);
				} else {
					this.config.load (Main.CONFIG_XML_FILE);
				}
			}
		}

		private function setParamsToConfig ():void {
			this.autosize = LoaderInfoParams.getParam (this.stage.loaderInfo, 'autosize', this.config.getData ('autosize.value', this.autosize));
			this.bandwidthOverride = LoaderInfoParams.getParam (this.stage.loaderInfo, 'bandwidth', this.config.getData ('bandwidth.value', this.bandwidthOverride));
			this.jsCallback = LoaderInfoParams.getParam (this.stage.loaderInfo, 'callback', this.config.getData ('callback.value', ''));
			this.r5mcProject = LoaderInfoParams.getParam (this.stage.loaderInfo, 'r5mcproject', this.config.getData ('r5mcproject.value', this.r5mcProject));
			this.r5mcSecret = LoaderInfoParams.getParam (this.stage.loaderInfo, 'r5mcsecret', this.config.getData ('r5mcsecret.value', this.r5mcSecret));

			this.player.autosize = this.autosize;

			this.messages = {
				connectionError: this.config.getData ('messages.connection.error', ''),
				connectionLost: this.config.getData ('messages.connection.lost', ''),
				finish: this.config.getData ('messages.finish', '')
			}

			this.panel.setPlayButton (this.config.getData ('panel.player.play.src', ''), {
				show: this.config.getData ('panel.player.play.show', ''),
				hide: this.config.getData ('panel.player.play.hide', ''),
				x: this.config.getData ('panel.player.play.x', ''),
				y: this.config.getData ('panel.player.play.y', '')
			});

			this.panel.setPauseButton (this.config.getData ('panel.player.pause.src', ''), {
				show: this.config.getData ('panel.player.pause.show', ''),
				hide: this.config.getData ('panel.player.pause.hide', ''),
				x: this.config.getData ('panel.player.pause.x', ''),
				y: this.config.getData ('panel.player.pause.y', '')
			});

			this.panel.setStopPlayButton (this.config.getData ('panel.player.stop.src', ''), {
				show: this.config.getData ('panel.player.stop.show', ''),
				hide: this.config.getData ('panel.player.stop.hide', ''),
				x: this.config.getData ('panel.player.stop.x', ''),
				y: this.config.getData ('panel.player.stop.y', '')
			});

			this.panel.setPreviewButton (this.config.getData ('panel.recorder.preview.src', ''), {
				show: this.config.getData ('panel.recorder.preview.show', ''),
				hide: this.config.getData ('panel.recorder.preview.hide', ''),
				x: this.config.getData ('panel.recorder.preview.x', ''),
				y: this.config.getData ('panel.recorder.preview.y', '')
			});

			this.panel.setRecordButton (this.config.getData ('panel.recorder.record.src', ''), {
				show: this.config.getData ('panel.recorder.record.show', ''),
				hide: this.config.getData ('panel.recorder.record.hide', ''),
				x: this.config.getData ('panel.recorder.record.x', ''),
				y: this.config.getData ('panel.recorder.record.y', '')
			});

			this.panel.setStopRecordButton (this.config.getData ('panel.recorder.stop.src', ''), {
				show: this.config.getData ('panel.recorder.stop.show', ''),
				hide: this.config.getData ('panel.recorder.stop.hide', ''),
				x: this.config.getData ('panel.recorder.stop.x', ''),
				y: this.config.getData ('panel.recorder.stop.y', '')
			});

			this.panel.setFinishButton (this.config.getData ('panel.recorder.finish.src', ''), {
				show: this.config.getData ('panel.recorder.finish.show', ''),
				hide: this.config.getData ('panel.recorder.finish.hide', ''),
				x: this.config.getData ('panel.recorder.finish.x', ''),
				y: this.config.getData ('panel.recorder.finish.y', '')
			});

			this.panel.init ();

			this.recorder.flip = LoaderInfoParams.getParam (this.stage.loaderInfo, 'flip', this.config.getData ('videoflip.value', null));
			this.recorder.timeLimit = LoaderInfoParams.getParam (this.stage.loaderInfo, 'recordtime', this.config.getData ('recordtime.value', this.recorder.timeLimit));
		}

		private function setupConnectionControls ():void {
			this.connection = new NetConnection ();
			this.connection.addEventListener (NetStatusEvent.NET_STATUS, this.connectionNetStatusHandler, false, 0, true);
			this.connection.addEventListener (SecurityErrorEvent.SECURITY_ERROR, this.connectionSecurityErrorHandler, false, 0, true);

			this.missionControl = new R5MC ();
			this.missionControl.addEventListener (Event.COMPLETE, this.missionControlCompleteHandler, false, 0, true);
			this.missionControl.addEventListener (ErrorEvent.ERROR, this.missionControlErrorHandler, false, 0, true);

			this.bwDetect = new Red5BwDetect ();
			this.bwDetect.addEventListener (Event.COMPLETE, this.bwCheckCompleteHandler, false, 0, true);
			this.bwDetect.addEventListener (ErrorEvent.ERROR, this.bwCheckFailedHandler, false, 0, true);
		}

		private function removeConnectionControls ():void {
			this.connection.removeEventListener (NetStatusEvent.NET_STATUS, this.connectionNetStatusHandler);
			this.connection.removeEventListener (SecurityErrorEvent.SECURITY_ERROR, this.connectionSecurityErrorHandler);
			this.connection = null;

			this.missionControl.removeEventListener (Event.COMPLETE, this.missionControlCompleteHandler);
			this.missionControl.removeEventListener (ErrorEvent.ERROR, this.missionControlErrorHandler);
			this.missionControl = null;

			this.bwDetect.removeEventListener (Event.COMPLETE, this.bwCheckCompleteHandler);
			this.bwDetect.removeEventListener (ErrorEvent.ERROR, this.bwCheckFailedHandler);
			this.bwDetect = null;
		}

		private function setupMissionControl ():void {
			Debug.debug ('Setting up Mission Control');
			this.missionControl.load (this.r5mcProject, this.r5mcSecret);
		}

		private function setupConnection ():void {
			Debug.debug ('Setting up NetConnection');
			this.connection.connect (this.missionControl.rtmp, this.missionControl.stream);
		}

		private function retryConnection ():Boolean {
			clearTimeout (this.connectionRetryTimeout);

			if (this.connectionRetries < Main.CONNECTION_RETRIES) {
				this.connectionRetries++;
				Debug.debug ('Retrying to setup up connection, ' + this.connectionRetries + ' of ' + Main.CONNECTION_RETRIES);
				this.setupLoader ();
				this.connectionRetryTimeout = setTimeout (this.setupConnection, Main.CONNECTION_RETRY_TIMEOUT);
				return true;
			}

			return false;
		}

		private function setupBwDetect ():void {
			this.bwDetect.connection = this.connection;
			this.bwDetect.start ();
		}

		private function setupRecorder ():void {
			this.removeRecorder ();
			this.recorder.connection = this.connection;

			if (this.bandwidthOverride > 0) {
				this.recorder.bandwidth = this.bandwidthOverride;
			} else if (this.bwDetect.detected) {
				this.recorder.bandwidth = this.bwDetect.kbitUp;
			}

			if (this.recorder.parent == null) {
				this.recplayContainer.addChild (this.recorder);
			}
		}

		private function removeRecorder ():void {
			if (this.recorder.parent != null) {
				this.recplayContainer.removeChild (this.recorder);
			}
		}

		private function setupPlayer ():void {
			this.removeRecorder ();
			this.player.connection = this.connection;
			this.player.load (this.missionControl.rtmp + '/' + this.missionControl.stream);
			if (this.player.parent == null) {
				this.recplayContainer.addChild (this.player);
			}
		}

		private function removePlayer ():void {
			if (this.player.parent != null) {
				this.recplayContainer.removeChild (this.player);
			}
		}

		private function setupVideoPositions ():void {
			this.player.x = (this.player.width - this.stage.stageWidth) / 2;
			this.player.y = (this.player.height - this.stage.stageHeight) / 2;
			this.recorder.x = (this.recorder.width - this.stage.stageWidth) / 2;
			this.recorder.y = (this.recorder.height - this.stage.stageHeight) / 2;
		}

		private function setupLoader ():void {
			if (this.loader == null) {
				this.loader = Sprite (new loaderMovieClass ());
			}

			this.loader.visible = true;
			this.setupLoaderPositions ();

			if (this.loader.parent == null) {
				this.addChild (this.loader);
			}
		}

		private function setupLoaderPositions ():void {
			if (this.loader != null) {
				this.loader.x = (this.stage.stageWidth - this.loader.width) / 2;
				this.loader.y = (this.stage.stageHeight - this.loader.height) / 2;
			}
		}

		private function removeLoader ():void {
			if (this.loader != null) {
				this.loader.visible = false;
			}
		}

		private function sendMessage (message:String):void {
			//
		}

		private function sendErrorMessage (message:String):void {
			//
		}

		private function sendCallback (type:String, ... args):void {
			if (!(StringUtil.isEmpty (this.jsCallback))) {
				Debug.debug ('Calling ' + this.jsCallback + ' as javascript callback with type ' + type);
				ExternalInterface.call (this.jsCallback, type, args);
			} else {
				Debug.debug ('No javascript callback to call to');
			}
		}

	}

}