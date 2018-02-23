package h3d.mat;
import h3d.mat.Data;

#if mobile
// KTX loading code, loosely based on https://github.com/snowkit/ktx-format

import haxe.io.Bytes;
import haxe.io.BytesData;
import haxe.io.BytesInput;
import haxe.io.UInt8Array;
import haxe.io.UInt16Array;
import haxe.io.UInt32Array;

typedef KTXMipLevel = {
    var imageSize:Int;
    var faces:Array<BytesData>;
    var width:Int;
    var height:Int;
    var depth:Int;
};

typedef KTXData = {
    var glType:Int;
    var glTypeSize:Int;
    var glFormat:Int;
    var glInternalFormat:Int;
    var glBaseInternalFormat:Int;
    var pixelWidth:Int;
    var pixelHeight:Int;
    var pixelDepth:Int;
    var numberOfArrayElements:Int;
    var numberOfFaces:Int;
    var numberOfMipmapLevels:Int;
    var bytesOfKeyValueData:Int;
    var mips:Array<KTXMipLevel>;
    var compressed:Bool;
    var generateMips:Bool;
    var glTarget:Int;
    var dimensions:Int;
};
#end

@:allow(h3d)
class Texture {

	static var UID = 0;

	/**
		The default texture color format
	**/
	public static var nativeFormat(default,never) : TextureFormat =
		#if flash
			BGRA
		#else
			RGBA // OpenGL, WebGL
		#end;

	/**
		Tells if the Driver requires y-flipping the texture pixels before uploading.
	**/
	public static inline var nativeFlip = 	#if (hlsdl||usegl) true
											#elseif (openfl) false
											#elseif (lime && (cpp || neko || nodejs)) true
											#else false #end;

	var t : h3d.impl.Driver.Texture;
	var mem : h3d.impl.MemoryManager;
	#if debug
	var allocPos : h3d.impl.AllocPos;
	#end
	public var id(default, null) : Int;
	public var name(default, null) : String;
	public var width(default, null) : Int;
	public var height(default, null) : Int;
	public var flags(default, null) : haxe.EnumFlags<TextureFlags>;
	public var format(default, null) : TextureFormat;

	var lastFrame : Int;
	var bits : Int;
	var waitLoads : Array<Void -> Void>;
	public var mipMap(default,set) : MipMap;
	public var filter(default,set) : Filter;
	public var wrap(default, set) : Wrap;

	/**
		If this callback is set, the texture can be re-allocated when the 3D context has been lost or when
		it's been free because of lack of memory.
	**/
	public var realloc : Void -> Void;

	/**
		When the texture is used as render target, tells which depth buffer will be used.
		If set to null, depth testing is disabled.
	**/
	public var depthBuffer : DepthBuffer;


	/**
		Loading path for debug
	**/
	public var resPath : String;

	public function new(w, h, ?flags : Array<TextureFlags>, ?format : TextureFormat, ?allocPos : h3d.impl.AllocPos, ?resPath : String ) {
		#if !noEngine
		var engine = h3d.Engine.getCurrent();
		this.mem = engine.mem;
		#end
		if( format == null ) format = nativeFormat;
		this.id = ++UID;
		this.format = format;
		this.flags = new haxe.EnumFlags();
		this.resPath = resPath;
		if( flags != null )
			for( f in flags )
				this.flags.set(f);

		var tw = 1, th = 1;
		while( tw < w ) tw <<= 1;
		while( th < h) th <<= 1;
		if( tw != w || th != h )
			this.flags.set(IsNPOT);

		// make the texture disposable if we're out of memory
		// this can be disabled after allocation by reseting realloc
		if( this.flags.has(Target) ) realloc = function() { };

		this.width = w;
		this.height = h;
		this.mipMap = this.flags.has(MipMapped) ? Nearest : None;
		this.filter = Linear;
		this.wrap = Clamp;
		bits &= 0x7FFF;
		#if debug
		this.allocPos = allocPos;
		#end
		if( !this.flags.has(NoAlloc) ) alloc();
	}

	public function alloc() {
		if( t == null ) {
			if (this.flags.has(CompressedTexture))
				mem.allocCompressedTexture(this);
			else
				mem.allocTexture(this);
		}
	}

