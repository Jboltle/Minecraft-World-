/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#version 120
#extension GL_EXT_gpu_shader4 : enable

#define frag
#define deffered0
#define ShaderStage 0

#include "/InternalLib/Syntax.glsl"

flat varying vec3 sunColor;
flat varying vec3 lightVector;
flat varying vec3 skyColor;

varying vec2 texcoord;
varying vec2 jitter;

varying float transitionFading;

varying mat3x4 skySH;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D colortex6;

uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float wetness;
uniform float eyeAltitude;
uniform float rainStrength;

uniform ivec2 eyeBrightnessSmooth;

uniform int worldTime;
uniform int isEyeInWater;
uniform int frameCounter;
uniform int heldItemId;

#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Uniform/Matrices.glsl"
#include "/InternalLib/Debug.glsl"

const bool colortex6MipmapEnabled = true;

/*******************************************************************************
 - Settings
 ******************************************************************************/

/*
const int colortex0Format = RGBA8; //Albedo
const int colortex1Format = RGBA16; //Big Data
const int colortex2Format = RGBA8; //Color Pass
const int colortex3Format = RGBA8; //SkyDome/BloomTiles
const int colortex4Format = RGBA8; //TAA Feedback
const int colortex5Format = RGBA16F; //Loddable Color/Previous Lum
const int colortex7Format = RGB8; //LUT

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex3Clear = false;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const bool colortex6Clear = false;

const float	sunPathRotation = -25.0;
const float ambientOcclusionLevel = 0.0;

const float eyeBrightnessHalflife = 1.0;

const float wetnessHalflife = 180.0;
const float drynessHalflife = 60.0;
*/

const int noiseTextureResolution = 64;
const float invNoiseRes = 1.0 / noiseTextureResolution;

const bool colortex7MipmapEnabled = true;

/*******************************************************************************
 - Lookups
 ******************************************************************************/

float GetDepth(vec2 coord) {
    return texture2D(depthtex1, coord).x;
}

vec3 GetAlbedo(vec3 data) {
    return srgbToLinear(data);
}

vec3 GetNormal(float data, out vec3 worldNormal) {
    worldNormal = DecodeNormal(data);
    return mat3(gbufferModelView) * worldNormal;
}

void GetLightmaps(float data, out float torchLightmap, out float skyLightmap) {
    vec2 temp = DecodeVec2(data);

    torchLightmap = temp.x;
    skyLightmap = temp.y;
}

/*******************************************************************************
 - Space Conversions
 ******************************************************************************/

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = (screenPos - vec3(jitter, 0.0)) * 2.0 - 1.0;

	return projMAD(projMatrixInverse, screenPos) / (screenPos.z * projMatrixInverse[2].w + projMatrixInverse[3].w);
}

vec3 CalculateViewSpacePosition(vec2 coord) {
	vec3 screenPos = vec3(coord - jitter, GetDepth(coord)) * 2.0 - 1.0;

	return projMAD(projMatrixInverse, screenPos) / (screenPos.z * projMatrixInverse[2].w + projMatrixInverse[3].w);
}

vec3 CalculateWorldSpacePosition(vec3 viewPos){
    return mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
}

vec3 FromSH(vec4 cR, vec4 cG, vec4 cB, vec3 lightDir) {
    const float sqrt1OverPI = sqrt(rPI);
    const float sqrt3OverPI = sqrt(3.0 * rPI);
    const vec2 halfnhalf = vec2(0.5, -0.5);
    const vec2 sqrtOverPI = vec2(sqrt1OverPI, sqrt3OverPI);
    const vec4 foo = halfnhalf.xyxy * sqrtOverPI.xyyy;

    vec4 sh = foo * vec4(1.0, lightDir.yzx);

    // know to work
    return vec3(
        dot(sh,cR),
        dot(sh,cG),
        dot(sh,cB)
    );
}


/*******************************************************************************
 - Includes
 ******************************************************************************/

#include "/InternalLib/Fragment/Sky.fsh"
#include "/InternalLib/Fragment/Clouds2D.fsh"
#include "/InternalLib/Fragment/Clouds.fsh"
#include "/InternalLib/Fragment/DiffuseLighting.fsh"

