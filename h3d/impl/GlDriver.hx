package h3d.impl;
import h3d.impl.Driver;
import h3d.mat.Pass;
import h3d.mat.Stencil;
import h3d.mat.Data;

#if (js||cpp||hlsdl||usegl)

#if js
import js.html.Uint16Array;
import js.html.Uint8Array;
import js.html.Float32Array;
private typedef GL = js.html.webgl.GL;
private extern class GL2 extends js.html.webgl.GL {
	// webgl2
	function drawBuffers( buffers : Array<Int> ) : Void;
	static inline var RGBA16F = 0x881A;
	static inline var RGBA32F = 0x8814;
	static inline var ALPHA16F = 0x881C;
	static inline var ALPHA32F = 0x8816;
	static inline var RGBA8	   = 0x8058;
	static inline var BGRA 		 = 0x80E1;
	static inline var HALF_FLOAT = 0x140B;
}
private typedef Uniform = js.html.webgl.UniformLocation;
private typedef Program = js.html.webgl.Program;
private typedef GLShader = js.html.webgl.Shader;
private typedef Framebuffer = js.html.webgl.Framebuffer;
#elseif lime
import lime.graphics.opengl.GL;
private typedef Uniform = Dynamic;
private typedef Program = lime.graphics.opengl.GLProgram;
private typedef GLShader = lime.graphics.opengl.GLShader;
private typedef Framebuffer = lime.graphics.opengl.GLFramebuffer;
private typedef Uint16Array = lime.utils.UInt16Array;
private typedef Uint8Array = lime.utils.UInt8Array;
private typedef Float32Array = lime.utils.Float32Array;
#elseif nme
import nme.gl.GL;
private typedef Uniform = Dynamic;
private typedef Program = nme.gl.GLProgram;
private typedef GLShader = nme.gl.GLShader;
private typedef Framebuffer = nme.gl.Framebuffer;
private typedef Uint16Array = nme.utils.Int16Array;
private typedef Uint8Array = nme.utils.UInt8Array;
private typedef Float32Array = nme.utils.Float32Array;
#elseif hlsdl
import sdl.GL;
private typedef Uniform = sdl.GL.Uniform;
private typedef Program = sdl.GL.Program;
private typedef GLShader = sdl.GL.Shader;
private typedef Framebuffer = sdl.GL.Framebuffer;
private typedef Texture = h3d.impl.Driver.Texture;
private typedef Query = h3d.impl.Driver.Query;
private typedef VertexArray = sdl.GL.VertexArray;
#if cpp
private typedef Float32Array = Array<cpp.Float32>;
#end
#elseif usegl
import haxe.GLTypes;
private typedef Uniform = haxe.GLTypes.Uniform;
private typedef Program = haxe.GLTypes.Program;
private typedef GLShader = haxe.GLTypes.Shader;
private typedef Framebuffer = haxe.GLTypes.Framebuffer;
private typedef Texture = h3d.impl.Driver.Texture;
private typedef Query = h3d.impl.Driver.Query;
private typedef VertexArray = haxe.GLTypes.VertexArray;
#end

#if usegl
private typedef ShaderCompiler = haxe.GLTypes.ShaderCompiler;
#else
private typedef ShaderCompiler = hxsl.GlslOut;
#end

private class CompiledShader {
	public var s : GLShader;
	public var vertex : Bool;
	public var globals : Uniform;
	public var params : Uniform;
	public var textures : Array<Uniform>;
	public var cubeTextures : Array<Uniform>;
	public var shader : hxsl.RuntimeShader.RuntimeShaderData;
	public function new(s,vertex,shader) {
		this.s = s;
		this.vertex = vertex;
		this.shader = shader;
	}
}

private class CompiledAttribute {
	public var index : Int;
	public var type : Int;
	public var size : Int;
	public var offset : Int;
	public function new() {
	}
}

private class CompiledProgram {
	public var p : Program;
	public var vertex : CompiledShader;
	public var fragment : CompiledShader;
	public var stride : Int;
	public var attribNames : Array<String>;
	public var attribs : Array<CompiledAttribute>;
	public function new() {
	}
}

@:access(h3d.impl.Shader)
#if (cpp||hlsdl||usegl)
@:build(h3d.impl.MacroHelper.replaceGL())
#end
class GlDriver extends Driver {

	#if js
	var canvas : js.html.CanvasElement;
	var mrtExt : { function drawBuffersWEBGL( colors : Array<Int> ) : Void; };
	static var UID = 0;
	public var gl : GL2;
	#end

	#if (hlsdl||usegl)
	var commonVA : VertexArray;
	#end

	var commonFB : Framebuffer;
	var curAttribs : Int;
	var curShader : CompiledProgram;
	var curBuffer : h3d.Buffer;
	var curIndexBuffer : IndexBuffer;
	var curMatBits : Int;
	var curStOpBits : Int;
	var curStFrBits : Int;
	var curStBrBits : Int;
	var curStEnabled : Bool;
	var defStencil : Stencil;
	var programs : Map<Int, CompiledProgram>;
	var frame : Int;
	var lastActiveIndex : Int = 0;

	var bufferWidth : Int;
	var bufferHeight : Int;
	var curTarget : h3d.mat.Texture;
	var numTargets : Int;
	var curTargetFace : Int;
	var curTargetMip : Int;

	var debug : Bool;
	var glDebug : Bool;
	var boundTextures : Array<Texture> = [];
	var glES : Null<Float>;
	var shaderVersion : Null<Int>;
	var firstShader = true;

	var lowRes : Int = 0;

	public function new(antiAlias=0) {
		#if js
		canvas = @:privateAccess hxd.Stage.getInstance().canvas;
		var options = {alpha:false,antialias:antiAlias>0};
		gl = cast canvas.getContext("webgl2",options);
		if( gl == null )
			gl = cast canvas.getContextWebGL(options);
		if( gl == null ) throw "Could not acquire GL context";
		// debug if webgl_debug.js is included
		untyped if( __js__('typeof')(WebGLDebugUtils) != "undefined" ) {
			gl = untyped WebGLDebugUtils.makeDebugContext(gl);
			glDebug = true;
		}
		#if multidriver
		canvas.setAttribute("class", canvas.getAttribute("class") + " _id_" + (UID++));
		#end
		#end
		commonFB = gl.createFramebuffer();
		programs = new Map();
		curAttribs = 0;
		curMatBits = -1;
		defStencil = new Stencil();

		var v : String = gl.getParameter(GL.VERSION);
		var reg = ~/ES ([0-9]+\.[0-9]+)/;
		if( reg.match(v) )
			glES = Std.parseFloat(reg.matched(1));

		#if !js
		// if( glES == null ) {
		// 	commonVA = gl.createVertexArray();
		// 	gl.bindVertexArray( commonVA );
		// }
		#end

		var reg = ~/[0-9]+\.[0-9]+/;
		var v : String = gl.getParameter(GL.SHADING_LANGUAGE_VERSION);
		if( reg.match(v) )
			shaderVersion = Math.round( Std.parseFloat(reg.matched(0)) * 100 );

		#if !js
		gl.enable(GL.TEXTURE_CUBE_MAP_SEAMLESS);
		gl.pixelStorei(GL.PACK_ALIGNMENT, 1);
		gl.pixelStorei(GL.UNPACK_ALIGNMENT, 1);
		gl.finish(); // prevent glError() on first bufferData
		#end
	}

