package hxd;

#if hlsdl
import sdl.Cursor;
#elseif hldx
import dx.Cursor;
#end

@:enum abstract Platform(Int) {
	var IOS		= 0;
	var TV_OS	= 1;
	var Android	= 2;
	var WebGL	= 3;
	var PC		= 4;
	var Console	= 5;
	var FlashPlayer	= 6;
}

/*enum Platform {
	IOS;
	TV_OS;
	Android;
	WebGL;
	PC;
	Console;
	FlashPlayer;
}*/

enum SystemValue {
	IsTouch;
	IsWindowed;
	IsMobile;
}

//@:coreApi
class System {

	public static var width(get,never) : Int;
	public static var height(get, never) : Int;
	public static var lang(get, never) : String;
	public static var platform(get, never) : Platform;
	public static var screenDPI(get,never) : Float;
	public static var setCursor = setNativeCursor;
	public static var allowTimeout(get, set) : Bool;

	static var loopFunc : Void -> Void;
	static var dismissErrors = false;

	#if !usesys
	static var sentinel : hl.UI.Sentinel;
	#end

	#if hlsdl
	public static var appInBackground = false;
	#end

	// -- HL
	static var currentNativeCursor : hxd.Cursor = Default;
	static var cursorVisible = true;

	public static function getCurrentLoop() : Void -> Void {
		return loopFunc;
	}

	public static function setLoop( f : Void -> Void ) : Void {
		loopFunc = f;
	}

	static function mainLoop() : Bool {
		// process events
		#if hldx
		if( !dx.Loop.processEvents(@:privateAccess hxd.Stage.inst.onEvent) )
			return false;
		#elseif hlsdl
		if( !sdl.Sdl.processEvents(@:privateAccess hxd.Stage.inst.onEvent) )
			return false;
		#elseif usesys
		if( !haxe.System.emitEvents(@:privateAccess hxd.Stage.inst.event) )
			return false;
		#end

		// loop
		timeoutTick();
		if( loopFunc != null ) loopFunc();

		// present
		#if usesys
		haxe.System.present();
		#elseif hlsdl
		@:privateAccess hxd.Stage.inst.window.present();
		#end

		return true;
	}

	public static function start( init : Void -> Void ) : Void {
		#if usesys

		if( !haxe.System.init() ) return;
		@:privateAccess Stage.inst = new Stage("", haxe.System.width, haxe.System.height);
		init();

		#else
		var width = 800;
		var height = 600;
		var size = haxe.macro.Compiler.getDefine("windowSize");
		var title = haxe.macro.Compiler.getDefine("windowTitle");
		if( title == null )
			title = "";
		if( size != null ) {
			var p = size.split("x");
			width = Std.parseInt(p[0]);
			height = Std.parseInt(p[1]);
		}
		timeoutTick();
		#if hlsdl
			sdl.Sdl.init();
			@:privateAccess Stage.initChars();
			@:privateAccess Stage.inst = new Stage(title, get_width(), get_height());
			init();
		#elseif hldx
			@:privateAccess Stage.inst = new Stage(title, width, height);
			init();
		#else
			@:privateAccess Stage.inst = new Stage(title, width, height);
			init();
		#end
		#end

		timeoutTick();
		haxe.Timer.delay(runMainLoop, 0);
	}

	static function runMainLoop() {
		while( true ) {
			try {
				@:privateAccess haxe.MainLoop.tick();
				if( !mainLoop() ) break;
			} catch( e : Dynamic ) {
				reportError(e);
			}
		}
		Sys.exit(0);
	}

	public dynamic static function reportError( e : Dynamic ) {
		var stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack());
		var err = try Std.string(e) catch( _ : Dynamic ) "????";
		Sys.println(err + stack);
		#if !usesys
		if( dismissErrors )
			return;

		var arr = new Array();
		arr.push({ text : "Continue", callb : function() { }});
		arr.push({ text : "Dismiss all", callb : function() {
			dismissErrors = true;
		}});
		arr.push({ text : "Exit", callb : function() {
			Sys.exit(0);
		}});

		showInfoDialog("Uncaught Exception", err, arr, 2);
		#end
	}

#if !usesys

	/*
	Show informations with buttons in a native window 

	@param title the title of the window
	@param message the core message of the window
	@param button contains all the buttons of the window
	@param index the minimal button index to discard the information dialog
	*/
	public static function showInfoDialog(title : String, message : String, buttons : Array<{ text : String, callb : Void -> Void }>, index : Int)
	{
		var infoWindow = new hl.UI.WinLog(title, 500, 400);
		infoWindow.setTextContent(message);

		for(button in buttons)
		{
			var but = new hl.UI.Button(infoWindow, button.text);
			but.onClick = function() {
				hl.UI.stopLoop();
				if(button.callb != null)
					button.callb();
			} 
		}

		while( hl.UI.loop(true) - index < 0 )
			timeoutTick();
		infoWindow.destroy();
	}

