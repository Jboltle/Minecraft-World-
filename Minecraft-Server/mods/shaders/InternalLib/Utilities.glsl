/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

const float PI = radians(180.0);
const float TAU = radians(360.0);
const float HPI = PI * 0.5;
const float rPI = 1.0 / PI;
const float rTAU = 1.0 / TAU;
const float PHI = sqrt(5.0) * 0.5 + 0.5;

const float goldenAngle = TAU / PHI / PHI;

const float LOG2 = log(2.0);
const float rLOG2 = 1.0 / LOG2;

#define TIME_SPEED 1.0 // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 5.0 6.0 7.0 8.0 9.0 10.0 12.0 14.0 16.0 18.0 20.0 24.0 28.0 32.0 36.0 40.0]
#define TIME ( frameTimeCounter * TIME_SPEED )

#define diagonal2(m) vec2((m)[0].x, (m)[1].y)
#define diagonal3(m) vec3(diagonal2(m), m[2].z)
#define diagonal4(m) vec4(diagonal3(m), m[2].w)

#define transMAD(mat, v) (     mat3(mat) * (v) + (mat)[3].xyz)
#define  projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

#define fstep(a, b) clamp(((b) - (a)) * 1e35, 0.0, 1.0)
#define fsign(a) (clamp((a) * 1e35, 0.0, 1.0) * 2.0 - 1.0)

#define textureRaw(samplr, coord) texelFetch2D(samplr, ivec2((coord) * vec2(viewWidth, viewHeight)), 0)
#define ScreenTex(samplr) texelFetch2D(samplr, ivec2(gl_FragCoord.st), 0)

#if defined composite0 || defined composite1 || defined deffered0 || defined gbuffers_water || defined gbuffers_textured || defined final || defined gbuffers_hand_water
#define up gbufferModelView[1].xyz
#endif

vec3 clampNormal(const vec3 n, const vec3 v) {
    float NoV = clamp(dot(n, -v), 0.0, 1.0);
    return normalize(NoV * v + n);
}

float dotNorm(vec3 v, vec3 n) {
	return dot(v, n) * inversesqrt(dot(v, v));
}

vec2 sincos(float x){
	return vec2(sin(x),cos(x));
}

vec2 circlemap(float i, float n){
	return sincos(i * n * goldenAngle) * sqrt(i);
}

vec3 circlemapL(float i, float n){
	return vec3(sincos(i * n * goldenAngle), sqrt(i));
}

vec3 srgbToLinear(vec3 srgb) {
    return mix(
        srgb * 0.07739938080495356, // 1.0 / 12.92 = ~0.07739938080495356
        pow(0.947867 * srgb + 0.0521327, vec3(2.4)),
        step(0.04045, srgb)
    );
}

vec3 linearToSrgb(vec3 linear) {
    return mix(
        linear * 12.92,
        pow(linear, vec3(0.416666666667)) * 1.055 - 0.055, // 1.0 / 2.4 = ~0.416666666667
        step(0.0031308, linear)
    );
}

mat3 getRotMat(vec3 x,vec3 y){
   float d = dot(x,y);
   vec3 cr = cross(y,x);

   float s = length(cr);

   float id = 1.-d;

   vec3 m = cr/s;

   vec3 m2 = m*m*id+d;
   vec3 sm = s*m;

   vec3 w = (m.xy*id).xxy*m.yzz;

   return mat3(
	   m2.x,     w.x-sm.z, w.y+sm.y,
	   w.x+sm.z, m2.y,     w.z-sm.x,
	   w.y-sm.y, w.z+sm.x, m2.z
   );
}

vec3 blackbody(float t) {
    // http://en.wikipedia.org/wiki/Planckian_locus

    vec4 vx = vec4( -0.2661239e9, -0.2343580e6, 0.8776956e3, 0.179910   );
    vec4 vy = vec4( -1.1063814,   -1.34811020,  2.18555832, -0.20219683 );
    //vec4 vy = vec4(-0.9549476,-1.37418593,2.09137015,-0.16748867); //>2222K
    float it = 1. / t;
    float it2= it * it;
    float x = dot( vx, vec4( it*it2, it2, it, 1. ) );
    float x2 = x * x;
    float y = dot( vy, vec4( x*x2, x2, x, 1. ) );

    // http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
    mat3 xyzToSrgb = mat3(
         3.2404542,-1.5371385,-0.4985314,
        -0.9692660, 1.8760108, 0.0415560,
         0.0556434,-0.2040259, 1.0572252
    );

    vec3 srgb = vec3( x/y, 1., (1.-x-y)/y ) * xyzToSrgb;

    return max( srgb, 0. );
}

vec3 fromYUV (vec3 yuv) {
    const vec2 c2 = vec2(1.8556,1.5748);
    const float c4 = 1. / .7152;
    const vec2 c5 = -vec2(.0722,.2126) * c4;
    const vec2 c1 = -.5* c2;

    vec2 br = yuv.yz * c2 + (c1 + yuv.x);
    return vec3(br.y, yuv.x * c4 + dot(c5, br), br.x);
}

vec3 toYUV (vec3 rgb) {
    const vec2 c2 = vec2(1.8556,1.5748);
    const vec3 c3 = vec3(.2126,.7152,.0722);
    const vec2 c6 = 1. / c2;

    float y = dot(rgb, c3);
    return vec3(y, (rgb.br - y) * c6 +.5);
}

vec2 rotate(vec2 vector, float r) {
    float c = cos(r), s = sin(r);
    return vector * mat2(c, -s, s, c);
}

vec3 hash33(vec3 p){
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p.zxy, p.yxz + 19.27);
    return fract(vec3(p.x * p.y, p.z * p.x, p.y * p.z));
}

float cubesmooth(float x) { return (x * x) * (3.0 - 2.0 * x); }
vec2 cubesmooth(vec2 x) { return (x * x) * (3.0 - 2.0 * x); }
vec3 cubesmooth(vec3 x) { return (x * x) * (3.0 - 2.0 * x); }
vec4 cubesmooth(vec4 x) { return (x * x) * (3.0 - 2.0 * x); }

#define getDepthExp(x) ( (far * (x - near)) / (x * (far - near)) )

#define EncodeColor(x) ((x) * 0.0001)
#define DecodeColor(x) ((x) * 10000.0)

#include "/InternalLib/Utilities/Encoding.glsl"
#include "/InternalLib/Utilities/Pow.glsl"
#include "/InternalLib/Utilities/Clamping.glsl"
#include "/InternalLib/Utilities/Noise.glsl"
#include "/InternalLib/Utilities/FastMath.glsl"
#include "/InternalLib/Fragment/ACESTransforms.glsl"

#include "/InternalLib/UserLibManager.glsl"
