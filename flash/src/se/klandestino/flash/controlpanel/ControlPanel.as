package se.klandestino.flash.controlpanel {

	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.ui.Mouse;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	import se.klandestino.flash.controlpanel.ControlPanelSetup;
	import se.klandestino.flash.debug.Debug;
	import se.klandestino.flash.events.ControlPanelEvent;
	import se.klandestino.flash.events.VideoplayerEvent;
	import se.klandestino.flash.events.VideorecEvent;
	import se.klandestino.flash.net.MultiLoader;
	import se.klandestino.flash.utils.CoordinationTools;
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
	public class ControlPanel extends Sprite {

		//--------------------------------------
		// CLASS CONSTANTS
		//--------------------------------------

		public static const MOUSE_HIDE_TIMEOUT:int = 3000;
		public static const POSITION_BOTTOM:String = 'bottom';
		public static const POSITION_CENTER:String = 'center';
		public static const POSITION_LEFT:String = 'left';
		public static const POSITION_RIGHT:String = 'right';
		public static const POSITION_TOP:String = 'top';
		public static const SHOW_ALWAYS:String = 'always';

		//--------------------------------------
		//  CONSTRUCTOR
		//--------------------------------------

		/**
		 *	@constructor
		 */
		public function ControlPanel () {
			super ();
			this.visible = false;
			this.loader = new MultiLoader ();
			this.loader.addEventListener (Event.COMPLETE, this.loaderCompleteHandler, false, 0, true);
		}

		//--------------------------------------
		//  PRIVATE VARIABLES
		//--------------------------------------

		private var buttonOffsets:Object;
		private var _currentSetup:String = ControlPanelSetup.START;
		private var finishbutton:Object;
		private var loader:MultiLoader;
		private var mouseTimeout:uint;
		private var pausebutton:Object;
		private var playbutton:Object;
		private var previewbutton:Object;
		private var recordbutton:Object;
		private var stopplaybutton:Object;
		private var stoprecordbutton:Object;
		private var _player:Videoplayer;
		private var _recorder:Videorec;

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		public function get currentSetup ():String {
			return this._currentSetup;
		}

		public function get player ():Videoplayer {
			return this._player;
		}

		public function set player (player:Videoplayer):void {
			this.removePlayerEventListeners ();
			this._player = player;
			this.addPlayerEventListeners ();
		}

		public function get recorder ():Videorec {
			return this._recorder;
		}

		public function set recorder (recorder:Videorec):void {
			this.removeRecorderEventListeners ();
			this._recorder = recorder;
			this.addPlayerEventListeners ();
		}

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		public function init ():void {
			this.loader.load ();
		}

		public function setup (setup:String):void {
			Debug.debug ('Settng up control panel to ' + setup);

			switch (setup) {
				case ControlPanelSetup.START:
					this._currentSetup = ControlPanelSetup.START;
					Mouse.show ();
					break;
				case ControlPanelSetup.RECORD:
					this._currentSetup = ControlPanelSetup.RECORD;
					Mouse.show ();
					if (this.recorder != null) {
						this.recorder.record ();
					} else {
						Debug.warn ('No recorder registered to record');
					}
					break;
				case ControlPanelSetup.PREVIEW:
					this._currentSetup = ControlPanelSetup.PREVIEW;
					Mouse.show ();
					break;
				case ControlPanelSetup.PLAY:
					if (this.player != null) {
						if (this._currentSetup == ControlPanelSetup.PLAY_PAUSE) {
							this.player.resume ();
						} else {
							this.player.play ();
						}
					} else {
						Debug.warn ('No player registered to play');
					}

					this._currentSetup = ControlPanelSetup.PLAY;
					Mouse.show ();
					break;
				case ControlPanelSetup.PLAY_MOUSE:
					this._currentSetup = ControlPanelSetup.PLAY_MOUSE;
					Mouse.show ();
					clearTimeout (this.mouseTimeout);
					this.mouseTimeout = setTimeout (this.endMouseSetup, ControlPanel.MOUSE_HIDE_TIMEOUT);
					break;
				case ControlPanelSetup.PLAY_PAUSE:
					this.player.pause ();
					this._currentSetup = ControlPanelSetup.PLAY_PAUSE;
					Mouse.show ();
					break;
				case ControlPanelSetup.FINISH:
					this._currentSetup = ControlPanelSetup.FINISH;
					Mouse.show ();
					break;
				default:
					Debug.warn ('There is no setup with name ' + setup);
					return;
			}

			this.buttonOffsets = null;
			this.setupButton (this.finishbutton);
			this.setupButton (this.pausebutton);
			this.setupButton (this.playbutton);
			this.setupButton (this.recordbutton);
			this.setupButton (this.stopplaybutton);
			this.setupButton (this.stoprecordbutton);

			var event:ControlPanelEvent = new ControlPanelEvent (ControlPanelEvent.SETUP_CHANGE);
			event.setup = setup;
			this.dispatchEvent (event);
		}

		public function setFinishButton (url:String, params:Object = null):void {
			Debug.debug ('Setting finish button to ' + url);
			this.hideButton (this.finishbutton);
			this.finishbutton = createButton ('finish', url, params, {
				show: ControlPanelSetup.PREVIEW,
				hide: ControlPanelSetup.START
			});
		}

		public function setPauseButton (url:String, params:Object = null):void {
			Debug.debug ('Setting pause button to ' + url);
			this.hideButton (this.pausebutton);
			this.pausebutton = createButton ('pause', url, params, {
				show: ControlPanelSetup.PLAY_MOUSE,
				hide: ControlPanelSetup.PLAY
			});
		}

		public function setPlayButton (url:String, params:Object = null):void {
			Debug.debug ('Setting play button to ' + url);
			this.hideButton (this.playbutton);
			this.playbutton = createButton ('play', url, params, {
				show: ControlPanelSetup.PREVIEW + ' ' + ControlPanelSetup.PLAY_PAUSE,
				hide: ControlPanelSetup.PLAY
			});
		}

		public function setPreviewButton (url:String, params:Object = null):void {
			Debug.debug ('Setting preview button to ' + url);
			this.hideButton (this.previewbutton);
			this.previewbutton = createButton ('preview', url, params, {
				show: ControlPanelSetup.PREVIEW,
				hide: ControlPanelSetup.START + ' ' + ControlPanelSetup.PLAY
			});
		}

		public function setStopPlayButton (url:String, params:Object = null):void {
			Debug.debug ('Setting stop play button to ' + url);
			this.hideButton (this.stopplaybutton);
			this.stopplaybutton = createButton ('stop-play', url, params, {
				show: ControlPanelSetup.PLAY,
				hide: ControlPanelSetup.RECORD + ' ' + ControlPanelSetup.START + ' ' + ControlPanelSetup.PREVIEW
			});
		}

		public function setStopRecordButton (url:String, params:Object = null):void {
			Debug.debug ('Setting stop record button to ' + url);
			this.hideButton (this.stoprecordbutton);
			this.stoprecordbutton = createButton ('stop-record', url, params, {
				show: ControlPanelSetup.RECORD,
				hide: ControlPanelSetup.PLAY + ' ' + ControlPanelSetup.START + ' ' + ControlPanelSetup.PREVIEW
			});
		}

		public function setRecordButton (url:String, params:Object = null):void {
			Debug.debug ('Setting record button to ' + url);
			this.hideButton (this.recordbutton);
			this.recordbutton = createButton ('record', url, params, {
				show: ControlPanelSetup.START,
				hide: ControlPanelSetup.PLAY
			});
		}

		//--------------------------------------
		//  EVENT HANDLERS
		//--------------------------------------

		private function buttonClickHandler (event:MouseEvent):void {
			if (this.finishbutton != null) {
				Debug.debug ('Finish button clicked');
				this.setup (ControlPanelSetup.FINISH)
			}

			if (this.pausebutton != null) {
				if (event.target === this.pausebutton.sprite) {
					Debug.debug ('Pause button clicked');
					this.setup (ControlPanelSetup.PLAY_PAUSE);
				}
			}

			if (this.playbutton != null) {
				if (event.target === this.playbutton.sprite) {
					Debug.debug ('Play button clicked');
					this.setup (ControlPanelSetup.PLAY);
				}
			}

			if (this.previewbutton != null) {
				if (event.target === this.previewbutton.sprite) {
					Debug.debug ('Preview button clicked');
					this.setup (ControlPanelSetup.PLAY);
				}
			}

			if (this.recordbutton != null) {
				if (event.target === this.recordbutton.sprite) {
					Debug.debug ('Record button clicked');
					this.setup (ControlPanelSetup.RECORD);
				}
			}

			if (this.stopplaybutton != null) {
				if (event.target === this.stopplaybutton.sprite) {
					Debug.debug ('Stop play button clicked');
					this.setup (ControlPanelSetup.PREVIEW);
				}
			}

			if (this.stoprecordbutton != null) {
				if (event.target === this.stoprecordbutton.sprite) {
					Debug.debug ('Stop record button clicked');
					this.setup (ControlPanelSetup.PREVIEW);
				}
			}
		}

		private function loaderCompleteHandler (event:Event):void {
			Debug.debug ('Loading buttons complete');
			this.setup (this.currentSetup);
		}

		private function playerEnterFrameHandler (event:Event):void {
			/*var point:Point = CoordinationTools.localToLocal (this.videoplayer, this);
			this.x = point.x;
			this.y = point.y;*/
		}

		private function playerLoadedHandler (event:VideoplayerEvent):void {
			Debug.debug ('Handling loaded event from video player');
		}

		private function playerMouseMoveHandler (event:MouseEvent):void {
			if (this.currentSetup == ControlPanelSetup.PLAY) {
				this.setup (ControlPanelSetup.PLAY_MOUSE);
			}
		}

		private function playerPauseHandler (event:VideoplayerEvent):void {
			Debug.debug ('Handling pause event from video player');
			this.setup (ControlPanelSetup.PLAY_PAUSE);
		}

		private function playerPlayHandler (event:VideoplayerEvent):void {
			Debug.debug ('Handling play event from video player');
			this.setup (ControlPanelSetup.PLAY);
		}

		private function playerResizeHandler (event:Event):void {
			Debug.debug ('Handling resize event from video player ' + this.player.width + 'x' + this.player.height);
			this.setup (this.currentSetup);
		}

		private function playerResumeHandler (event:VideoplayerEvent):void {
			Debug.debug ('Handling resume event from video player');
			this.setup (ControlPanelSetup.PLAY);
		}

		private function playerStopHandler (event:VideoplayerEvent):void {
			Debug.debug ('Handling pause event from video player');
			this.setup (ControlPanelSetup.PREVIEW);
		}

		private function recorderEnterFrameHandler (event:Event):void {
			//
		}

		private function recorderRecordHandler (event:VideorecEvent):void {
			Debug.debug ('Handling record event from video recorder');
			this.setup (ControlPanelSetup.RECORD);
		}

		private function recorderResizeHandler (event:Event):void {
			Debug.debug ('Handling resize event from video recorder ' + this.recorder.width + 'x' + this.recorder.height);
			this.setup (this.currentSetup);
		}

		private function recorderStopHandler (event:VideorecEvent):void {
			Debug.debug ('Handling stop event from video recorder');
			this.setup (ControlPanelSetup.PREVIEW);
		}

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

		private function removePlayerEventListeners ():void {
			if (this._player != null) {
				this._player.removeEventListener (Event.ENTER_FRAME, this.playerEnterFrameHandler);
				this._player.removeEventListener (Event.RESIZE, this.playerResizeHandler);
				this._player.removeEventListener (MouseEvent.MOUSE_MOVE, this.playerMouseMoveHandler);
				this._player.removeEventListener (VideoplayerEvent.LOADED, this.playerLoadedHandler);
				this._player.removeEventListener (VideoplayerEvent.PAUSE, this.playerPauseHandler);
				this._player.removeEventListener (VideoplayerEvent.PLAY, this.playerPlayHandler);
				this._player.removeEventListener (VideoplayerEvent.RESUME, this.playerResumeHandler);
				this._player.removeEventListener (VideoplayerEvent.STOP, this.playerStopHandler);
			}
		}

		private function addPlayerEventListeners ():void {
			if (this._player != null) {
				this._player.addEventListener (Event.ENTER_FRAME, this.playerEnterFrameHandler, false, 0, true);
				this._player.addEventListener (Event.RESIZE, this.playerResizeHandler, false, 0, true);
				this._player.addEventListener (MouseEvent.MOUSE_MOVE, this.playerMouseMoveHandler, false, 0, true);
				this._player.addEventListener (VideoplayerEvent.LOADED, this.playerLoadedHandler, false, 0, true);
				this._player.addEventListener (VideoplayerEvent.PAUSE, this.playerPauseHandler, false, 0, true);
				this._player.addEventListener (VideoplayerEvent.PLAY, this.playerPlayHandler, false, 0, true);
				this._player.addEventListener (VideoplayerEvent.RESUME, this.playerResumeHandler, false, 0, true);
				this._player.addEventListener (VideoplayerEvent.STOP, this.playerStopHandler, false, 0, true);
			}
		}

		private function removeRecorderEventListeners ():void {
			if (this._recorder != null) {
				this._recorder.removeEventListener (Event.ENTER_FRAME, this.recorderEnterFrameHandler);
				this._recorder.removeEventListener (Event.RESIZE, this.recorderResizeHandler);
				this._recorder.removeEventListener (VideorecEvent.RECORD, this.recorderRecordHandler);
				this._recorder.removeEventListener (VideorecEvent.STOP, this.recorderStopHandler);
			}
		}

		private function addRecorderEventListeners ():void {
			if (this._recorder != null) {
				this._recorder.addEventListener (Event.ENTER_FRAME, this.recorderEnterFrameHandler, false, 0, true);
				this._recorder.addEventListener (Event.RESIZE, this.recorderResizeHandler, false, 0, true);
				this._recorder.addEventListener (VideorecEvent.RECORD, this.recorderRecordHandler, false, 0, true);
				this._recorder.addEventListener (VideorecEvent.STOP, this.recorderStopHandler, false, 0, true);
			}
		}

		private function createButton (name:String, url:String, params:Object, defaultValues:Object):Object {
			var button:Object = new Object ();
			button.url = url;
			button.show = params ? (params.show ? params.show : defaultValues.show) : defaultValues.show;
			button.hide = params ? (params.hide ? params.hide : defaultValues.hide) : defaultValues.hide;
			button.x = params ? (params.x ? params.x : defaultValues.x) : defaultValues.x;
			button.y = params ? (params.y ? params.y : defaultValues.y) : defaultValues.y;
			button.sprite = new Sprite ();
			this.addChild (button.sprite);
			this.loader.add (url, name, button.sprite);
			return button;
		}

		private function hideButton (button:Object):void {
			if (button != null) {
				button.sprite.removeEventListener (MouseEvent.CLICK, this.buttonClickHandler);
				button.sprite.visible = false;
			}
		}

		private function showButton (button:Object):void {
			button.sprite.mouseChildren = false;
			button.sprite.buttonMode = true;
			button.sprite.addEventListener (MouseEvent.CLICK, this.buttonClickHandler, false, 0, true);
			this.setupButtonPositions (button);
			button.sprite.visible = true;
		}

		private function setupButton (button:Object):void {
			if (button != null) {
				if (StringUtil.containsWord (button.hide, this.currentSetup)) {
					this.hideButton (button);
				} else if (StringUtil.containsWord (button.show, this.currentSetup) || StringUtil.containsWord (button.show, ControlPanel.SHOW_ALWAYS)) {
					this.showButton (button);
				}
			}
		}

		private function setupButtonPositions (button:Object):void {
			var device:* = null;

			if (
				this.currentSetup == ControlPanelSetup.START
				|| this.currentSetup == ControlPanelSetup.RECORD
				|| this.currentSetup == ControlPanelSetup.PREVIEW
			) {
				device = this.recorder;
			} else if (
				this.currentSetup == ControlPanelSetup.PLAY
				|| this.currentSetup == ControlPanelSetup.PLAY_MOUSE
				|| this.currentSetup == ControlPanelSetup.PLAY_PAUSE
			) {
				device = this.player;
			}

			if (this.buttonOffsets == null) {
				this.buttonOffsets = {
					left: 0,
					right: 0
				}
			}

			if (button != null && device != null) {
				var centered:Boolean = true;
				var x:Number = (device.width - button.sprite.width) / 2;
				var y:Number = (device.height - button.sprite.height) / 2;

				if (!StringUtil.isEmpty (button.x)) {
					if (!isNaN (parseFloat (button.x))) {
						x = parseFloat (button.x);
					} else {
						switch (button.x) {
							case ControlPanel.POSITION_LEFT:
								centered = false;
								x = this.buttonOffsets.left;
								this.buttonOffsets += button.sprite.width;
								break;
							case ControlPanel.POSITION_RIGHT:
								centered = false;
								x = device.width - button.sprite.width - this.buttonOffsets.right;
								this.buttonOffsets += button.sprite.width;
								break;
							default:
								Debug.warn ('There x is no position by value ' + button.x);
						}
					}
				}

				if (!StringUtil.isEmpty (button.y)) {
					if (!isNaN (parseFloat (button.y))) {
						y = parseFloat (button.y);
					} else {
						switch (button.y) {
							case ControlPanel.POSITION_BOTTOM:
								y = device.height - button.sprite.height;;
								break;
							case ControlPanel.POSITION_TOP:
								y = 0;
								break;
							default:
								Debug.warn ('There y is no position by value ' + button.x);
						}
					}
				}

				if (centered) {
					button.x = ControlPanel.POSITION_CENTER;
					this.setupCenteredButtonPositions (device);
				}

				Debug.debug ('Setting up button positions to ' + x + 'x' + y);

				button.sprite.x = x;
				button.sprite.y = y;
			}
		}

		private function setupCenteredButtonPositions (device:*):void {
			var width:Number = 0;
			var buttons:Array = [
				this.finishbutton,
				this.pausebutton,
				this.playbutton,
				this.recordbutton,
				this.stopplaybutton,
				this.stoprecordbutton
			];

			for (var wi:int = 0, wl:int = buttons.length; wi < wl; wi++) {
				width += buttons [wi].sprite.width;
			}

			for (var xi:int = 0, xl:int = buttons.length; xi < xl; xi++) {
				var x:Number = 0;
				if (xi > 0) {
					x = buttons [xi - 1].sprite.x;
				}
				buttons [xi].sprite.x = ((device.width - width) / 2) + x;
			}
		}

		private function endMouseSetup ():void {
			if (this.currentSetup == ControlPanelSetup.PLAY_MOUSE) {
				this.setup (ControlPanelSetup.PLAY);
			}
		}

	}
}