	override function logImpl( str : String ) {
		#if js
		untyped console.log(str);
		#else
		Sys.println(str);
		#end
	}

	override function setDebug(d) {
		this.debug = d;
	}

	override function begin(frame) {
		this.frame = frame;
		resetStream();
		#if cpp
		curAttribs = 0;
		curMatBits = -1;
		#end
		gl.useProgram(null);
		curShader = null;
		curBuffer = null;
	}

	override function getShaderInputNames() {
		return curShader.attribNames;
	}

	override function getNativeShaderCode( shader : hxsl.RuntimeShader ) {
		return "// vertex:\n" + ShaderCompiler.compile(shader.vertex.data) + "// fragment:\n" + ShaderCompiler.compile(shader.fragment.data);
	}

	override public function getDriverName(details:Bool) {
		var render = gl.getParameter(GL.RENDERER);
		if( details )
			render += " GLv" + gl.getParameter(GL.VERSION);
		else
			render = render.split("/").shift(); // GeForce reports "/PCIe/SSE2" extension
		#if js
		render = render.split("WebGL ").join("");
		#end
		return "OpenGL "+render;
	}

	function compileShader( glout : ShaderCompiler, shader : hxsl.RuntimeShader.RuntimeShaderData ) {
		var type = shader.vertex ? GL.VERTEX_SHADER : GL.FRAGMENT_SHADER;
		var s = gl.createShader(type);
		if( shader.code == null ){
			shader.code = glout.run(shader.data);
			shader.data.funs = null;
		}
		gl.shaderSource(s, shader.code);
		gl.compileShader(s);
		var log = gl.getShaderInfoLog(s);
		if ( gl.getShaderParameter(s, GL.COMPILE_STATUS) != cast 1 ) {
			var log = gl.getShaderInfoLog(s);
			var lid = Std.parseInt(log.substr(9));
			var line = lid == null ? null : shader.code.split("\n")[lid - 1];
			if( line == null ) line = "" else line = "(" + StringTools.trim(line) + ")";
			var codeLines = shader.code.split("\n");
			for( i in 0...codeLines.length )
				codeLines[i] = (i+1) + "\t" + codeLines[i];
			throw "An error occurred compiling the shaders: " + log + line+"\n\n"+codeLines.join("\n");
		}
		return new CompiledShader(s, shader.vertex, shader);
	}

	function initShader( p : CompiledProgram, s : CompiledShader, shader : hxsl.RuntimeShader.RuntimeShaderData ) {
		var prefix = s.vertex ? "vertex" : "fragment";
		s.globals = gl.getUniformLocation(p.p, prefix + "Globals");
		s.params = gl.getUniformLocation(p.p, prefix + "Params");
		s.textures = [for( i in 0...shader.textures2DCount ) gl.getUniformLocation(p.p, prefix + "Textures[" + i + "]")];
		s.cubeTextures = [for( i in 0...shader.texturesCubeCount ) gl.getUniformLocation(p.p, prefix + "TexturesCube[" + i + "]")];
	}

	override function selectShader( shader : hxsl.RuntimeShader ) {
		var p = programs.get(shader.id);
		if( p == null ) {
			p = new CompiledProgram();
			var glout = new ShaderCompiler();
			glout.glES = glES;
			glout.version = shaderVersion;
			p.vertex = compileShader(glout,shader.vertex);
			p.fragment = compileShader(glout,shader.fragment);

			p.p = gl.createProgram();
			#if (hlsdl || usegl)
			if( glES == null ) {
				var outCount = 0;
				for( v in shader.fragment.data.vars )
					switch( v.kind ) {
					case Output:
						gl.bindFragDataLocation(p.p, outCount++, glout.varNames.exists(v.id) ? glout.varNames.get(v.id) : v.name);
					default:
					}
			}
			#end
			gl.attachShader(p.p, p.vertex.s);
			gl.attachShader(p.p, p.fragment.s);
			var log = null;
			try {
				gl.linkProgram(p.p);
				if( gl.getProgramParameter(p.p, GL.LINK_STATUS) != cast 1 )
					log = gl.getProgramInfoLog(p.p);
			} catch( e : Dynamic ) {
				throw "Shader linkage error: "+Std.string(e)+" ("+getDriverName(false)+")";
			}
			gl.deleteShader(p.vertex.s);
			gl.deleteShader(p.fragment.s);
			if( log != null ) {
				#if js
				gl.deleteProgram(p.p);
				#end
				#if hlsdl
				/*
					Tentative patch on some driver that report an higher shader version that it's allowed to use.
				*/
				if( log == "" && shaderVersion > 130 && firstShader ) {
					shaderVersion -= 10;
					return selectShader(shader);
				}
				#end
				throw "Program linkage failure: "+log+"\nVertex=\n"+glout.run(shader.vertex.data)+"\n\nFragment=\n"+glout.run(shader.fragment.data);
			}
			firstShader = false;
			initShader(p, p.vertex, shader.vertex);
			initShader(p, p.fragment, shader.fragment);
			p.attribNames = [];
			p.attribs = [];
			p.stride = 0;
			for( v in shader.vertex.data.vars )
				switch( v.kind ) {
				case Input:
					var t = GL.FLOAT;
					var size = switch( v.type ) {
					case TVec(n, _): n;
					case TBytes(n): t = GL.BYTE; n;
					case TFloat: 1;
					default: throw "assert " + v.type;
					}
					var index = gl.getAttribLocation(p.p, glout.varNames.exists(v.id) ? glout.varNames.get(v.id) : v.name);
					if( index < 0 ) {
						p.stride += size;
						continue;
					}
					var a = new CompiledAttribute();
					a.type = t;
					a.size = size;
					a.index = index;
					a.offset = p.stride;
					p.attribs.push(a);
					p.attribNames.push(v.name);
					p.stride += size;
				default:
				}
			programs.set(shader.id, p);
		}
		if( curShader == p ) return false;

		gl.useProgram(p.p);
		for( i in curAttribs...p.attribs.length ) {
			gl.enableVertexAttribArray(i);
			curAttribs++;
		}
		while( curAttribs > p.attribs.length )
			gl.disableVertexAttribArray(--curAttribs);
		curShader = p;
		curBuffer = null;
		for( i in 0...boundTextures.length )
			boundTextures[i] = null;
		return true;
	}

	override function uploadShaderBuffers( buf : h3d.shader.Buffers, which : h3d.shader.Buffers.BufferKind ) {
		uploadBuffer(curShader.vertex, buf.vertex, which);
		uploadBuffer(curShader.fragment, buf.fragment, which);
	}

