/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#version 120
#extension GL_EXT_gpu_shader4 : enable

#define frag
#define composite0
#define ShaderStage 10

#include "/InternalLib/Syntax.glsl"

flat varying vec3 sunColor;
flat varying vec3 lightVector;
flat varying vec3 skyColor;

varying vec2 texcoord;
varying vec2 jitter;

varying float transitionFading;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 sunPosition; // We might need to add moonPosition back.
uniform vec3 upPosition;
uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float wetness;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform float eyeAltitude;
uniform float rainStrength;

uniform int worldTime;
uniform int isEyeInWater;
uniform int frameCounter;
uniform int heldItemId;

uniform ivec2 eyeBrightnessSmooth;

#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Uniform/Matrices.glsl"
#include "/InternalLib/Debug.glsl"

const int noiseTextureResolution = 64;
const float invNoiseRes = 1.0 / noiseTextureResolution;

/*******************************************************************************
 - Lookups
 ******************************************************************************/

float GetDepth(vec2 coord) {
    return texture2D(depthtex0, coord).x;
}

vec3 GetAlbedo(vec3 data) {
    return srgbToLinear(data);
}

vec3 GetNormal(float data) {
    return mat3(gbufferModelView) * DecodeNormal(data);
}

void GetLightmaps(float data, out float torchLightmap, out float skyLightmap) {
    vec2 temp = DecodeVec2(data);

    torchLightmap = temp.x;
    skyLightmap = temp.y;
}

bool GetWaterMask(vec2 coord) {
    return texture2D(depthtex1, coord).x > texture2D(depthtex0, coord).x && DecodeVec2(texture2D(colortex0, coord).g).y > 0.5;
}

/*******************************************************************************
 - Space Conversions
 ******************************************************************************/

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = (screenPos - vec3(jitter, 0.0)) * 2.0 - 1.0;

	return projMAD(projMatrixInverse, screenPos) / (screenPos.z * projMatrixInverse[2].w + projMatrixInverse[3].w);
}

vec3 CalculateViewSpacePosition(vec2 coord) {
	vec3 screenPos = vec3(coord - jitter, GetDepth(coord - jitter)) * 2.0 - 1.0;

	return projMAD(projMatrixInverse, screenPos) / (screenPos.z * projMatrixInverse[2].w + projMatrixInverse[3].w);
}

vec3 CalculateWorldSpacePosition(vec3 viewPos) {
	return mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
}

vec3 ViewSpaceToScreenSpace(vec3 viewPos) {
	return ((projMAD(projMatrix, viewPos) / -viewPos.z)) * 0.5 + 0.5 + vec3(jitter, 0.0);
}

float ScreenToViewSpaceDepth(float p) {
	p = p * 2.0 - 1.0;
	vec2 x = projMatrixInverse[2].zw * p + projMatrixInverse[3].zw;

	return x.x / x.y;
}

vec2 UnprojectSpherical(vec3 dir) {
    vec2 lonlat = vec2(atan(-dir.x, dir.z), acos(dir.y));
    return lonlat * vec2(rTAU, rPI) + vec2(0.5, 0.0);
}

/*******************************************************************************
 - Includes
 ******************************************************************************/

#include "/InternalLib/Fragment/Sky.fsh"
#include "/InternalLib/Fragment/SpecularLighting.fsh"
#include "/InternalLib/Fragment/Clouds2D.fsh"
#include "/InternalLib/Fragment/Clouds.fsh"
#include "/InternalLib/Fragment/VolumetricRenderer.fsh"

/*******************************************************************************
 - Functions
 ******************************************************************************/

void GetRoughnessF0(float data, out float roughness, out float f0, mat2x3 position, vec3 normal, float skyLightmap, bool isTransparent) {
	float puddles = getRainPuddles(position[1], normal, skyLightmap) * (1.0 - float(isTransparent));
    vec2 temp = DecodeVec2(data);

    roughness = temp.x;
    roughness = mix(roughness, 0.05, puddles);

	f0 = temp.y;
    f0 = mix(f0, 0.021, puddles);
}

