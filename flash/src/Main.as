package {

	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.external.ExternalInterface;
	import net.hires.debug.Stats;
	import org.red5.flash.bwcheck.events.BandwidthDetectEvent;
	import se.klandestino.flash.config.ConfigLoader;
	import se.klandestino.flash.debug.Debug;
	import se.klandestino.flash.debug.loggers.NullLogger;
	import se.klandestino.flash.debug.loggers.TraceLogger;
	import se.klandestino.flash.red5utils.R5MC;
	import se.klandestino.flash.red5utils.Red5BwDetect;
	import se.klandestino.flash.utils.LoaderInfoParams;
	import se.klandestino.flash.utils.StringUtil;
	import se.klandestino.flash.videorec.ControlPanel;
	import se.klandestino.flash.videorec.Recorder;

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

		public static const CONFIG_XML_FILE:String = 'videorec.xml';
		public static const CONFIG_ZIP_FILE:String = 'videorec.zip';

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

			this.stage.scaleMode = StageScaleMode.NO_SCALE;
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.addEventListener (Event.RESIZE, this.init, false, 0, true);
			this.stage.dispatchEvent (new Event (Event.RESIZE));
		}

		//--------------------------------------
		//  PRIVATE VARIABLES
		//--------------------------------------

		private var bandwidthOverride:int = 0;
		private var config:ConfigLoader;
		private var missionControl:R5MC;
		private var panel:ControlPanel;
		private var r5mcProject:String = '';
		private var r5mcSecret:String = '';
		private var recorder:Recorder;

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

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

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
			this.bandwidthOverride = LoaderInfoParams.getParam (this.stage.loaderInfo, 'bandwidth', this.config.getData ('bandwidth.value', this.bandwidthOverride));
			this.jsCallback = LoaderInfoParams.getParam (this.stage.loaderInfo, 'callback', this.config.getData ('callback.value', ''));
			this.r5mcProject = LoaderInfoParams.getParam (this.stage.loaderInfo, 'r5mcproject', this.config.getData ('r5mcproject.value', this.r5mcProject));
			this.r5mcSecret = LoaderInfoParams.getParam (this.stage.loaderInfo, 'r5mcsecret', this.config.getData ('r5mcsecret.value', this.r5mcSecret));

			this.recorder.flip = LoaderInfoParams.getParam (this.stage.loaderInfo, 'flip', this.config.getData ('videoflip.value', null));
			this.recorder.timelimit = LoaderInfoParams.getParam (this.stage.loaderInfo, 'recordtime', this.config.getData ('recordtime.value', this.recordTime));
			this.recorder.init ();

			this.panel.init ();
		}

	}

}