/*******************************************************************************
 - Functions
 ******************************************************************************/
 
void GetRoughnessF0(float data, out float roughness, out float f0, mat2x3 position, vec3 normal, float skyLightmap) {
	float puddles = getRainPuddles(position[1], normal, skyLightmap);
    vec2 temp = DecodeVec2(data);

    roughness = temp.x;
    roughness = mix(roughness, 0.05, puddles);

	f0 = temp.y;
    f0 = mix(f0, 0.021, puddles);
}

vec3 ProjectSpherical(vec2 coord) {
	coord *= vec2(TAU, PI);
	vec2 lon = sincos(coord.x) * sin(coord.y);
	return vec3(lon.x, cos(coord.y), lon.y);
}

vec3 CalculateSkyDome(float dither) {
	if(any(greaterThan(texcoord, vec2(0.501)))) return vec3(0.0);

	vec3 sphericalProjection = ProjectSpherical(texcoord * 2.0) * vec3(1.0, 1.0, -1.0);
	vec3 sphericalProjectionView = mat3(gbufferModelView) * sphericalProjection;
	vec3 sphericalViewVector = -sphericalProjectionView;

	vec3 sunVector = sunPosition * 0.01;
	vec3 upVector = upPosition * 0.01;

	vec3 viewAbsorb = vec3(1.0);

    vec3 skyDome = sky_atmosphere(vec3(0.0), sphericalViewVector, upVector, sunVector, -sunVector, sky_sunColor, sky_moonColor, 8, viewAbsorb);

	#ifdef REFLECT_2D_CLOUDS
		skyDome = CalculatePlanarClouds(skyDome, -sphericalProjection, dot(sphericalViewVector, sunVector));
	#endif

	#ifdef REFLECT_3D_CLOUDS
    	skyDome = CalculateVolumetricClouds(skyDome, skyDome, sunColor, -mat2x3(sphericalProjectionView, sphericalProjection), 1.0, dither, 0.0, REFLECTED_CLOUDS_QUALITY, REFLECTED_CLOUDS_QUALITY_DIRECT);
	#endif

	return skyDome;
}


/* DRAWBUFFERS:23 */

void main() {
    float depth = GetDepth(texcoord);
    float luminancePassthrough = texture2D(colortex4, texcoord).a;

	float dither = bayer64(gl_FragCoord.st);
    #ifdef TAA
          dither = fract(frameCounter * 0.109375 + dither);
    #endif

    vec3 skyDome = CalculateSkyDome(0.0);
    gl_FragData[1] = EncodeRGBE8(skyDome);

    if(depth >= 1.0) { // Write to passthrough buffer and return early if the fragment belongs to the sky.
        exit();
        return;
    }

	mat2x3 position;
	position[0] = CalculateViewSpacePosition(vec3(texcoord, depth));
	position[1] = CalculateWorldSpacePosition(position[0]);

    float normFactor = inversesqrt(dot(position[0], position[0]));
    vec3 viewVector = normFactor * -position[0];

    vec4 data0 = ScreenTex(colortex0);
    vec4 data1 = ScreenTex(colortex1);
	
	vec3 worldNormal = vec3(0.0);
    vec3 albedo     = GetAlbedo(data0.xyz);
    vec3 normal     = GetNormal(data1.x, worldNormal);

    float roughness, f0, skyLightmap, torchLightmap;
    GetLightmaps(data1.y, torchLightmap, skyLightmap);
    GetRoughnessF0(data1.z, roughness, f0, position, normal, skyLightmap);

	vec2 decodeData1Alpha = DecodeVec2(data1.a);

    float materialFlag = (1.0 - decodeData1Alpha.y) * 10.0;  //1.0 is for all plants
    vec3 shadows = vec3(decodeData1Alpha.x * 2.0 - 1.0);

    vec3 finalColor = CalculateLighting(position, albedo, viewVector, normal, worldNormal, vec2(torchLightmap, skyLightmap), normFactor, roughness, f0, dither, shadows, materialFlag);

    gl_FragData[0] = EncodeRGBE8(finalColor);

	exit();
}

/*******************************************************************************
 - EOF
 ******************************************************************************/