#end

	public static function setNativeCursor( c : hxd.Cursor ) : Void {
		#if (hlsdl || hldx)
		if( c.equals(currentNativeCursor) )
			return;
		currentNativeCursor = c;
		if( c == Hide ) {
			cursorVisible = false;
			Cursor.show(false);
			return;
		}
		var cur : Cursor;
		switch( c ) {
		case Default:
			cur = Cursor.createSystem(Arrow);
		case Button:
			cur = Cursor.createSystem(Hand);
		case Move:
			cur = Cursor.createSystem(SizeALL);
		case TextInput:
			cur = Cursor.createSystem(IBeam);
		case Hide:
			throw "assert";
		case Custom(c):
			if( c.alloc == null ) {
				if( c.frames.length > 1 ) throw "Animated cursor not supported";
				var pixels = c.frames[0].getPixels();
				pixels.convert(BGRA);
				#if hlsdl
				var surf = sdl.Surface.fromBGRA(pixels.bytes, pixels.width, pixels.height);
				c.alloc = sdl.Cursor.create(surf, c.offsetX, c.offsetY);
				surf.free();
				#elseif hldx
				c.alloc = dx.Cursor.createCursor(pixels.width, pixels.height, pixels.bytes, c.offsetX, c.offsetY);
				#end
				pixels.dispose();
			}
			cur = c.alloc;
		}
		cur.set();
		if( !cursorVisible ) {
			cursorVisible = true;
			Cursor.show(true);
		}
		#end
	}
	
	@:hlNative("util","device_powerful") static function is_device_powerful() : Bool { return false; }

	public static function isDevicePowerful() : Bool {
		return is_device_powerful();
	}

	public static function getDeviceName() : String {
		#if usesys
		return haxe.System.name;
		#elseif hlsdl
		return "PC/" + sdl.Sdl.getDevices()[0];
		#elseif hldx
		return "PC/" + dx.Driver.getDeviceName();
		#else
		return "PC/Commandline";
		#end
	}

	public static function getDefaultFrameRate() : Float {
		return 60.;
	}

	/*
	If wantedFPS is equal or less than 0, the FPS lock is removed, else it will lock the FPS at wantedFPS
	*/
	public static function lockFPS(?wantedFPS:Int)
	{
		#if hlsdl
		sdl.Sdl.lockFPS(wantedFPS);
		#end
	}

	public static function getValue( s : SystemValue ) : Bool {
		return switch( s ) {
		#if !usesys
		case IsWindowed:
			return true;
		#end
		default:
			return false;
		}
	}

	public static function exit() : Void {
		try {
			Sys.exit(0);
		} catch( e : Dynamic ) {
			// access violation sometimes ?
			exit();
		}
	}

	@:hlNative("std","sys_locale") static function getLocale() : hl.Bytes { return null; }

	static var _lang : String;
	static function get_lang() : String {
		if( _lang == null ) {
			var str = @:privateAccess String.fromUCS2(getLocale());
			_lang = ~/[.@_-]/g.split(str)[0];
		}
		return _lang;
	}

	// getters

	#if usesys
	static function get_width() : Int return haxe.System.width;
	static function get_height() : Int return haxe.System.height;
	static function get_platform() : Platform return Console;
	#elseif hldx
	static function get_width() : Int return dx.Window.getScreenWidth();
	static function get_height() : Int return dx.Window.getScreenHeight();
	static function get_platform() : Platform return PC; // TODO : Xbox ?
	#elseif hlsdl
	static function get_width() : Int return sdl.Sdl.getScreenWidth();
	static function get_height() : Int return sdl.Sdl.getScreenHeight();
	static function get_platform() : Platform return sdl.Sdl.getPlatform(); // TODO : Xbox ?
	#else
	static function get_width() : Int return 800;
	static function get_height() : Int return 600;
	static function get_platform() : Platform return PC;
	#end

	static function get_screenDPI() : Int return 72; // TODO

	public static function timeoutTick() : Void @:privateAccess {
		#if !usesys
		sentinel.tick();
		#end
	}

	static function get_allowTimeout() @:privateAccess {
		#if (usesys || (haxe_ver < 4))
		return false;
		#else
		return !sentinel.pause;
		#end
	}

	static function set_allowTimeout(b) @:privateAccess {
		#if (usesys || (haxe_ver < 4))
		return false;
		#else
		return sentinel.pause = !b;
		#end
	}

	static function __init__() {
		#if !usesys
		hl.Api.setErrorHandler(function(e) reportError(e)); // initialization error
		sentinel = new hl.UI.Sentinel(30, function() throw "Program timeout (infinite loop?)");
		haxe.MainLoop.add(timeoutTick);
		#end
	}

}