	public function clone( ?allocPos : h3d.impl.AllocPos ) {
		var old = lastFrame;
		preventAutoDispose();
		var t = new Texture(width, height, null, format, allocPos);
		h3d.pass.Copy.run(this, t);
		lastFrame = old;
		return t;
	}

	/**
		In case of out of GPU memory, textures that hasn't been used for a long time will be disposed.
		Calling this will make this texture not considered for auto disposal.
	**/
	public function preventAutoDispose() {
		lastFrame = 0x7FFFFFFF;
	}

	/**
		Some textures might take some time to load. You can check flags.has(Loading)
		or add a waitLoad callback which will get called either immediately if the texture is already loaded
		or when loading is complete.
	**/
	public function waitLoad( f : Void -> Void ) {
		if( !flags.has(Loading) ) {
			f();
			return;
		}
		if( waitLoads == null ) waitLoads = [];
		waitLoads.push(f);
	}

	function toString() {
		var str = name;
		if( name == null ) {
			str = "Texture_" + id;
			#if debug
			if( allocPos != null ) str += "(" + allocPos.className+":" + allocPos.lineNumber + ")";
			#end
		}
		return str+"("+width+"x"+height+")";
	}

	public function setName(n) {
		name = n;
	}

	function set_mipMap(m:MipMap) {
		bits = (bits & ~(3 << 0)) | (Type.enumIndex(m) << 0);
		return mipMap = m;
	}

	function set_filter(f:Filter) {
		bits = (bits & ~(3 << 3)) | (Type.enumIndex(f) << 3);
		return filter = f;
	}

	function set_wrap(w:Wrap) {
		bits = (bits & ~(3 << 6)) | (Type.enumIndex(w) << 6);
		return wrap = w;
	}

	public inline function isDisposed() {
		return t == null && realloc == null;
	}

	public function resize(width, height) {
		dispose();

		var tw = 1, th = 1;
		while( tw < width ) tw <<= 1;
		while( th < height ) th <<= 1;
		if( tw != width || th != height )
			this.flags.set(IsNPOT);
		else
			this.flags.unset(IsNPOT);

		this.width = width;
		this.height = height;

		if( !flags.has(NoAlloc) )
			alloc();
	}

	public function clear( color : Int, alpha = 1. ) {
		alloc();
		var p = hxd.Pixels.alloc(width, height, nativeFormat);
		var k = 0;
		var b = color & 0xFF, g = (color >> 8) & 0xFF, r = (color >> 16) & 0xFF, a = Std.int(alpha * 255);
		if( a < 0 ) a = 0 else if( a > 255 ) a = 255;
		switch( nativeFormat ) {
		case RGBA:
		case BGRA:
			// flip b/r
			var tmp = r;
			r = b;
			b = tmp;
		default:
			throw "TODO";
		}
		for( i in 0...width * height ) {
			p.bytes.set(k++,r);
			p.bytes.set(k++,g);
			p.bytes.set(k++,b);
			p.bytes.set(k++,a);
		}
		if( nativeFlip ) p.flags.set(FlipY);
		for( i in 0...(flags.has(Cube) ? 6 : 1) )
			uploadPixels(p, 0, i);
		p.dispose();
	}

	inline function checkSize(width, height, mip) {
		var thisW = this.width >> mip;
		thisW = (thisW < 1 ? 1 : thisW);
		var thisH = this.height >> mip;
		thisH = (thisH < 1 ? 1 : thisH);
		if ((width != 1 || height != 1) && ( width != thisW || height != thisH ))
			throw "Invalid upload size : " + width + "x" + height + " should be " + thisW + "x" + thisH;
	}

	function checkMipMapGen(mipLevel,side) {
		if( mipLevel == 0 && flags.has(MipMapped) && !flags.has(ManualMipMapGen) && (!flags.has(Cube) || side == 5) )
			mem.driver.generateMipMaps(this);
	}

	public function uploadCompressedData( bytes : haxe.io.Bytes, width, height, mipLevel = 0, side = 0) {
		alloc();
		checkSize(width, height, mipLevel);
		mem.driver.uploadTextureCompressed(this, bytes, width, height, mipLevel, side);
		flags.set(WasCleared);
	}

