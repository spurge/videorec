package se.klandestino.flash.videorec.events {

	import flash.events.Event;

	/**
	 *	Event subclass description.
	 *
	 *	@langversion ActionScript 3.0
	 *	@playerversion Flash 10.0
	 *
	 *	@author spurge
	 *	@since  6.09.2010
	 */
	public class ControlPanelEvent extends Event {

		//--------------------------------------
		// CLASS CONSTANTS
		//--------------------------------------

		public static const SETUP_CHANGE:String = 'setup change';

		//--------------------------------------
		//  CONSTRUCTOR
		//--------------------------------------

		/**
		 *	@constructor
		 */
		public function ControlPanelEvent (type:String, bubbles:Boolean = true, cancelable:Boolean = false) {
			super (type, bubbles, cancelable);
		}

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		public function get setup ():String {
			return this._setup;
		}

		public function set setup (setup:String):void {
			if (this._setup == null) {
				this._setup = setup;
			}
		}

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		override public function clone ():Event {
			return new ControlPanelEvent (type, bubbles, cancelable);
		}

		//--------------------------------------
		//  EVENT HANDLERS
		//--------------------------------------

		//--------------------------------------
		//  PRIVATE VARIABLES
		//--------------------------------------

		private var _setup:String;

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

	}
}