	function uploadBuffer( s : CompiledShader, buf : h3d.shader.Buffers.ShaderBuffers, which : h3d.shader.Buffers.BufferKind ) {
		switch( which ) {
		case Globals:
			if( s.globals != null ) {
				#if hl
				gl.uniform4fv(s.globals, streamData(hl.Bytes.getArray(buf.globals.toData()), 0, s.shader.globalsSize * 16), 0, s.shader.globalsSize * 4);
				#else
				var a = buf.globals.subarray(0, s.shader.globalsSize * 4);
				gl.uniform4fv(s.globals, a);
				#end
			}
		case Params:
			if( s.params != null ) {
				#if hl
				gl.uniform4fv(s.params, streamData(hl.Bytes.getArray(buf.params.toData()), 0, s.shader.paramsSize * 16), 0, s.shader.paramsSize * 4);
				#else
				var a = buf.params.subarray(0, s.shader.paramsSize * 4);
				gl.uniform4fv(s.params, a);
				#end
			}
		case Textures:
			var tcount = s.textures.length;
			for( i in 0...s.textures.length + s.cubeTextures.length ) {
				var t = buf.tex[i];
				var isCube = i >= tcount;
				if( t == null || t.isDisposed() ) {
					if( isCube ) {
						t = h3d.mat.Texture.defaultCubeTexture();
					} else {
						var color = h3d.mat.Defaults.loadingTextureColor;
						t = h3d.mat.Texture.fromColor(color, (color >>> 24) / 255);
					}
				}
				if( t != null && t.t == null && t.realloc != null ) {
					t.alloc();
					t.realloc();
				}
				t.lastFrame = frame;

				var pt = isCube ? s.cubeTextures[i - tcount] : s.textures[i];
				if( pt == null ) continue;
				if( boundTextures[i] == t.t ) continue;
				boundTextures[i] = t.t;

				#if multidriver
				if( t.t.driver != this )
					throw "Invalid texture context";
				#end

				var mode = isCube ? GL.TEXTURE_CUBE_MAP : GL.TEXTURE_2D;
				gl.activeTexture(GL.TEXTURE0 + i);
				gl.uniform1i(pt, i);
				gl.bindTexture(mode, t.t.t);
				lastActiveIndex = i;

				var mip = Type.enumIndex(t.mipMap);
				var filter = Type.enumIndex(t.filter);
				var wrap = Type.enumIndex(t.wrap);
				var bits = mip | (filter << 3) | (wrap << 6);
				if( bits != t.t.bits ) {
					t.t.bits = bits;
					var flags = TFILTERS[mip][filter];
					gl.texParameteri(mode, GL.TEXTURE_MAG_FILTER, flags[0]);
					gl.texParameteri(mode, GL.TEXTURE_MIN_FILTER, flags[1]);
					var w = TWRAP[wrap];
					gl.texParameteri(mode, GL.TEXTURE_WRAP_S, w);
					gl.texParameteri(mode, GL.TEXTURE_WRAP_T, w);
				}
			}
		}
	}

	override function selectMaterial( pass : Pass ) {
		selectMaterialBits(@:privateAccess pass.bits);
		var s = defStencil;
		if( pass.stencil == null ) {
			if( curStEnabled ) {
				gl.disable(GL.STENCIL_TEST);
				curStEnabled = false;
			}
		} else {
			s = pass.stencil;
			if( !curStEnabled ) {
				gl.enable(GL.STENCIL_TEST);
				curStEnabled = true;
			}
		}
		@:privateAccess selectStencilBits(s.opBits, s.frontRefBits, s.backRefBits);
		// TODO : Blend Op value sync
	}

	function selectMaterialBits( bits : Int ) {
		var diff = bits ^ curMatBits;
		if( curMatBits < 0 ) diff = -1;
		if( diff == 0 )
			return;
		if( diff & Pass.culling_mask != 0 ) {
			var cull = Pass.getCulling(bits);
			if( cull == 0 )
				gl.disable(GL.CULL_FACE);
			else {
				if( curMatBits < 0 || Pass.getCulling(curMatBits) == 0 )
					gl.enable(GL.CULL_FACE);
				gl.cullFace(FACES[cull]);
			}
		}
		if( diff & (Pass.blendSrc_mask | Pass.blendDst_mask | Pass.blendAlphaSrc_mask | Pass.blendAlphaDst_mask) != 0 ) {
			var csrc = Pass.getBlendSrc(bits);
			var cdst = Pass.getBlendDst(bits);
			var asrc = Pass.getBlendAlphaSrc(bits);
			var adst = Pass.getBlendAlphaDst(bits);
			if( csrc == asrc && cdst == adst ) {
				if( csrc == 0 && cdst == 1 )
					gl.disable(GL.BLEND);
				else {
					if( curMatBits < 0 || (Pass.getBlendSrc(curMatBits) == 0 && Pass.getBlendDst(curMatBits) == 1) ) gl.enable(GL.BLEND);
					gl.blendFunc(BLEND[csrc], BLEND[cdst]);
				}
			} else {
				if( curMatBits < 0 || (Pass.getBlendSrc(curMatBits) == 0 && Pass.getBlendDst(curMatBits) == 1) ) gl.enable(GL.BLEND);
				gl.blendFuncSeparate(BLEND[csrc], BLEND[cdst], BLEND[asrc], BLEND[adst]);
			}
		}
		if( diff & (Pass.blendOp_mask | Pass.blendAlphaOp_mask) != 0 ) {
			var cop = Pass.getBlendOp(bits);
			var aop = Pass.getBlendAlphaOp(bits);
			if( cop == aop ) {
				#if (nme || openfl)
				if( OP[cop] != GL.FUNC_ADD )
					throw "blendEquation() disable atm (crash)";
				#else
				gl.blendEquation(OP[cop]);
				#end
			}
			else
				gl.blendEquationSeparate(OP[cop], OP[aop]);
		}
		if( diff & Pass.depthWrite_mask != 0 )
			gl.depthMask(Pass.getDepthWrite(bits) != 0);
		if( diff & Pass.depthTest_mask != 0 ) {
			var cmp = Pass.getDepthTest(bits);
			if( cmp == 0 )
				gl.disable(GL.DEPTH_TEST);
			else {
				if( curMatBits < 0 || Pass.getDepthTest(curMatBits) == 0 ) gl.enable(GL.DEPTH_TEST);
				gl.depthFunc(COMPARE[cmp]);
			}
		}
		if( diff & Pass.colorMask_mask != 0 ) {
			var m = Pass.getColorMask(bits);
			gl.colorMask(m & 1 != 0, m & 2 != 0, m & 4 != 0, m & 8 != 0);
		}
		curMatBits = bits;
	}