	public function uploadBitmap( bmp : hxd.BitmapData, mipLevel = 0, side = 0 ) {
		alloc();
		checkSize(bmp.width, bmp.height, mipLevel);
		mem.driver.uploadTextureBitmap(this, bmp, mipLevel, side);
		flags.set(WasCleared);
		checkMipMapGen(mipLevel, side);
	}

	public function uploadPixels( pixels : hxd.Pixels, mipLevel = 0, side = 0 ) {
		alloc();
		checkSize(pixels.width, pixels.height, mipLevel);
		mem.driver.uploadTexturePixels(this, pixels, mipLevel, side);
		flags.set(WasCleared);
		checkMipMapGen(mipLevel, side);
	}

	public function dispose() {
		if( t != null ) {
			mem.deleteTexture(this);
			#if debug
			this.allocPos.customParams = ["#DISPOSED"];
			#end
		}
	}

	/**
		Swap two textures, this is an immediate operation.
		BEWARE : if the texture is a cached image (hxd.res.Image), the swap will affect the cache!
	**/
	public function swapTexture( t : Texture ) {
		if( isDisposed() || t.isDisposed() )
			throw "One of the two texture is disposed";
		var tmp = this.t;
		this.t = t.t;
		t.t = tmp;
	}

	/**
		Downloads the current texture data from the GPU.
		Beware, this is a very slow operation that shouldn't be done during rendering.
	**/
	public function capturePixels( face = 0, mipLevel = 0 ) : hxd.Pixels {
		#if flash
		if( flags.has(Cube) ) throw "Can't capture cube texture on this platform";
		if( face != 0 || mipLevel != 0 ) throw "Can't capture face/mipLevel on this platform";
		return capturePixelsFlash();
		#else
		var old = lastFrame;
		preventAutoDispose();
		var pix = mem.driver.capturePixels(this, face, mipLevel);
		lastFrame = old;
		return pix;
		#end
	}

