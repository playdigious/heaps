package hxd;

enum EventKind {
	EPush;
	ERelease;
	EMove;
	EMultiGesture;
	EOver;
	EOut;
	EWheel;
	EFocus;
	EFocusLost;
	EKeyDown;
	EKeyUp;
	EReleaseOutside;
	ETextInput;
	/**
		Used to check if we are still on the interactive if no EMove was triggered this frame.
	**/
	ECheck;
	EWillEnterBackground;
	EDidEnterBackground;
	EWillEnterForeground;
	EDidEnterForeground;
	ELowMemoryWarning;
}

class Event {

	public var kind : EventKind;
	public var relX : Float;
	public var relY : Float;
	public var relZ : Float;
	/**
		Will propagate the event to other interactives that are below the current one.
	**/
	public var propagate : Bool;
	/**
		Will cancel the default behavior for this event as if it had happen outside of the interactive zone.
	**/
	public var cancel : Bool;
	public var button : Int = 0;
	public var touchId : Int;
	public var keyCode : Int;
	public var charCode : Int;
	public var wheelDelta : Float;
	public var fingerCount : Int;
	public var dx : Float;
	public var dy : Float;
	public var dTheta : Float;
	public var dDist : Float;

	public function new(k,x=0.,y=0.) {
		kind = k;
		this.relX = x;
		this.relY = y;
	}

	public function toString() {
		return kind + "[" + Std.int(relX) + "," + Std.int(relY) + "]" + switch( kind ) {
		case EPush, ERelease, EReleaseOutside: ",button=" + button;
		case EMove, EMultiGesture, EOver, EOut, EFocus, EFocusLost, ECheck: "";
		case EWheel: ",wheelDelta=" + wheelDelta;
		case EKeyDown, EKeyUp: ",keyCode=" + keyCode;
		case ETextInput: ",charCode=" + charCode;
		default:"";
		}
	}

}