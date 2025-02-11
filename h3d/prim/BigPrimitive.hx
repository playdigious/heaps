package h3d.prim;

/**
	Vertex buffers are limited to 65K vertexes because of the 16-bits limitation of the index buffers.
	BigPrimitive allows you to easily create large buffers by spliting the buffers.
**/
class BigPrimitive extends Primitive {

	var isRaw : Bool;
	var stride : Int;
	var buffers : Array<Buffer>;
	var allIndexes : Array<Indexes>;
	var tmpBuf : hxd.FloatBuffer;
	var tmpIdx : hxd.IndexBuffer;
	var bounds : h3d.col.Bounds;
	var bufPos : Int = 0;
	var idxPos : Int = 0;
	var startIndex : Int = 0;
	var flushing : Bool;
	#if debug
	var allocPos : h3d.impl.AllocPos;
	#end

	public var isStatic = true;

	static var PREV_BUFFER : hxd.FloatBuffer;
	static var PREV_INDEX : hxd.IndexBuffer;

	public function new(stride, isRaw=false, ?pos : h3d.impl.AllocPos ) {
		this.isRaw = isRaw;
		buffers = [];
		allIndexes = [];
		bounds = new h3d.col.Bounds();
		this.stride = stride;
		if( stride < 3 ) throw "Minimum stride = 3";
		#if debug
		allocPos = pos;
		#end
	}

	/**
		Call begin() before starting to add vertexes/indexes to the primitive.
		The count value is the number of vertexes you will add, it will automatically flush() if it doesn't fit into the current buffer.
	**/
	public function begin(vcount,icount) {
		startIndex = Std.int(bufPos / stride);
		var VERTICES = 8192;
		while ( startIndex + vcount >= VERTICES ) {
			VERTICES *= 2;
			if( vcount >= 65535 ) throw "Too many vertices in begin()";
			flush();
		}
		if( tmpBuf == null ) {
			tmpBuf = PREV_BUFFER;
			if( tmpBuf == null )
				tmpBuf = new hxd.FloatBuffer();
			else
				PREV_BUFFER = null;
			#if hl
			if( isStatic )
			#end
				tmpBuf.grow(VERTICES * stride);
		}
		if( tmpIdx == null ) {
			tmpIdx = PREV_INDEX;
			if( tmpIdx == null )
				tmpIdx = new hxd.IndexBuffer();
			else
				PREV_INDEX = null;
		}
		if( idxPos + icount > tmpIdx.length ) {
			var size = tmpIdx.length == 0 ? 1024 : tmpIdx.length;
			var req = idxPos + icount;
			while( size < req ) size <<= 1;
			tmpIdx.grow(size);
		}
	}

	/**
		This is similar to addVertexValue for X Y and Z, but will also update the bounds if you wish to have them calculated.
	**/
	public inline function addPoint(x, y, z) {
		tmpBuf[bufPos++] = x;
		tmpBuf[bufPos++] = y;
		tmpBuf[bufPos++] = z;
		bounds.addPos(x, y, z);
	}

	public inline function addBounds(x, y, z) {
		bounds.addPos(x, y, z);
	}

	public inline function addVertexValue(v) {
		tmpBuf[bufPos++] = v;
	}

	public inline function addIndex(i) {
		tmpIdx[idxPos++] = i + startIndex;
	}

	override function triCount() {
		var count = 0;
		for( i in allIndexes )
			count += i.count;
		count += idxPos;
		return Std.int(count/3);
	}

	override function vertexCount() {
		var count = 0;
		for( b in buffers )
			count += b.vertices;
		count += Std.int(bufPos / stride);
		return count;
	}