	#if flash
	function capturePixelsFlash() {
		var e = h3d.Engine.getCurrent();
		var oldW = e.width, oldH = e.height;
		var oldF = filter, oldM = mipMap, oldWrap = wrap;
		if( e.width < width || e.height < height )
			e.resize(width, height);
		e.driver.clear(new h3d.Vector(0, 0, 0, 0),1,0);
		var s2d = new h2d.Scene();
		var b = new h2d.Bitmap(h2d.Tile.fromTexture(this), s2d);
		var shader = new h3d.shader.AlphaChannel();
		b.addShader(shader); // erase alpha
		b.blendMode = None;

		mipMap = None;

		s2d.render(e);

		var pixels = hxd.Pixels.alloc(width, height, ARGB);
		e.driver.captureRenderBuffer(pixels);

		shader.showAlpha = true;
		s2d.render(e); // render only alpha channel
		var alpha = hxd.Pixels.alloc(width, height, ARGB);
		e.driver.captureRenderBuffer(alpha);
		var alphaPos = hxd.Pixels.getChannelOffset(alpha.format, A);
		var redPos = hxd.Pixels.getChannelOffset(alpha.format, R);
		var bpp = hxd.Pixels.bytesPerPixel(alpha.format);
		for( y in 0...height ) {
			var p = y * width * bpp;
			for( x in 0...width ) {
				pixels.bytes.set(p + alphaPos, alpha.bytes.get(p + redPos)); // copy alpha value only
				p += bpp;
			}
		}
		alpha.dispose();
		pixels.flags.unset(AlphaPremultiplied);

		if( e.width != oldW || e.height != oldH )
			e.resize(oldW, oldH);
		e.driver.clear(new h3d.Vector(0, 0, 0, 0));
		s2d.dispose();

		filter = oldF;
		mipMap = oldM;
		wrap = oldWrap;
		return pixels;
	}
	#end

#if mobile
	public function loadRes(resPath : String)
	{
		var bytes = null;
		try {
			bytes = hxd.Res.load(resPath).entry.getBytes();
		} catch ( e: hxd.res.NotFound) { trace("loadRes failed resPath="+ resPath); }
	    	var GL_TEXTURE_1D:Int      = 0x0DE0;
	    	var GL_TEXTURE_2D:Int      = 0x0DE1;
	    	var GL_TEXTURE_3D:Int      = 0x806F;
		var GL_TEXTURE_CUBE_MAP:Int = 0x8513;
		var fin:BytesInput = new BytesInput(bytes);

	        var id = UInt8Array.fromBytes(bytes, 0, 12);
	        if (id[0] != 0xAB && id[1] != 0x4B && id[2] != 0x54 && id[3] != 0x58 &&
	            id[4] != 0x20 && id[5] != 0x31 && id[6] != 0x31 && id[7] != 0xBB &&
	            id[8] != 0x0D && id[9] != 0x0A && id[10] != 0x1A && id[11] != 0x0A)
	            return null;
	        fin.position = 12;

	        // check endianess of data
		var bigEndian = false;
	        var e = fin.readInt32();
	        if (e == 0x04030201)
        	    bigEndian = false;
	        else 
	            bigEndian = true;

		var ktx:KTXData = {
        	    glType:                 fin.readInt32(),
	            glTypeSize:             fin.readInt32(),
	            glFormat:               fin.readInt32(),
	            glInternalFormat:       fin.readInt32(),
	            glBaseInternalFormat:   fin.readInt32(),
	            pixelWidth:             fin.readInt32(),
	            pixelHeight:            fin.readInt32(),
	            pixelDepth:             fin.readInt32(),
	            numberOfArrayElements:  fin.readInt32(),
	            numberOfFaces:          fin.readInt32(),
	            numberOfMipmapLevels:   fin.readInt32(),
	            bytesOfKeyValueData:    fin.readInt32(),
	            mips: [],
            
	            compressed: false,
	            generateMips: false,
	            glTarget: GL_TEXTURE_1D,
	            dimensions: 1
	        };

	        fin.position += ktx.bytesOfKeyValueData;

	        // run some validation
	        if (ktx.glTypeSize != 1 && ktx.glTypeSize != 2 && ktx.glTypeSize != 4)
        	    throw "[KTX] Unsupported glTypeSize \""+ktx.glTypeSize+"\".";
        
	        if (ktx.glType == 0 || ktx.glFormat == 0) {
	            if (ktx.glType + ktx.glFormat != 0)
        	        throw "[KTX] glType and glFormat must be zero. Broken compression?";
	            ktx.compressed = true;
	        }

	        if ((ktx.pixelWidth == 0) || (ktx.pixelDepth > 0 && ktx.pixelHeight == 0))
	            throw "[KTX] texture must have width or height if it has depth.";

	        if (ktx.pixelHeight > 0) {
	            ktx.dimensions = 2;
	            ktx.glTarget = GL_TEXTURE_2D;
	        }
	        if (ktx.pixelDepth > 0) {
	            ktx.dimensions = 3;
	            ktx.glTarget = GL_TEXTURE_3D;
	        }
	        if (ktx.numberOfFaces == 6) {
	            if (ktx.dimensions == 2)
	                ktx.glTarget = GL_TEXTURE_CUBE_MAP;
	            else
	                throw "[KTX] cubemap needs 2D faces.";
	        }
	        else if (ktx.numberOfFaces != 1)
        	    throw "[KTX] numberOfFaces must be either 1 or 6";

	        if (ktx.numberOfMipmapLevels == 0) {
	            ktx.generateMips = true;
	            ktx.numberOfMipmapLevels = 1;
	        }

	        // make sane defaults
	        var pxDepth = ktx.pixelDepth > 0 ? ktx.pixelDepth : 1;
	        var pxHeight = ktx.pixelHeight > 0 ? ktx.pixelHeight : 1;
	        var pxWidth = ktx.pixelWidth > 0 ? ktx.pixelWidth : 1;
        
	        for (i in 0...ktx.numberOfMipmapLevels) {
	            var ml:KTXMipLevel = {
        	        imageSize: fin.readInt32(),
	                faces: [],
	                width: Std.int(Math.max(1, ktx.pixelWidth >> i)),
	                height: Std.int(Math.max(1, ktx.pixelHeight >> i)),
	                depth: Std.int(Math.max(1, ktx.pixelDepth >> i))
	            }
            
	            var imageSizeRounded = (ml.imageSize + 3)&~3;

	            for (k in 0...ktx.numberOfFaces) {
        	        var data = Bytes.alloc(imageSizeRounded);
                	fin.readFullBytes(data, 0, imageSizeRounded);
	                ml.faces.push(data.getData());

	                if (ktx.numberOfArrayElements > 0) {
        	            if (ktx.dimensions == 2) ml.height = ktx.numberOfArrayElements;
                	    if (ktx.dimensions == 3) ml.depth = ktx.numberOfArrayElements;
	                }
	            }

	            ktx.mips.push(ml);
	        }

		var format = GL_COMPRESSED_RGB8_ETC1;
		switch (ktx.glInternalFormat) {
			case 0x8C00: format = GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG;
			case 0x8D64: format = GL_COMPRESSED_RGB8_ETC1;
			case 0x9274: format = GL_COMPRESSED_RGB8_ETC2;
			case 0x93b2: format = GL_COMPRESSED_RGBA_ASTC_5x5;
			case 0x93b4: format = GL_COMPRESSED_RGBA_ASTC_6x6;
			default: throw "[KTX] Unsupported glInternalFormat 0x" + StringTools.hex(ktx.glInternalFormat);
		}
		for (mipLevel in 0...ktx.numberOfMipmapLevels)
		{
			uploadCompressedData(haxe.io.Bytes.ofData(ktx.mips[mipLevel].faces[0]), ktx.mips[mipLevel].width, ktx.mips[mipLevel].height, mipLevel);
		}
		return null;
	}