	function selectStencilBits( opBits : Int, frBits : Int, brBits : Int ) {
		var diffOp = opBits ^ curStOpBits;
		var diffFr = frBits ^ curStFrBits;
		var diffBr = brBits ^ curStBrBits;

		if ( (diffOp | diffFr | diffBr) == 0 ) return;

		if( diffOp & (Stencil.frontSTfail_mask | Stencil.frontDPfail_mask | Stencil.frontDPpass_mask) != 0 ) {
			gl.stencilOpSeparate(
				FACES[Type.enumIndex(Front)],
				STENCIL_OP[Stencil.getFrontSTfail(opBits)],
				STENCIL_OP[Stencil.getFrontDPfail(opBits)],
				STENCIL_OP[Stencil.getFrontDPpass(opBits)]);
		}

		if( diffOp & (Stencil.backSTfail_mask | Stencil.backDPfail_mask | Stencil.backDPpass_mask) != 0 ) {
			gl.stencilOpSeparate(
				FACES[Type.enumIndex(Back)],
				STENCIL_OP[Stencil.getBackSTfail(opBits)],
				STENCIL_OP[Stencil.getBackDPfail(opBits)],
				STENCIL_OP[Stencil.getBackDPpass(opBits)]);
		}

		if( (diffOp & Stencil.frontTest_mask) | (diffFr & (Stencil.frontRef_mask | Stencil.frontReadMask_mask)) != 0 ) {
			gl.stencilFuncSeparate(
				FACES[Type.enumIndex(Front)],
				COMPARE[Stencil.getFrontTest(opBits)],
				Stencil.getFrontRef(frBits),
				Stencil.getFrontReadMask(frBits));
		}

		if( (diffOp & Stencil.backTest_mask) | (diffBr & (Stencil.backRef_mask | Stencil.backReadMask_mask)) != 0 ) {
			gl.stencilFuncSeparate(
				FACES[Type.enumIndex(Back)],
				COMPARE[Stencil.getBackTest(opBits)],
				Stencil.getBackRef(brBits),
				Stencil.getBackReadMask(brBits));
		}

		if( diffFr & Stencil.frontWriteMask_mask != 0 )
			gl.stencilMaskSeparate(FACES[Type.enumIndex(Front)], Stencil.getFrontWriteMask(frBits));

		if( diffBr & Stencil.backWriteMask_mask != 0 )
			gl.stencilMaskSeparate(FACES[Type.enumIndex(Back)], Stencil.getBackWriteMask(brBits));

		curStOpBits = opBits;
		curStFrBits = frBits;
		curStBrBits = brBits;
	}

	override function clear( ?color : h3d.Vector, ?depth : Float, ?stencil : Int ) {
		var bits = 0;
		if( color != null ) {
			gl.colorMask(true, true, true, true);
			if( curMatBits >= 0 ) curMatBits |= Pass.colorMask_mask;
			gl.clearColor(color.r, color.g, color.b, color.a);
			bits |= GL.COLOR_BUFFER_BIT;
		}
		if( depth != null ) {
			gl.depthMask(true);
			if( curMatBits >= 0 ) curMatBits |= Pass.depthWrite_mask;
			gl.clearDepth(depth);
			bits |= GL.DEPTH_BUFFER_BIT;
		}
		if( stencil != null ) {
			// reset stencyl mask when we allow to change it
			@:privateAccess selectStencilBits(defStencil.opBits, defStencil.frontRefBits, defStencil.backRefBits);
			gl.clearStencil(stencil);
			bits |= GL.STENCIL_BUFFER_BIT;
		}
		if( bits != 0 ) gl.clear(bits);
		if( curTarget != null ) curTarget.flags.set(WasCleared);
	}

	override function resize(width, height, lowRes : Int = 0) {
		#if js
		// prevent infinite grow if pixelRatio != 1
		if( canvas.style.width == "" ) {
			canvas.style.width = Std.int(width / js.Browser.window.devicePixelRatio)+"px";
			canvas.style.height = Std.int(height / js.Browser.window.devicePixelRatio)+"px";
		}
		canvas.width = width;
		canvas.height = height;
		#elseif cpp
		// resize window
		#end
		bufferWidth = width;
		bufferHeight = height;
		this.lowRes = lowRes;
		gl.viewport(0, 0, width, height);

		@:privateAccess if( defaultDepth != null ) {
			disposeDepthBuffer(defaultDepth);
			defaultDepth.width = this.bufferWidth >> this.lowRes;
			defaultDepth.height = this.bufferHeight >> this.lowRes;
			defaultDepth.b = allocDepthBuffer(defaultDepth);
		}
	}

	function getChannels( t : Texture ) {
		return switch( t.internalFmt ) {
		case GL2.RGBA32F, GL2.RGBA16F: GL.RGBA;
		case GL2.ALPHA16F, GL2.ALPHA32F: GL.ALPHA;
		case GL2.RGBA8: GL2.BGRA;
		case GL.RGBA: GL.RGBA;
		case GL.ALPHA: GL.ALPHA;
		default: throw "Invalid format " + t.internalFmt;
		}
	}

	override function isSupportedFormat( fmt : h3d.mat.Data.TextureFormat ) {
		return switch( fmt ) {
		case RGBA, ALPHA8: true;
		case RGBA16F, RGBA32F, ALPHA16F, ALPHA32F: hasFeature(FloatTextures);
		default: false;
		}
	}

