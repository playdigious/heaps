package hxd;

enum EventKind {
	EPush;
	ERelease;
	EMove;
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
	ECloudSaveLoaded;
	EWillEnterBackground;
	EDidEnterBackground;
	EWillEnterForeground;
	EDidEnterForeground;
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
	public var fingerId : Int;
	public var keyCode : Int;
	public var charCode : Int;
	public var wheelDelta : Float;
	#if hl
	public var saveName : hl.Bytes;
	public var saveData : hl.Bytes;
	#end

	public function new(k,x=0.,y=0., fid = -1) {
		kind = k;
		this.relX = x;
		this.relY = y;
		this.fingerId = fid;
	}

	public function toString() {
		return kind + "[" + Std.int(relX) + "," + Std.int(relY) + "]" + switch( kind ) {
		case EPush, ERelease, EReleaseOutside: ",button=" + button;
		case EMove, EOver, EOut, EFocus, EFocusLost, ECheck: "";
		case EWheel: ",wheelDelta=" + wheelDelta;
		case EKeyDown, EKeyUp: ",keyCode=" + keyCode;
		case ETextInput: ",charCode=" + charCode;
		#if hl
		case ECloudSaveLoaded : ",saveName=" + saveName + "\nwithData=" + saveData;
		#else
		case ECloudSaveLoaded: "";
		#end
		default:"";
		}
	}

}