	// KTX loading code, loosely based on https://github.com/snowkit/ktx-format
	public static function fromKTX( _bytes : haxe.io.Bytes, ?allocPos : h3d.impl.AllocPos, ?resPath : String) {
	    	var GL_TEXTURE_1D:Int      = 0x0DE0;
	    	var GL_TEXTURE_2D:Int      = 0x0DE1;
	    	var GL_TEXTURE_3D:Int      = 0x806F;
		var GL_TEXTURE_CUBE_MAP:Int = 0x8513;
		var fin:BytesInput = new BytesInput(_bytes);

	        var id = UInt8Array.fromBytes(_bytes, 0, 12);
	        if (id[0] != 0xAB && id[1] != 0x4B && id[2] != 0x54 && id[3] != 0x58 &&
	            id[4] != 0x20 && id[5] != 0x31 && id[6] != 0x31 && id[7] != 0xBB &&
	            id[8] != 0x0D && id[9] != 0x0A && id[10] != 0x1A && id[11] != 0x0A)
	            return null;
	        fin.position = 12;

	        // check endianess of data
		var bigEndian = false;
	        var e = fin.readInt32();
	        if (e == 0x04030201)
        	    bigEndian = false;
	        else 
	            bigEndian = true;

		var ktx:KTXData = {
        	    glType:                 fin.readInt32(),
	            glTypeSize:             fin.readInt32(),
	            glFormat:               fin.readInt32(),
	            glInternalFormat:       fin.readInt32(),
	            glBaseInternalFormat:   fin.readInt32(),
	            pixelWidth:             fin.readInt32(),
	            pixelHeight:            fin.readInt32(),
	            pixelDepth:             fin.readInt32(),
	            numberOfArrayElements:  fin.readInt32(),
	            numberOfFaces:          fin.readInt32(),
	            numberOfMipmapLevels:   fin.readInt32(),
	            bytesOfKeyValueData:    fin.readInt32(),
	            mips: [],
            
	            compressed: false,
	            generateMips: false,
	            glTarget: GL_TEXTURE_1D,
	            dimensions: 1
	        };

	        fin.position += ktx.bytesOfKeyValueData;

	        /* TODO: parse and type the key-value-data
	        for (i in fin.position...(fin.position+ktx.bytesOfKeyValueData)) {
	            var kvByteSize = fin.readInt32();
	            var kv = Bytes.alloc(kvByteSize);
	            fin.readFullBytes(kv, 0, kvByteSize);
	            var padSize = 3 - ((kvByteSize + 3) % 4);
	            var pad = Bytes.alloc(padSize);
	            fin.readFullBytes(pad, 0, padSize);
	        }
	        */

	        // run some validation
	        if (ktx.glTypeSize != 1 && ktx.glTypeSize != 2 && ktx.glTypeSize != 4)
        	    throw "[KTX] Unsupported glTypeSize \""+ktx.glTypeSize+"\".";
        
	        if (ktx.glType == 0 || ktx.glFormat == 0) {
	            if (ktx.glType + ktx.glFormat != 0)
        	        throw "[KTX] glType and glFormat must be zero. Broken compression?";
	            ktx.compressed = true;
	        }

	        if ((ktx.pixelWidth == 0) || (ktx.pixelDepth > 0 && ktx.pixelHeight == 0))
	            throw "[KTX] texture must have width or height if it has depth.";

	        if (ktx.pixelHeight > 0) {
	            ktx.dimensions = 2;
	            ktx.glTarget = GL_TEXTURE_2D;
	        }
	        if (ktx.pixelDepth > 0) {
	            ktx.dimensions = 3;
	            ktx.glTarget = GL_TEXTURE_3D;
	        }
	        if (ktx.numberOfFaces == 6) {
	            if (ktx.dimensions == 2)
	                ktx.glTarget = GL_TEXTURE_CUBE_MAP;
	            else
	                throw "[KTX] cubemap needs 2D faces.";
	        }
	        else if (ktx.numberOfFaces != 1)
        	    throw "[KTX] numberOfFaces must be either 1 or 6";

	        if (ktx.numberOfMipmapLevels == 0) {
	            ktx.generateMips = true;
	            ktx.numberOfMipmapLevels = 1;
	        }

	        // make sane defaults
	        var pxDepth = ktx.pixelDepth > 0 ? ktx.pixelDepth : 1;
	        var pxHeight = ktx.pixelHeight > 0 ? ktx.pixelHeight : 1;
	        var pxWidth = ktx.pixelWidth > 0 ? ktx.pixelWidth : 1;
        
	        for (i in 0...ktx.numberOfMipmapLevels) {
	            var ml:KTXMipLevel = {
        	        imageSize: fin.readInt32(),
	                faces: [],
	                width: Std.int(Math.max(1, ktx.pixelWidth >> i)),
	                height: Std.int(Math.max(1, ktx.pixelHeight >> i)),
	                depth: Std.int(Math.max(1, ktx.pixelDepth >> i))
	            }
            
	            /* HACK-NOTE:
	            Uncomment the following part if have trouble loading the last mips
	            of a cubemap!
	            if (ktx.numberOfFaces == 6 && i > 1 && ml.width == 1) {
        	        var w = ktx.mips[i-1].width;
	                ml.imageSize = Std.int(ktx.mips[i-1].imageSize / (w*w));
	            }
        	    */

	            var imageSizeRounded = (ml.imageSize + 3)&~3;

	            for (k in 0...ktx.numberOfFaces) {
        	        var data = Bytes.alloc(imageSizeRounded);
                	fin.readFullBytes(data, 0, imageSizeRounded);
	                ml.faces.push(data.getData());

	                if (ktx.numberOfArrayElements > 0) {
        	            if (ktx.dimensions == 2) ml.height = ktx.numberOfArrayElements;
                	    if (ktx.dimensions == 3) ml.depth = ktx.numberOfArrayElements;
	                }
	            }

	            ktx.mips.push(ml);
	        }

		var textureFlags = new Array<TextureFlags>();
		textureFlags.push(CompressedTexture);
		if (ktx.numberOfMipmapLevels > 1) textureFlags.push(MipMapped);
		var format = GL_COMPRESSED_RGB8_ETC2;
		switch (ktx.glInternalFormat) {
			case 0x8C00: format = GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG;
			case 0x8D64: format = GL_COMPRESSED_RGB8_ETC1;
			case 0x9274: format = GL_COMPRESSED_RGB8_ETC2;
			case 0x93b2: format = GL_COMPRESSED_RGBA_ASTC_5x5;
			case 0x93b4: format = GL_COMPRESSED_RGBA_ASTC_6x6;
			default: throw "[KTX] Unsupported glInternalFormat 0x" + StringTools.hex(ktx.glInternalFormat);
		}
		var t = new Texture(ktx.pixelWidth, ktx.pixelHeight, textureFlags, format, allocPos, resPath);
		for (mipLevel in 0...ktx.numberOfMipmapLevels)
		{
			t.uploadCompressedData(haxe.io.Bytes.ofData(ktx.mips[mipLevel].faces[0]), ktx.mips[mipLevel].width, ktx.mips[mipLevel].height, mipLevel);
		}
	        t.realloc = function() { t.loadRes(resPath); }
		return t;
	}
#end

