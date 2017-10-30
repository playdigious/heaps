package hxd;

enum PixelFormat {
	ARGB;
	BGRA;
	RGBA;
	RGBA16F;
	RGBA32F;
	ALPHA8;
	ALPHA16F;
	ALPHA32F;
#if mobile
	PVRTC;
#end
}
