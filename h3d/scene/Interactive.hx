package h3d.scene;

class Interactive extends Object implements hxd.SceneEvents.Interactive {

	@:s public var shape : h3d.col.Collider;

	/**
		If several interactive conflicts, the preciseShape (if defined) can be used to distinguish between the two.
	**/
	@:s public var preciseShape : Null<h3d.col.Collider>;

	/**
		In case of conflicting shapes, usually the one in front of the camera is prioritized, unless you set an higher priority.
	**/
	@:s public var priority : Int;

	public var cursor(default,set) : hxd.Cursor;
	/**
		Set the default `cancel` mode (see `hxd.Event`), default to false.
	**/
	@:s public var cancelEvents : Bool = false;
	/**
		Set the default `propagate` mode (see `hxd.Event`), default to false.
	**/
	@:s public var propagateEvents : Bool = false;
	@:s public var enableRightButton : Bool;

	/**
		Is it required to find the best hit point in a complex mesh or any hit possible point will be enough (default = false, faster).
	**/
	@:s public var bestMatch : Bool;

	var scene : Scene;
	var mouseDownButton : Int = -1;

	@:allow(h3d.scene.Scene)
	var hitPoint = new h3d.Vector();

	public function new(shape, ?parent) {
		super(parent);
		this.shape = shape;
		cursor = Button;
	}

	override function onAdd() {
		this.scene = getScene();
		if( scene != null ) scene.addEventTarget(this);
		super.onAdd();
	}

	override function onRemove() {
		if( scene != null ) {
			scene.removeEventTarget(this);
			scene = null;
		}
		super.onRemove();
	}

	/**
		This can be called during or after a push event in order to prevent the release from triggering a click.
	**/
	public function preventClick() {
		mouseDownButton = -1;
	}

	@:noCompletion public function getInteractiveScene() : hxd.SceneEvents.InteractiveScene {
		return scene;
	}

	@:noCompletion public function handleEvent( e : hxd.Event ) {
		if( propagateEvents ) e.propagate = true;
		if( cancelEvents ) e.cancel = true;
		switch( e.kind ) {
		case EMove:
			onMove(e);
		case EPush:
			if( enableRightButton || e.button == 0 ) {
				mouseDownButton = e.button;
				onPush(e);
			}
		case ERelease:
			if( enableRightButton || e.button == 0 ) {
				onRelease(e);
				if( mouseDownButton == e.button )
					onClick(e);
			}
			mouseDownButton = -1;
		case EReleaseOutside:
			if( enableRightButton || e.button == 0 ) {
				e.kind = ERelease;
				onRelease(e);
				e.kind = EReleaseOutside;
			}
			mouseDownButton = -1;
		case EOver:
			onOver(e);
			if( !e.cancel && cursor != null )
				hxd.System.setCursor(cursor);
		case EOut:
			mouseDownButton = -1;
			onOut(e);
			if( !e.cancel )
				hxd.System.setCursor(Default);
		case EWheel:
			onWheel(e);
		case EFocusLost:
			onFocusLost(e);
		case EFocus:
			onFocus(e);
		case EKeyUp:
			onKeyUp(e);
		case EKeyDown:
			onKeyDown(e);
		case ECheck:
			onCheck(e);
		case ETextInput:
			onTextInput(e);
		case EWillEnterBackground:
		case EDidEnterBackground:
		case EWillEnterForeground:
		case EDidEnterForeground:
		}
	}

	function set_cursor(c) {
		this.cursor = c;
		if( isOver() && cursor != null )
			hxd.System.setCursor(cursor);
		return c;
	}

	public function focus() {
		if( scene == null || scene.events == null )
			return;
		scene.events.focus(this);
	}

	public function blur() {
		if( hasFocus() ) scene.events.blur();
	}

	public function isOver() {
		return scene != null && scene.events != null && @:privateAccess scene.events.currentOver == this;
	}

	public function hasFocus() {
		return scene != null && scene.events != null && @:privateAccess scene.events.currentFocus == this;
	}

	public dynamic function onOver( e : hxd.Event ) {
	}

	public dynamic function onOut( e : hxd.Event ) {
	}

	public dynamic function onPush( e : hxd.Event ) {
	}

	public dynamic function onRelease( e : hxd.Event ) {
	}

	public dynamic function onClick( e : hxd.Event ) {
	}

	public dynamic function onMove( e : hxd.Event ) {
	}

	public dynamic function onWheel( e : hxd.Event ) {
	}

	public dynamic function onFocus( e : hxd.Event ) {
	}

	public dynamic function onFocusLost( e : hxd.Event ) {
	}

	public dynamic function onKeyUp( e : hxd.Event ) {
	}

	public dynamic function onKeyDown( e : hxd.Event ) {
	}

	public dynamic function onCheck( e : hxd.Event ) {
	}

	public dynamic function onTextInput( e : hxd.Event ) {
	}

}
