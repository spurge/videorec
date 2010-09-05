package se.klandestino.flash.videorec {

	import flash.display.Sprite;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.StatusEvent;
	import flash.events.TimerEvent;
	import flash.filters.BlurFilter;
	import flash.filters.BitmapFilterQuality;
	import flash.filters.GlowFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Transform;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.system.Security;
	import flash.system.SecurityPanel;
	import flash.utils.Timer;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	import se.klandestino.flash.debug.Debug;
	import se.klandestino.flash.debug.loggers.NullLogger;
	import se.klandestino.flash.debug.loggers.TraceLogger;
	import se.klandestino.flash.events.VideorecEvent;

	/**
	 *	Sprite sub class description.
	 *
	 *	@langversion ActionScript 3.0
	 *	@playerversion Flash 9.0
	 *
	 *	@author Olof Montin
	 *	@since  02.02.2010
	 */
	public class Videorec extends Sprite {

		//--------------------------------------
		// CLASS CONSTANTS
		//--------------------------------------

		public static const CAMERA_BLUR:Number = 20;
		public static const MICROPHONE_GAIN:Number = 100;

		//--------------------------------------
		//  CONSTRUCTOR
		//--------------------------------------

		/**
		 *	@constructor
		 */
		public function Videorec () {
			super ();
		}
		
		//--------------------------------------
		//  PRIVATE VARIABLES
		//--------------------------------------

		private var camera:Camera;
		private var _connection:NetConnection;
		private var microphone:Microphone;
		private var recordTime:int = 120;
		private var recordTimeLeft:int = 0;
		private var recordTimer:Timer;
		private var stream:NetStream;
		private var streamActiveRecording:Boolean = false;
		private var streamId:String;
		private var video:Video;
		private var videoFlip:Boolean = true;

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		public function get connection ():NetConnection {
			return this._connection;
		}

		public function set connection (connection:NetConnection):void {
			this._connection = connection;
		}

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		public function record ():void {
			Debug.debug ('Trying to start recording ' + this.streamId);
			this.setupNetStream ();
			this.streamDuration = 0;
			this.setupLoaderMovie ();

			var recordSuccess:Boolean = false;
			try {
				this.stream.publish (this.streamId, 'record');
				recordSuccess = true;
			} catch (error:Error) {
				//
			}

			if (!recordSuccess) {
				Debug.error ('Could not record videostream')
				this.stop ();
				this.dispatchEvent (new VideorecEvent (VideorecEvent.DISCONNECTED));
			}
		}

		public function stop ():void {
			Debug.debug ('Trying to stop recording or playing ' + this.streamId);
			this.stream.close ();
			this.removeNetStream ();
			this.setupVideoFilters ();
			this.camera.setLoopback (false);
			this.microphone.setLoopBack (false);
			this.video.attachNetStream (null);
			this.video.attachCamera (this.camera);
		}

		public function finish ():void {
			//
		}

		//--------------------------------------
		//  EVENT HANDLERS
		//--------------------------------------

		private function cameraStatusHandler (event:StatusEvent):void {
			Debug.debug ('Camera status: ' + event.code);

			switch (event.code) {
				case 'Camera.Unmuted':
					this.setupCamera ();

					if (this.connected && !this.microphone.muted) {
						this.dispatchEvent (new VideorecEvent (VideorecEvent.CONNECTED));
					}
					break;
				case 'Camera.Muted':
					this.dispatchEvent (new VideorecEvent (VideorecEvent.NO_CAMERA));
					break;
			}
		}

		private function microphoneStatusHandler (event:StatusEvent):void {
			Debug.debug ('Microphone status: ' + event.code);

			switch (event.code) {
				case 'Microphone.Unmuted':
					this.setupCamera ();

					if (this.connected && !this.camera.muted) {
						this.dispatchEvent (new VideorecEvent (VideorecEvent.CONNECTED));
					}
					break;
				case 'Microphone.Muted':
					this.dispatchEvent (new VideorecEvent (VideorecEvent.NO_MICROPHONE));
					break;
			}
		}

		private function streamNetStatusHandler (event:NetStatusEvent):void {
			Debug.debug ('NetStream status: ' + event.info.code);

			switch (event.info.code) {
				case 'NetStream.Record.Start':
					this.streamActiveRecording = true;
					this.recordStart ();
					break;
				case 'NetStream.Record.Stop':
					this.streamActiveRecording = false;
					this.stop ();
					this.recordStop ();
					break;
			}
		}

		private function streamIoErrorHandler (event:IOErrorEvent):void {
			Debug.error ('NetStream input/output error');
			this.dispatchEvent (new VideorecEvent (VideorecEvent.ERROR_STREAM_IO));
		}

		private function recordTimerCompleteHandler (event:TimerEvent):void {
			Debug.debug ('Timer complete'):
			this.stop ();
			this.recordStop ();
		}

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

		private function recordStart ():void {
			Debug.debug ('Start recording ' + this.streamId);
			this.removeVideoFilters ();

			Debug.debug ('Setting camera bandwidth to ' + this.bandwidth + ' kbit');
			this.camera.setQuality (this.bandwidth, 0);

			this.camera.setLoopback (true);
			this.stream.attachCamera (this.camera);
			this.stream.attachAudio (this.microphone);
			this.setupTimer ();

			this.dispatchEvent (new VideorecEvent (VideorecEvent.RECORD));
		}

		private function recordStop ():void {
			Debug.debug ('Stopped recording ' + this.streamId);
			this.dispatchEvent (new VideorecEvent (VideorecEvent.STOP));
		}

		private function setupVideoFilters ():void {
			var filters:Array = new Array ();
			filters.push (new BlurFilter (Videorec.CAMERA_BLUR, Videorec.CAMERA_BLUR, BitmapFilterQuality.HIGH));
			this.video.filters = filters;
		}

		private function removeVideoFilters ():void {
			this.video.filters = null;
		}

		private function setupCamera ():void {
			if (this.camera == null) {
				this.camera = Camera.getCamera ();

				if (this.camera != null) {
					this.camera.addEventListener (StatusEvent.STATUS, this.cameraStatusHandler, false, 0, true);
				}
			}

			if (this.camera != null) {
				if (this.camera.muted) {
					Debug.debug ('Camera is muted');
					Security.showSettings (SecurityPanel.PRIVACY);
				} else {
					Debug.debug ('Camera is not muted');
				}

				if (this.video == null) {
					this.video = new Video ();
				}
			} else {
				Debug.fatal ('No camera available');
				this.dispatchEvent (new VideorecEvent (VideorecEvent.NO_CAMERA));
				return;
			}

			if (this.video.parent == null) {
				this.addChild (this.video);
			}

			this.video.visible = true;

			if (!(this.camera.muted)) {
				this.video.attachCamera (this.camera);
			}
		}

		private function removeCamera ():void {
			this.video.visible = false;
		}

		private function setupMicrophone ():void {
			if (this.microphone == null) {
				this.microphone = Microphone.getMicrophone ();

				if (this.microphone != null) {
					this.microphone.gain = Videorec.MICROPHONE_GAIN;
					this.microphone.setUseEchoSuppression (true);
					this.microphone.setSilenceLevel (0);
					this.microphone.addEventListener (StatusEvent.STATUS, this.microphoneStatusHandler, false, 0, true);
				}
			}

			if (this.microphone != null) {
				if (this.microphone.muted) {
					Debug.debug ('Microphone is muted');
					Security.showSettings (SecurityPanel.PRIVACY);
				} else {
					Debug.debug ('Microphone is not muted');
				}
			} else {
				Debug.fatal ('No microphone available');
				this.dispatchEvent (new VideorecEvent (VideorecEvent.NO_MICROPHONE));
				return;
			}
		}

		private function setupNetStream ():void {
			Debug.debug ('Setting up NetStream');

			this.removeNetStream ();

			this.stream = new NetStream (this.connection);
			this.stream.addEventListener (NetStatusEvent.NET_STATUS, this.streamNetStatusHandler, false, 0, true);
			this.stream.addEventListener (IOErrorEvent.IO_ERROR, this.streamIoErrorHandler, false, 0, true);

			if (this.streamClient == null) {
				this.streamClient = new NetStreamClient ();
				this.streamClient.addEventListener (NetStreamClientEvent.META, this.streamClientMetaHandler, false, 0, true);
				this.streamClient.addEventListener (NetStreamClientEvent.PLAY_STATUS, this.streamClientStatusHandler, false, 0, true);
			}
		}

		private function removeNetStream ():void {
			if (this.stream != null) {
				this.removeEventListener (NetStatusEvent.NET_STATUS, this.streamNetStatusHandler);
				this.removeEventListener (IOErrorEvent.IO_ERROR, this.streamIoErrorHandler);
				this.stream = null;
			}
		}

		private function setupTimer ():void {
			if (this.recordTimer == null) {
				this.recordTimer = new Timer (1000, this.recordTime);
				this.recordTimer.addEventListener (TimerEvent.TIMER_COMPLETE, this.recordTimerCompleteHandler, false, 0, false);
			}

			this.recordTimer.reset ();
			this.recordTimer.start ();
		}

	}
}