	/**
		Flush the current buffer.
		It is required to call begin() after a flush()
	**/
	public function flush() {
		if( tmpBuf != null ) {
			if( bufPos > 0 && idxPos > 0 ) {
				flushing = true;
				var b = h3d.Buffer.ofSubFloats(tmpBuf, stride, Std.int(bufPos / stride) #if debug , null, allocPos #end);
				if( isRaw ) b.flags.set(RawFormat);
				buffers.push(b);
				allIndexes.push(h3d.Indexes.alloc(tmpIdx, 0, idxPos));
				flushing = false;
			}
			if( PREV_BUFFER == null || PREV_BUFFER.length < tmpBuf.length )
				PREV_BUFFER = tmpBuf;
			if( PREV_INDEX == null || PREV_INDEX.length < tmpIdx.length )
				PREV_INDEX = tmpIdx;
			tmpBuf = null;
			tmpIdx = null;
			bufPos = 0;
			idxPos = 0;
			startIndex = 0;
		}
	}

	override function render( engine : h3d.Engine ) {
		if( tmpBuf != null ) flush();
		for( i in 0...buffers.length )
			engine.renderIndexed(buffers[i],allIndexes[i]);
	}

	override function getBounds() {
		return bounds;
	}

	override function dispose() {
		clear();
	}

	public function clear() {

		if( flushing )
			throw "Cannot clear() BigPrimitive while it's flushing";

		bounds.empty();
		for( b in buffers )
			b.dispose();
		for( i in allIndexes )
			i.dispose();
		buffers = [];
		allIndexes = [];
		bufPos = 0;
		tmpBuf = null;
		tmpIdx = null;
	}

	/**
		Adds a complete object to the primitive, with custom position,scale,rotation.
		See addSub for complete documentation.
	**/
	public function add( buf : hxd.FloatBuffer, idx : hxd.IndexBuffer, dx : Float = 0. , dy : Float = 0., dz : Float = 0., rotation = 0., scale = 1., stride = -1 ) {
		return addSub(buf, idx, 0, 0, Std.int(buf.length / (stride < 0 ? this.stride : stride)), Std.int(idx.length / 3), dx, dy, dz, rotation, scale, stride);
	}
	/**
		Adds a buffer to the primitive, with custom position,scale,rotation.
		The buffer can have more stride than the BigPrimitive, but not less.
		It is assumed that the buffer contains [X,Y,Z,NX,NY,NZ,U,V,R,G,B] (depending on his stride) so the different offsets are applied to the corresponding components.
		However if the stride is 5, we assume [X,Y,Z,U,V]
		If mat is not null, it overrides dx, dy, dz, rotation, scale
	**/
	@:noDebug
	public function addSub( buf : hxd.FloatBuffer, idx : hxd.IndexBuffer, startVert, startTri, nvert, triCount, dx : Float = 0. , dy : Float = 0., dz : Float = 0., rotation = 0., scale = 1., stride = -1, deltaU = 0., deltaV = 0., color = 1., mat : h3d.Matrix = null) {
		if( stride < 0 ) stride = this.stride;
		if( stride < this.stride ) throw "only stride >= " + this.stride+" allowed";
		begin(nvert, triCount*3);
		var start = startIndex;
		var cr = Math.cos(rotation);
		var sr = Math.sin(rotation);
		var pos = bufPos;
		var tmpBuf = tmpBuf;
		#if hl
		var buf : hl.BytesAccess<hxd.impl.Float32> = hl.Bytes.getArray(buf.getNative());
		var tmpBuf : hl.BytesAccess<hxd.impl.Float32> = hl.Bytes.getArray(tmpBuf.getNative());
		#end
		var p;
		var x ;
		var y ;
		var z ;
		var tx;
		var ty;
		var vx;
		var vy;
		var vz;
		var nx ;
		var ny ;
		var nz ;
		var tnx;
		var tny;
		for( i in 0...nvert ) {
			inline function add(v) tmpBuf[pos++] = v;

			p = (i + startVert) * stride;
			x = buf[p++];
			y = buf[p++];
			z = buf[p++];

			if(mat != null) {
				var pt = new h3d.col.Point(x, y, z);
				pt.transform(mat);
				add(pt.x);
				add(pt.y);
				add(pt.z);
				bounds.addPoint(pt);
			}
			else {
				tx = (x * cr - y * sr) * scale;
				ty = (x * sr + y * cr) * scale;
				vx = dx + tx;
				vy = dy + ty;
				vz = dz + z * scale;
				add(vx);
				add(vy);
				add(vz);
				bounds.addPos(vx, vy, vz);
			}

			if(this.stride >= 6) {
				nx = buf[p++];
				ny = buf[p++];
				nz = buf[p++];

				if(mat != null) {
					var pt = new h3d.col.Point(nx, ny, nz);
					pt.transform3x3(mat);
					pt.normalize();
					add(pt.x);
					add(pt.y);
					add(pt.z);
				}
				else {
					tnx = nx * cr - ny * sr;
					tny = nx * sr + ny * cr;
					add(tnx);
					add(tny);
					add(nz);
				}
			}

			switch( this.stride ) {
			case 3, 6:
				continue;
			case 4, 7:
				add(buf[p++] + deltaU);
			case 5, 8, 9, 10:
				add(buf[p++] + deltaU);
				add(buf[p++] + deltaV);
				for( i in 8...this.stride )
					add(buf[p++]);
			default:
				// UV
				add(buf[p++] + deltaU);
				add(buf[p++] + deltaV);

				// COLOR
				add(buf[p++] * color);
				add(buf[p++] * color);
				add(buf[p++] * color);

				for( i in 11...this.stride )
					add(buf[p++]);
			}
		}
		bufPos = pos;
		start -= startVert;
		for( i in 0...triCount * 3 )
			tmpIdx[idxPos++] = idx[i+startTri*3] + start;
	}

	#if hxbit
	override function customSerialize(ctx:hxbit.Serializer) {
		flush();
		ctx.addBool(isRaw);
		ctx.addInt(stride);
		ctx.addFloat(bounds.xMin);
		ctx.addFloat(bounds.yMin);
		ctx.addFloat(bounds.zMin);
		ctx.addFloat(bounds.xMax);
		ctx.addFloat(bounds.yMax);
		ctx.addFloat(bounds.zMax);
		ctx.addInt(buffers.length);
		var reqSize = 0;
		for( a in allIndexes ) {
			var sz = a.count << 1;
			if( reqSize < sz ) reqSize = sz;
		}
		for( b in buffers ) {
			var sz = (b.vertices * stride) << 2;
			if( reqSize < sz ) reqSize = sz;
		}
		var tmpBytes = haxe.io.Bytes.alloc(reqSize);
		for( i in 0...buffers.length ) {
			var idx = allIndexes[i];
			idx.readBytes(tmpBytes, 0, idx.count);
			ctx.addInt(idx.count);
			ctx.addBytesSub(tmpBytes, 0, idx.count << 1);

			var b = buffers[i];
			b.readBytes(tmpBytes, 0, b.vertices);
			ctx.addInt(b.vertices);
			ctx.addBytesSub(tmpBytes, 0, b.vertices * stride << 2);
		}
	}
	override function customUnserialize(ctx:hxbit.Serializer) {
		isRaw = ctx.getBool();
		stride = ctx.getInt();
		bounds = new h3d.col.Bounds();
		bounds.xMin = ctx.getFloat();
		bounds.yMin = ctx.getFloat();
		bounds.zMin = ctx.getFloat();
		bounds.xMin = ctx.getFloat();
		bounds.yMax = ctx.getFloat();
		bounds.zMax = ctx.getFloat();
		var count = ctx.getInt();
		buffers = [];
		allIndexes = [];
		for( i in 0...count ) {
			var nidx = ctx.getInt();
			var idx = new h3d.Indexes(nidx);
			idx.uploadBytes(ctx.getBytes(), 0, nidx);
			allIndexes.push(idx);

			var nvert = ctx.getInt();
			var buf = new h3d.Buffer(nvert, stride);
			buf.uploadBytes(ctx.getBytes(), 0, nvert);
			buffers.push(buf);
		}
	}
	#end

}