	override function allocTexture( t : h3d.mat.Texture ) : Texture {
		var tt = gl.createTexture();
		var bind = t.flags.has(Cube) ? GL.TEXTURE_CUBE_MAP : GL.TEXTURE_2D;
		var tt : Texture = { t : tt, width : t.width, height : t.height, internalFmt : GL.RGBA, pixelFmt : GL.UNSIGNED_BYTE, bits : -1, bind : bind #if multidriver, driver : this #end };
		switch( t.format ) {
		case RGBA:
			// default
		case ALPHA8:
			tt.internalFmt = GL.ALPHA;
		case RGBA32F if( hasFeature(FloatTextures) ):
			tt.internalFmt = GL2.RGBA32F;
			tt.pixelFmt = GL.FLOAT;
		case RGBA16F if( hasFeature(FloatTextures) ):
			tt.pixelFmt = GL2.HALF_FLOAT;
			tt.internalFmt = GL2.RGBA16F;
		case ALPHA16F if( hasFeature(FloatTextures) ):
			tt.pixelFmt = GL2.HALF_FLOAT;
			tt.internalFmt = GL2.ALPHA16F;
		case ALPHA32F if( hasFeature(FloatTextures) ):
			tt.pixelFmt = GL.FLOAT;
			tt.internalFmt = GL2.ALPHA32F;
		case BGRA:
			tt.internalFmt = GL2.RGBA8;
		default:
			throw "Unsupported texture format "+t.format;
		}
		t.lastFrame = frame;
		t.flags.unset(WasCleared);
		gl.bindTexture(bind, tt.t);
		var outOfMem = false;
		if( t.flags.has(Cube) ) {
			for( i in 0...6 ) {
				gl.texImage2D(CUBE_FACES[i], 0, tt.internalFmt, tt.width, tt.height, 0, getChannels(tt), tt.pixelFmt, null);
				if( gl.getError() == GL.OUT_OF_MEMORY ) {
					outOfMem = true;
					break;
				}
			}
		} else {
			gl.texImage2D(bind, 0, tt.internalFmt, tt.width, tt.height, 0, getChannels(tt), tt.pixelFmt, null);
			if( gl.getError() == GL.OUT_OF_MEMORY )
				outOfMem = true;
		}
		restoreBind();

		if( outOfMem ) {
			gl.deleteTexture(tt.t);
			return null;
		}

		return tt;
	}

	override function allocCompressedTexture( t : h3d.mat.Texture ) : Texture {
		var tt = gl.createTexture();
                var bind = t.flags.has(Cube) ? GL.TEXTURE_CUBE_MAP : GL.TEXTURE_2D;
		var tt : Texture = { t : tt, width : t.width, height : t.height, internalFmt : GL.COMPRESSED_RGB8_ETC1, pixelFmt : GL.RGB, bits : -1, bind : bind };
		switch( t.format ) {
		case GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG:
			tt.internalFmt = GL.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;
		case GL_COMPRESSED_RGB8_ETC1:
			tt.internalFmt = GL.COMPRESSED_RGB8_ETC1;
		case GL_COMPRESSED_RGB8_ETC2:
			tt.internalFmt = GL.COMPRESSED_RGB8_ETC2;
		case GL_COMPRESSED_RGBA_ASTC_5x5:
			tt.internalFmt = GL.COMPRESSED_RGBA_ASTC_5x5;
		case GL_COMPRESSED_RGBA_ASTC_6x6:
			tt.internalFmt = GL.COMPRESSED_RGBA_ASTC_6x6;
		default:
			throw "Unsupported compressed texture format "+t.format;
		}
		t.lastFrame = frame;
		t.flags.unset(WasCleared);
		/*var bind = t.flags.has(Cube) ? GL.TEXTURE_CUBE_MAP : GL.TEXTURE_2D;
		gl.bindTexture(bind, tt.t);
		var outOfMem = false;
		if( t.flags.has(Cube) ) {
			for( i in 0...6 ) {
				gl.compressedTexImage2D(CUBE_FACES[i], 0, tt.internalFmt, tt.width, tt.height, 0, 0, null);
				if( gl.getError() == GL.OUT_OF_MEMORY ) {
					outOfMem = true;
					break;
				}
			}
		} else {
			gl.compressedTexImage2D(bind, 0, tt.internalFmt, tt.width, tt.height, 0, 0, null);
			if( gl.getError() == GL.OUT_OF_MEMORY )
				outOfMem = true;
		}
		restoreBind();

		if( outOfMem ) {
			gl.deleteTexture(tt.t);
			return null;
		}*/

		return tt;
	}

	function restoreBind() {
		var t = boundTextures[lastActiveIndex];
		if( t == null )
			gl.bindTexture(GL.TEXTURE_2D, null);
		else
			gl.bindTexture(t.bind, t.t);
	}

	override function allocDepthBuffer( b : h3d.mat.DepthBuffer ) : DepthBuffer {
		var r = gl.createRenderbuffer();
		gl.bindRenderbuffer(GL.RENDERBUFFER, r);
		gl.renderbufferStorage(GL.RENDERBUFFER, #if hl GL.DEPTH_COMPONENT24 #else GL.DEPTH_COMPONENT16 #end, b.width, b.height);
		gl.bindRenderbuffer(GL.RENDERBUFFER, null);
		return { r : r #if multidriver, driver : this #end };
	}

	override function disposeDepthBuffer( b : h3d.mat.DepthBuffer ) {
		@:privateAccess if( b.b != null && b.b.r != null ) {
			gl.deleteRenderbuffer(b.b.r);
			b.b = null;
		}
	}

	var defaultDepth : h3d.mat.DepthBuffer;

	override function getDefaultDepthBuffer() : h3d.mat.DepthBuffer {
		if( defaultDepth != null )
			return defaultDepth;
		defaultDepth = new h3d.mat.DepthBuffer(0, 0);
		@:privateAccess {
			defaultDepth.width = this.bufferWidth >> lowRes;
			defaultDepth.height = this.bufferHeight >> lowRes;
			defaultDepth.b = allocDepthBuffer(defaultDepth);
		}
		return defaultDepth;
	}

	override function allocVertexes( m : ManagedBuffer ) : VertexBuffer {
		var b = gl.createBuffer();
		gl.bindBuffer(GL.ARRAY_BUFFER, b);
		if( m.size * m.stride == 0 ) throw "assert";
		#if js
		gl.bufferData(GL.ARRAY_BUFFER, m.size * m.stride * 4, m.flags.has(Dynamic) ? GL.DYNAMIC_DRAW : GL.STATIC_DRAW);
		#elseif hl
		gl.bufferDataSize(GL.ARRAY_BUFFER, m.size * m.stride * 4, m.flags.has(Dynamic) ? GL.DYNAMIC_DRAW : GL.STATIC_DRAW);
		#else
		var tmp = new Uint8Array(m.size * m.stride * 4);
		gl.bufferData(GL.ARRAY_BUFFER, tmp, m.flags.has(Dynamic) ? GL.DYNAMIC_DRAW : GL.STATIC_DRAW);
		#end
		var outOfMem = gl.getError() == GL.OUT_OF_MEMORY;
		gl.bindBuffer(GL.ARRAY_BUFFER, null);
		if( outOfMem ) {
			gl.deleteBuffer(b);
			return null;
		}
		return { b : b, stride : m.stride #if multidriver, driver : this #end };
	}

	override function allocIndexes( count : Int ) : IndexBuffer {
		var b = gl.createBuffer();
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, b);
		#if js
		gl.bufferData(GL.ELEMENT_ARRAY_BUFFER, count * 2, GL.STATIC_DRAW);
		#elseif hl
		gl.bufferDataSize(GL.ELEMENT_ARRAY_BUFFER, count * 2, GL.STATIC_DRAW);
		#else
		var tmp = new Uint16Array(count);
		gl.bufferData(GL.ELEMENT_ARRAY_BUFFER, tmp, GL.STATIC_DRAW);
		#end
		var outOfMem = gl.getError() == GL.OUT_OF_MEMORY;
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		curIndexBuffer = null;
		if( outOfMem ) {
			gl.deleteBuffer(b);
			return null;
		}
		return b;
	}

	override function disposeTexture( t : h3d.mat.Texture ) {
		var tt = t.t;
		if( tt == null ) return;
		t.t = null;
		for( i in 0...boundTextures.length )
			if( boundTextures[i] == tt )
				boundTextures[i] = null;
		gl.deleteTexture(tt.t);
	}

	override function disposeIndexes( i : IndexBuffer ) {
		gl.deleteBuffer(i);
	}

	override function disposeVertexes( v : VertexBuffer ) {
		gl.deleteBuffer(v.b);
	}

	override function generateMipMaps( t : h3d.mat.Texture ) {
		var bind = t.flags.has(Cube) ? GL.TEXTURE_CUBE_MAP : GL.TEXTURE_2D;
		gl.bindTexture(bind, t.t.t);
		gl.generateMipmap(bind);
		restoreBind();
	}

	override function uploadTextureBitmap( t : h3d.mat.Texture, bmp : hxd.BitmapData, mipLevel : Int, side : Int ) {
	#if (hxcpp || hl)
		var pixels = bmp.getPixels();
		uploadTexturePixels(t, pixels, mipLevel, side);
		pixels.dispose();
	#else
		if( t.format != RGBA || t.flags.has(Cube) ) {
			var pixels = bmp.getPixels();
			uploadTexturePixels(t, pixels, mipLevel, side);
			pixels.dispose();
		} else {
			var img = bmp.toNative();
			gl.bindTexture(GL.TEXTURE_2D, t.t.t);
			#if js
			gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 1);
			#end
			gl.texImage2D(GL.TEXTURE_2D, mipLevel, t.t.internalFmt, getChannels(t.t), t.t.pixelFmt, img.getImageData(0, 0, bmp.width, bmp.height));
			restoreBind();
		}
	#end
	}

	#if !hl
	inline static function bytesToUint8Array( b : haxe.io.Bytes ) : Uint8Array {
		#if (lime && !js)
		return new Uint8Array(b);
		#else
		return new Uint8Array(b.getData());
		#end
	}
	#end

	/*
		GL async model create crashes if the GC free the memory that we send it.
		Instead, we will copy the data into a temp location before uploading.
	*/

	static inline var STREAM_POS = #if hl 0 #else 1 #end;
	#if hl

	var streamKeep : Array<{ f : Int, b : hl.Bytes }> = [];
	var streamBytes : hl.Bytes;
	var streamLen : Int;
	var streamPos : Int;

	function expandStream(needed:Int) {
		GL.finish();

		// too much data in our tmp buffer, let's flush it
		if( streamPos > (needed >> 1) && needed > 16 << 20 ) {
			needed -= streamPos;
			streamPos = 0;
			if( needed < streamLen )
				return;
		}

		var newLen = streamLen == 0 ? 0x10000 : streamLen;
		while( newLen < needed )
			newLen = (newLen * 3) >> 1;
		var newBytes = new hl.Bytes(newLen);
		if( streamPos > 0 )
			newBytes.blit(0, streamBytes, 0, streamPos);
		streamLen = newLen;
		if( streamBytes != null ) streamKeep.push({ f : frame, b : streamBytes });
		streamBytes = newBytes;
	}

	#end

	function resetStream() {
		#if hl
		streamPos = 0;
		// keep during 2 frames
		while( streamKeep.length > 0 && streamKeep[0].f < frame - 1 ) streamKeep.shift();
		#end
	}

	inline function streamData(data, pos:Int, length:Int) {
		#if hl
		var needed = streamPos + length;
		var total = (needed + 7) & ~7; // align on 8 bytes
		if( total > streamLen ) expandStream(total);
		streamBytes.blit(streamPos, data, pos, length);
		data = streamBytes.offset(streamPos);
		streamPos = total;
		#end
		return data;
	}

	override function uploadTexturePixels( t : h3d.mat.Texture, pixels : hxd.Pixels, mipLevel : Int, side : Int ) {
		var cubic = t.flags.has(Cube);
		var bind = cubic ? GL.TEXTURE_CUBE_MAP : GL.TEXTURE_2D;
		var face = cubic ? CUBE_FACES[side] : GL.TEXTURE_2D;
		gl.bindTexture(bind, t.t.t);
		pixels.convert(t.format);
		#if hl
		pixels.setFlip(!cubic);
		gl.texImage2D(face, mipLevel, t.t.internalFmt, pixels.width, pixels.height, 0, getChannels(t.t), t.t.pixelFmt, streamData(pixels.bytes.getData(),pixels.offset,pixels.width*pixels.height*4));
		#elseif lime
		pixels.setFlip(!cubic);
		gl.texImage2D(face, mipLevel, t.t.internalFmt, pixels.width, pixels.height, 0, getChannels(t.t), t.t.pixelFmt, bytesToUint8Array(pixels.bytes));
		#else
		gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, cubic ? 0 : 1);
		gl.texImage2D(face, mipLevel, t.t.internalFmt, pixels.width, pixels.height, 0, getChannels(t.t), t.t.pixelFmt, bytesToUint8Array(pixels.bytes));
		#end
		restoreBind();
	}

	override function uploadTextureCompressed( t : h3d.mat.Texture, bytes  : haxe.io.Bytes, width : Int, height : Int, mipLevel : Int, side : Int ) {
		var bind = GL.TEXTURE_2D;
		var face = GL.TEXTURE_2D;
		if (width==0) width = 1;
		if (height==0) height = 1;
		gl.bindTexture(bind, t.t.t);
		#if hl
		gl.compressedTexImage2D(face, mipLevel, t.t.internalFmt, width, height, 0, bytes.length, streamData(bytes.getData(),0,bytes.length));
		#elseif lime
		gl.compressedTexImage2D(face, mipLevel, t.t.internalFmt, width, height, 0, bytes.length, bytesToUint8Array(bytes));
		#else
		gl.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, cubic ? 0 : 1);
		gl.compressedTexImage2D(face, mipLevel, t.t.internalFmt, width, height, 0, bytes.length, bytesToUint8Array(bytes));
		#end
		restoreBind();
	}