vec3 RenderTranslucents(vec3 background, vec4 transparentGeometry, vec3 viewVector, vec3 lightVector, vec3 normal, vec3 shadows, vec3 sunLightColor, vec3 skyLightColor, float skyLightmap, float torchLightmap, bool isWater) {
	background *= mix(vec3(1.0), transparentGeometry.rgb, clamp(transparentGeometry.a, 0.9, 1.0) * float(!isWater)); //Absorb Light through transparents.


	vec3 litTransparentGeometry = clamp01(dot(normal, lightVector)) * shadows * sunLightColor; //Light Forward Facing Transparents
	     litTransparentGeometry += skyLightColor * pow2(skyLightmap); //Skylight
		 litTransparentGeometry += CalculateTorchLightmap(GetTorchLightmapDistance(torchLightmap), true); //TorchLight

	return mix(background, litTransparentGeometry.rgb * transparentGeometry.rgb, transparentGeometry.a);
}

vec3 LensBokeh(vec2 offset) {
	const float lod  = 2.0;
	const float lod2 = exp2(lod);

	const float a  = TAU / CAMERA_BLADES;
	const mat2 rot = mat2(cos(a), -sin(a), sin(a), cos(a));

	const float softness = 0.9;

	const vec3 size  = 0.4 * vec3(1.0 - vec2(LENS_SHIFT_AMOUNT, 0.5 * LENS_SHIFT_AMOUNT), 1.0);
	const vec3 size0 = size * softness;
	const vec3 size1 = size0 * softness * 0.8;

	float r = 0.0;
	const vec2 caddv = vec2(sin(BLADE_ROTATION), -cos(BLADE_ROTATION));
	vec2 addv = caddv;

	vec2 coord = (texcoord - offset) * lod2;
	vec2 centerOffset = coord - 0.5;

	for(int i = 0; i < CAMERA_BLADES; ++i) {
		addv = rot * addv;
		r = max(r, dot(addv, centerOffset));
	}

	r = mix(r, length(centerOffset) * 0.8, BLADE_ROUNDING);

	vec3 bokeh = clamp01(1.0 - smoothstep(size0, size, vec3(r)));
	     bokeh = bokeh * (1.0 - clamp01(smoothstep(size, size1, vec3(r)) * CAMERA_BIAS));

	return bokeh;
}

/* DRAWBUFFERS:50 */