	public static function fromBitmap( bmp : hxd.BitmapData, ?allocPos : h3d.impl.AllocPos ) {
		var t = new Texture(bmp.width, bmp.height, allocPos);
		t.uploadBitmap(bmp);
		return t;
	}

	public static function fromPixels( pixels : hxd.Pixels, ?allocPos : h3d.impl.AllocPos ) {
		var t = new Texture(pixels.width, pixels.height, allocPos);
		t.uploadPixels(pixels);
		return t;
	}

	/**
		Creates a 1x1 texture using the RGB color passed as parameter.
	**/
	public static function fromColor( color : Int, ?alpha = 1., ?allocPos : h3d.impl.AllocPos ) {
		var engine = h3d.Engine.getCurrent();
		var aval = Std.int(alpha * 255);
		if( aval < 0 ) aval = 0 else if( aval > 255 ) aval = 255;
		var key = (color&0xFFFFFF) | (aval << 24);
		var t = @:privateAccess engine.textureColorCache.get(key);
		if( t != null )
			return t;
		var t = new Texture(1, 1, null, allocPos);
		t.clear(color, alpha);
		t.realloc = function() t.clear(color, alpha);
		@:privateAccess engine.textureColorCache.set(key, t);
		return t;
	}

	/**
		Returns a default dummy 1x1 black cube texture
	**/
	public static function defaultCubeTexture() {
		var engine = h3d.Engine.getCurrent();
		var t : h3d.mat.Texture = @:privateAccess engine.resCache.get(Texture);
		if( t != null )
			return t;
		t = new Texture(1, 1, [Cube]);
		t.clear(0x202020);
		t.realloc = function() t.clear(0x202020);
		@:privateAccess engine.resCache.set(Texture,t);
		return t;
	}