	override function uploadVertexBuffer( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : hxd.FloatBuffer, bufPos : Int ) {
		var stride : Int = v.stride;
		gl.bindBuffer(GL.ARRAY_BUFFER, v.b);
		#if hl
		var data = #if hl hl.Bytes.getArray(buf.getNative()) #else buf.getNative() #end;
		gl.bufferSubData(GL.ARRAY_BUFFER, startVertex * stride * 4, streamData(data,bufPos * 4,vertexCount * stride * 4), bufPos * 4 * STREAM_POS, vertexCount * stride * 4);
		#else
		var buf : Float32Array = buf.getNative();
		var sub = new Float32Array(buf.buffer, bufPos * 4, vertexCount * stride);
		gl.bufferSubData(GL.ARRAY_BUFFER, startVertex * stride * 4, sub);
		#end
		gl.bindBuffer(GL.ARRAY_BUFFER, null);
	}

	override function uploadVertexBytes( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		var stride : Int = v.stride;
		gl.bindBuffer(GL.ARRAY_BUFFER, v.b);
		#if hl
		gl.bufferSubData(GL.ARRAY_BUFFER, startVertex * stride * 4, streamData(buf.getData(),bufPos * 4,vertexCount * stride * 4), bufPos * 4 * STREAM_POS, vertexCount * stride * 4);
		#else
		var buf = bytesToUint8Array(buf);
		var sub = new Uint8Array(buf.buffer, bufPos * 4, vertexCount * stride * 4);
		gl.bufferSubData(GL.ARRAY_BUFFER, startVertex * stride * 4, sub);
		#end
		gl.bindBuffer(GL.ARRAY_BUFFER, null);
	}

