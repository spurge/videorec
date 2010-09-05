package se.klandestino.flash.videorec.events {

	import flash.events.Event;

	/**
	 *	Event subclass description.
	 *
	 *	@langversion ActionScript 3.0
	 *	@playerversion Flash 10.0
	 *
	 *	@author spurge
	 *	@since  02.09.2010
	 */
	public class RecorderEvent extends Event {

		//--------------------------------------
		// CLASS CONSTANTS
		//--------------------------------------

		public static const ERROR_SECURITY:String = 'security error';
		public static const ERROR_STREAM_IO:String = 'stream i/o error'
		public static const NO_CAMERA:String = 'no camera';
		public static const NO_MICROPHONE:String = 'no microphone';
		public static const RECORD:String = 'record';
		public static const STOP:String = 'stop';

		//--------------------------------------
		//  CONSTRUCTOR
		//--------------------------------------

		/**
		 *	@constructor
		 */
		public function RecorderEvent (type:String, bubbles:Boolean = true, cancelable:Boolean = false) {
			super (type, bubbles, cancelable);
		}

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		override public function clone ():Event {
			return new RecorderEvent (type, bubbles, cancelable);
		}

		//--------------------------------------
		//  EVENT HANDLERS
		//--------------------------------------

		//--------------------------------------
		//  PRIVATE VARIABLES
		//--------------------------------------

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

	}
}