void main() {
	gl_FragData[1] = vec4(LensBokeh(bokehOffset), 1.0);

	float depth = GetDepth(texcoord);
	float backDepth = texture2D(depthtex1, texcoord).x;

    mat2x3 position;
    position[0] = CalculateViewSpacePosition(vec3(texcoord, depth));
    position[1] = CalculateWorldSpacePosition(position[0]);

    mat2x3 backPosition;
    backPosition[0] = CalculateViewSpacePosition(vec3(texcoord, backDepth));
    backPosition[1] = CalculateWorldSpacePosition(backPosition[0]);

	float distFront = length(position[0]);

	vec4 data1 = ScreenTex(colortex1);
	vec3 normal = GetNormal(data1.x);

	float normFactor = inversesqrt(dot(position[0], position[0]));
	vec3 viewVector = normFactor * -position[0];

	vec3 wLightVector = mat3(gbufferModelViewInverse) * lightVector;

	float dither = bayer64(gl_FragCoord.st);
	#ifdef TAA
          dither = fract(frameCounter * 0.109375 + dither);
    #endif

	bool isTransparent = backDepth > depth;
	vec2 coord = texcoord;
	vec3 sky = vec3(0.0);
	vec3 viewAbsorb = vec3(1.0);

	//Refract
	#ifdef REFRACTION
		if (isTransparent) {
			vec3 flatNormal = clamp(normalize(cross(dFdx(position[0]), dFdy(position[0]))), -1.0, 1.0);
			vec3 rayDirection = refract(viewVector, normal - flatNormal, 0.75);
			vec3 refractedPosition = rayDirection * abs(distance(position[1], backPosition[1])) / position[0].z + position[0];
			     refractedPosition = ViewSpaceToScreenSpace(refractedPosition);
			     refractedPosition.z = texture2D(depthtex1, refractedPosition.xy).x;

	        if(refractedPosition.z > texture2D(depthtex0, refractedPosition.xy).x) {
				coord = refractedPosition.xy;
				backDepth = refractedPosition.z;

	            backPosition[0] = CalculateViewSpacePosition(refractedPosition);
	            backPosition[1] = CalculateWorldSpacePosition(backPosition[0]);

				float normFactor = inversesqrt(dot(backPosition[0], backPosition[0]));
	            viewVector = normFactor * -backPosition[0];
	        }
		}
	#endif

	float VoL = dot(-viewVector, lightVector);
	float VoS = dot(-viewVector, sunPosition * 0.01);

	VolumetricData vd = CalculateVolumetricVariables(viewVector, VoL);
	vec3 backWorldVector = mat3(gbufferModelViewInverse) * -viewVector;

	#if (defined VOLUMETRIC_LIGHT) && defined AERIAL_VL
		vec3 arealIncrement = (backWorldVector * VOLUMETRIC_CLOUDS_ALTITUDE) / clamp(abs(backWorldVector.y), 6e-2, 1.0) - position[1];
		float arealLength = length(arealIncrement);
    #else
		vec3 arealIncrement = vec3(0.0);
		float arealLength = 0.0;
    #endif

	//Calculate Sky
	if(backDepth >= 1.0) {
		vec3 sunMoonSpot = CalculateSunSpot(VoS) * sky_sunColor + CalculateMoonSpot(-VoS) * sky_moonColor;
		sky += sunMoonSpot;
		sky += calculateStars(backWorldVector, wLightVector);

		vec3 atmosphericScattering = sky_atmosphere(sky, -viewVector, upPosition * 0.01, sunPosition * 0.01, -sunPosition * 0.01, sky_sunColor, sky_moonColor, 25, viewAbsorb);
		sky = atmosphericScattering;

		sky = CalculatePlanarClouds(sky, backWorldVector, VoL);
		sky = CalculateVolumetricClouds(sky, sunMoonSpot * -viewAbsorb + atmosphericScattering, vd.sunlightColor, backPosition, backDepth, dither, arealLength, VOLUMETRIC_CLOUDS_QUALITY, VOLUMETRIC_CLOUDS_DIRECT_QUALITY);

		sky = CalculateAerialLight(vd, backPosition, sky, arealIncrement, distFront, dither);
	}

	//Bring in lit world
	vec3 data2 = max0(DecodeRGBE8(texture2D(colortex2, coord)));
	vec3 solidGeometry = data2.rgb + sky;

	float roughness, f0, skyLightmap, torchLightmap;
    GetLightmaps(data1.y, torchLightmap, skyLightmap);
    GetRoughnessF0(data1.z, roughness, f0, position, normal, skyLightmap, isTransparent);

	bool isWater = isTransparent && (roughness >= 0.025 && roughness <= 0.035);

	//Apply back volumes behind glass
	if(isTransparent && !isWater) 	 solidGeometry = CalculateVolumetricLight(vd, solidGeometry, isEyeInWater == 1 ? gbufferModelViewInverse[3].xyz : position[1], isEyeInWater == 1 ? position[1] : backPosition[1], distFront, dither);

	//Bring in semis
	vec4 albedo = texture2D(colortex0, texcoord);
		 albedo.rgb = srgbToLinear(albedo.rgb);

	vec3 shadows = vec3(1.0);
    if(isTransparent) {
		shadows = CalculateShadows(WorldSpaceToShadowSpace(position[1]), normal, dither, false);
		shadows *= CloudShadow(position[1] + cameraPosition);
	}

	shadows *= transitionFading;

	if(isTransparent) solidGeometry = RenderTranslucents(solidGeometry, albedo, viewVector, lightVector, normal, shadows, vd.sunlightColor, skyColor, skyLightmap, torchLightmap, isWater);
	// Render translucents after water fog because otherwise translucents will just render over fog underwater
	if(isWater || isEyeInWater == 1) solidGeometry = CalculateVolumetricWater(vd, solidGeometry, isEyeInWater == 1 ? gbufferModelViewInverse[3].xyz : position[1], isEyeInWater == 1 ? position[1] : backPosition[1], dither);

	if (isEyeInWater == 0) {
		if (depth < 1.0) CalculateSpecularReflections(solidGeometry, albedo.rgb, position, viewVector, vec3(texcoord, depth), normal, roughness, f0, skyLightmap, shadows, dither, isTransparent);
		solidGeometry = CalculateVolumetricLight(vd, solidGeometry, isEyeInWater == 1 ? position[1] : gbufferModelViewInverse[3].xyz, isEyeInWater == 1 ? backPosition[1] : position[1], distFront, dither);
	}

    gl_FragData[0] = vec4(EncodeColor(solidGeometry), texture2D(colortex5, texcoord).a);

	exit();
}