	/**
		Returns a checker texture of size x size, than can be repeated
	**/
	public static function genChecker(size) {
		var engine = h3d.Engine.getCurrent();
		var k = checkerTextureKeys.get(size);
		var t : Texture = k == null ? null : @:privateAccess engine.resCache.get(k);
		if( t != null && !t.isDisposed() )
			return t;
		if( k == null ) {
			k = {};
			checkerTextureKeys.set(size, k);
		}
		var t = new h3d.mat.Texture(size, size, [NoAlloc]);
		t.realloc = allocChecker.bind(t,size);
		@:privateAccess engine.resCache.set(k, t);
		return t;
	}

	static var checkerTextureKeys = new Map<Int,{}>();
	static var noiseTextureKeys = new Map<Int,{}>();

	public static function genNoise(size) {
		var engine = h3d.Engine.getCurrent();
		var k = noiseTextureKeys.get(size);
		var t : Texture = k == null ? null : @:privateAccess engine.resCache.get(k);
		if( t != null && !t.isDisposed() )
			return t;
		if( k == null ) {
			k = {};
			noiseTextureKeys.set(size, k);
		}
		var t = new h3d.mat.Texture(size, size, [NoAlloc]);
		t.realloc = allocNoise.bind(t,size);
		@:privateAccess engine.resCache.set(k, t);
		return t;
	}

	static function allocNoise( t : h3d.mat.Texture, size : Int ) {
		var b = new hxd.BitmapData(size, size);
		for( x in 0...size )
			for( y in 0...size ) {
				var n = Std.random(256);
				b.setPixel(x, y, 0xFF000000 | n | (n << 8) | (n << 16));
			}
		t.uploadBitmap(b);
		b.dispose();
	}

	static function allocChecker( t : h3d.mat.Texture, size : Int ) {
		var b = new hxd.BitmapData(size, size);
		b.clear(0xFFFFFFFF);
		for( x in 0...size>>1 )
			for( y in 0...size>>1 ) {
				b.setPixel(x, y, 0xFF000000);
				b.setPixel(x+(size>>1), y+(size>>1), 0xFF000000);
			}
		t.uploadBitmap(b);
		b.dispose();
	}

}