	override function uploadIndexBuffer( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : hxd.IndexBuffer, bufPos : Int ) {
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, i);
		#if hl
		var data = #if hl hl.Bytes.getArray(buf.getNative()) #else buf.getNative() #end;
		gl.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, startIndice * 2, streamData(data,bufPos*2,indiceCount*2), bufPos * 2 * STREAM_POS, indiceCount * 2);
		#else
		var buf = new Uint16Array(buf.getNative());
		var sub = new Uint16Array(buf.buffer, bufPos * 2, indiceCount);
		gl.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, startIndice * 2, sub);
		#end
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		curIndexBuffer = null;
	}

	override function uploadIndexBytes( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : haxe.io.Bytes , bufPos : Int ) {
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, i);
		#if hl
		gl.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, startIndice * 2, streamData(buf.getData(),bufPos * 2, indiceCount * 2), bufPos * 2 * STREAM_POS, indiceCount * 2);
		#else
		var buf = bytesToUint8Array(buf);
		var sub = new Uint8Array(buf.buffer, bufPos * 2, indiceCount * 2);
		gl.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, startIndice * 2, sub);
		#end
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		curIndexBuffer = null;
	}

	override function selectBuffer( v : h3d.Buffer ) {

		if( v == curBuffer )
			return;
		if( curBuffer != null && v.buffer == curBuffer.buffer && v.buffer.flags.has(RawFormat) == curBuffer.flags.has(RawFormat) ) {
			curBuffer = v;
			return;
		}

		if( curShader == null )
			throw "No shader selected";
		curBuffer = v;

		var m = @:privateAccess v.buffer.vbuf;
		if( m.stride < curShader.stride )
			throw "Buffer stride (" + m.stride + ") and shader stride (" + curShader.stride + ") mismatch";

		#if multidriver
		if( m.driver != this )
			throw "Invalid buffer context";
		#end
		gl.bindBuffer(GL.ARRAY_BUFFER, m.b);

		if( v.flags.has(RawFormat) ) {
			for( a in curShader.attribs ) {
				var pos = a.offset;
				gl.vertexAttribPointer(a.index, a.size, a.type, false, m.stride * 4, pos * 4);
			}
		} else {
			var offset = 8;
			for( i in 0...curShader.attribs.length ) {
				var a = curShader.attribs[i];
				var pos;
				switch( curShader.attribNames[i] ) {
				case "position":
					pos = 0;
				case "normal":
					if( m.stride < 6 ) throw "Buffer is missing NORMAL data, set it to RAW format ?" #if debug + @:privateAccess v.allocPos #end;
					pos = 3;
				case "uv":
					if( m.stride < 8 ) throw "Buffer is missing UV data, set it to RAW format ?" #if debug + @:privateAccess v.allocPos #end;
					pos = 6;
				case s:
					pos = offset;
					offset += a.size;
					if( offset > m.stride ) throw "Buffer is missing '"+s+"' data, set it to RAW format ?" #if debug + @:privateAccess v.allocPos #end;
				}
				gl.vertexAttribPointer(a.index, a.size, a.type, false, m.stride * 4, pos * 4);
			}
		}
	}

	override function selectMultiBuffers( buffers : Buffer.BufferOffset ) {
		for( a in curShader.attribs ) {
			gl.bindBuffer(GL.ARRAY_BUFFER, @:privateAccess buffers.buffer.buffer.vbuf.b);
			gl.vertexAttribPointer(a.index, a.size, a.type, false, buffers.buffer.buffer.stride * 4, buffers.offset * 4);
			buffers = buffers.next;
		}
		curBuffer = null;
	}

	override function draw( ibuf : IndexBuffer, startIndex : Int, ntriangles : Int ) {
		if( ibuf != curIndexBuffer ) {
			curIndexBuffer = ibuf;
			gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ibuf);
		}
		gl.drawElements(GL.TRIANGLES, ntriangles * 3, GL.UNSIGNED_SHORT, startIndex * 2);
	}

	override function end() {
		// no gl finish or flush !
	}

	override function present() {
		#if hlsdl
		@:privateAccess hxd.Stage.inst.window.present();
		#elseif usesys
		haxe.System.present();
		#end
	}

	override function isDisposed() {
		#if (nme || openfl) //lime ??
		return false;
		#else
		return gl.isContextLost();
		#end
	}

	override function setRenderZone( x : Int, y : Int, width : Int, height : Int ) {
		if( x == 0 && y == 0 && width < 0 && height < 0 )
			gl.disable(GL.SCISSOR_TEST);
		else {
			gl.enable(GL.SCISSOR_TEST);
			var th = curTarget == null ? bufferHeight : curTarget.height;
			gl.scissor(x, th - (y + height), width, height);
		}
	}

	function setDrawBuffers( k : Int ) {
		#if js
		if( glES >= 3 )
			gl.drawBuffers(CBUFFERS[k]);
		else if( mrtExt != null )
			mrtExt.drawBuffersWEBGL(CBUFFERS[k]);
		#elseif (hlsdl || usegl)
		gl.drawBuffers(k, CBUFFERS);
		#end
	}

	inline function unbindTargets() {
		if( curTarget != null && numTargets > 1 ) {
			while( numTargets > 1 )
				gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0 + (--numTargets), GL.TEXTURE_2D, null, 0);
			setDrawBuffers(1);
		}
	}

	override function capturePixels(tex:h3d.mat.Texture, face:Int, mipLevel:Int) {
		var old = curTarget;
		var oldCount = numTargets;
		var oldFace = curTargetFace;
		var oldMip = curTargetMip;
		numTargets = 1;
		setRenderTarget(tex, face, mipLevel);
		var pixels = hxd.Pixels.alloc(tex.width >> mipLevel, tex.height >> mipLevel, RGBA);
		captureRenderBuffer(pixels);
		setRenderTarget(old, oldFace, oldMip);
		if( oldCount > 1 ) {
			setDrawBuffers(oldCount);
			numTargets = oldCount;
		}
		return pixels;
	}

	override function setRenderTarget( tex : h3d.mat.Texture, face = 0, mipLevel = 0 ) {
		unbindTargets();
		curTarget = tex;
		if( tex == null ) {
			gl.bindFramebuffer(GL.FRAMEBUFFER, null);
			gl.viewport(0, 0, bufferWidth, bufferHeight);
			return;
		}

		if( tex.depthBuffer != null && (tex.depthBuffer.width != tex.width || tex.depthBuffer.height != tex.height) )
			throw "Invalid depth buffer size : does not match render target size";

		if( glES == 1 && mipLevel > 0 ) throw "Cannot render to mipLevel in WebGL1, use upload() instead";

		if( tex.t == null )
			tex.alloc();

		if( tex.flags.has(MipMapped) && !tex.flags.has(WasCleared) ) {
			var bind = tex.flags.has(Cube) ? GL.TEXTURE_CUBE_MAP : GL.TEXTURE_2D;
			gl.bindTexture(bind, tex.t.t);
			gl.generateMipmap(bind);
			restoreBind();
		}

		tex.flags.set(WasCleared); // once we draw to, do not clear again
		tex.lastFrame = frame;
		curTargetFace = face;
		curTargetMip = mipLevel;
		#if multidriver
		if( tex.t.driver != this )
			throw "Invalid texture context";
		#end
		gl.bindFramebuffer(GL.FRAMEBUFFER, commonFB);
		gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, tex.flags.has(Cube) ? CUBE_FACES[face] : GL.TEXTURE_2D, tex.t.t, mipLevel);
		if( tex.depthBuffer != null )
			gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, @:privateAccess tex.depthBuffer.b.r);
		else
			gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, null);
		gl.viewport(0, 0, tex.width >> mipLevel, tex.height >> mipLevel);
		for( i in 0...boundTextures.length )
			boundTextures[i] = null;

		#if js
		if( glDebug ) {
			var code = gl.checkFramebufferStatus(GL.FRAMEBUFFER);
			if( code != GL.FRAMEBUFFER_COMPLETE )
				throw "Invalid frame buffer: "+code;
		}
		#end
	}

	override function setRenderTargets( textures : Array<h3d.mat.Texture> ) {
		unbindTargets();
		setRenderTarget(textures[0]);
		if( textures.length < 2 )
			return;
		numTargets = textures.length;
		for( i in 1...textures.length ) {
			var tex = textures[i];
			if( tex.t == null )
				tex.alloc();
			#if multidriver
			if( tex.t.driver != this )
				throw "Invalid texture context";
			#end
			gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0 + i, GL.TEXTURE_2D, tex.t.t, 0);
			tex.lastFrame = frame;
			tex.flags.set(WasCleared); // once we draw to, do not clear again
		}
		setDrawBuffers(textures.length);
	}

	override function init( onCreate : Bool -> Void, forceSoftware = false ) {
		#if js
		var ready = false;
		// wait until all assets have properly load
		if( js.Browser.document.readyState == 'complete' )
			haxe.Timer.delay(onCreate.bind(false), 1);
		else
			js.Browser.window.addEventListener("load", function(_) {
				if( !ready ) {
					ready = true;
					onCreate(false);
				}
			});
		#else
		haxe.Timer.delay(onCreate.bind(false), 1);
		#end
	}

	override function hasFeature( f : Feature ) : Bool {
		return switch( f ) {
		#if hl

		case StandardDerivatives, FloatTextures, MultipleRenderTargets, Queries:
			true;

		#else

		case StandardDerivatives, MultipleRenderTargets if( glES >= 3 ):
			true;

		case FloatTextures if( glES >= 3 ):
			gl.getExtension('EXT_color_buffer_float') != null && gl.getExtension("OES_texture_float_linear") != null; // allow render to 16f/32f textures (not standard in webgl 2)

		case StandardDerivatives:
			gl.getExtension('OES_standard_derivatives') != null;

		case FloatTextures:
			gl.getExtension('OES_texture_float') != null && gl.getExtension('OES_texture_float_linear') != null &&
			gl.getExtension('OES_texture_half_float') != null && gl.getExtension('OES_texture_half_float_linear') != null;

		case MultipleRenderTargets:
			mrtExt != null || (mrtExt = gl.getExtension('WEBGL_draw_buffers')) != null;

		case Queries:
			false;

		#end
		case HardwareAccelerated:
			true;
		case AllocDepthBuffer:
			true;
		}
	}

	override function captureRenderBuffer( pixels : hxd.Pixels ) {
		if( curTarget == null )
			throw "Can't capture main render buffer in GL";
		#if (js || hl)
		gl.readPixels(0, 0, pixels.width, pixels.height, GL.RGBA, GL.UNSIGNED_BYTE, @:privateAccess pixels.bytes.b);
		@:privateAccess pixels.innerFormat = RGBA;
		pixels.flags.set(FlipY);
		#end
	}

	#if hl

	override function allocQuery(kind:QueryKind) {
		return { q : GL.createQuery(), kind : kind };
	}

	override function deleteQuery( q : Query ) {
		GL.deleteQuery(q.q);
		q.q = null;
	}

	override function beginQuery( q : Query ) {
		switch( q.kind ) {
		case TimeStamp:
			throw "use endQuery() for timestamp queries";
		case Samples:
			GL.beginQuery(GL.SAMPLES_PASSED, q.q);
		}
	}

	override function endQuery( q : Query ) {
		switch( q.kind ) {
		case TimeStamp:
			GL.queryCounter(q.q, GL.TIMESTAMP);
		case Samples:
			GL.endQuery(GL.SAMPLES_PASSED);
		}
	}

	override function queryResultAvailable(q:Query) {
		return GL.queryResultAvailable(q.q);
	}

	override function queryResult(q:Query) {
		return GL.queryResult(q.q);
	}

	#end

	static var TFILTERS = [
		[[GL.NEAREST,GL.NEAREST],[GL.LINEAR,GL.LINEAR]],
		[[GL.NEAREST,GL.NEAREST_MIPMAP_NEAREST],[GL.LINEAR,GL.LINEAR_MIPMAP_NEAREST]],
		[[GL.NEAREST,GL.NEAREST_MIPMAP_LINEAR],[GL.LINEAR,GL.LINEAR_MIPMAP_LINEAR]],
	];

	static var TWRAP = [
		GL.CLAMP_TO_EDGE,
		GL.REPEAT,
	];

	static var FACES = [
		0,
		GL.FRONT,
		GL.BACK,
		GL.FRONT_AND_BACK,
	];

	static var BLEND = [
		GL.ONE,
		GL.ZERO,
		GL.SRC_ALPHA,
		GL.SRC_COLOR,
		GL.DST_ALPHA,
		GL.DST_COLOR,
		GL.ONE_MINUS_SRC_ALPHA,
		GL.ONE_MINUS_SRC_COLOR,
		GL.ONE_MINUS_DST_ALPHA,
		GL.ONE_MINUS_DST_COLOR,
		GL.CONSTANT_COLOR,
		GL.CONSTANT_ALPHA,
		GL.ONE_MINUS_CONSTANT_COLOR,
		GL.ONE_MINUS_CONSTANT_ALPHA,
		GL.SRC_ALPHA_SATURATE,
	];

	static var COMPARE = [
		GL.ALWAYS,
		GL.NEVER,
		GL.EQUAL,
		GL.NOTEQUAL,
		GL.GREATER,
		GL.GEQUAL,
		GL.LESS,
		GL.LEQUAL,
	];

	static var STENCIL_OP = [
		GL.KEEP,
		GL.ZERO,
		GL.REPLACE,
		GL.INCR,
		GL.INCR_WRAP,
		GL.DECR,
		GL.DECR_WRAP,
		GL.INVERT,
	];

	static var OP = [
		GL.FUNC_ADD,
		GL.FUNC_SUBTRACT,
		GL.FUNC_REVERSE_SUBTRACT
	];

	static var CUBE_FACES = [
		GL.TEXTURE_CUBE_MAP_POSITIVE_X,
		GL.TEXTURE_CUBE_MAP_NEGATIVE_X,
		GL.TEXTURE_CUBE_MAP_POSITIVE_Y,
		GL.TEXTURE_CUBE_MAP_NEGATIVE_Y,
		GL.TEXTURE_CUBE_MAP_POSITIVE_Z,
		GL.TEXTURE_CUBE_MAP_NEGATIVE_Z,
	];

	static var CBUFFERS =
		#if (hlsdl || usegl)
			hl.Bytes.getArray([for( i in 0...32 ) GL.COLOR_ATTACHMENT0 + i]);
		#elseif js
			[for( i in 0...32 ) [for( k in 0...i ) GL.COLOR_ATTACHMENT0 + k]];
		#else
			null;
		#end

}

#end
