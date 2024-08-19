/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, Febuary 2018
 */

#version 120
#extension GL_EXT_gpu_shader4 : enable

#define frag
#define composite4
#define ShaderStage 14

#include "/InternalLib/Syntax.glsl"

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;

uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float frameTime;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;

uniform int frameCounter;

#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Uniform/Matrices.glsl"
#include "/InternalLib/Debug.glsl"
#include "/InternalLib/Misc/BicubicTexture.glsl"

#include "/InternalLib/Vertex/WavingTerrain.vsh"

/*******************************************************************************
 - Space Conversions
 ******************************************************************************/

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	return projMAD(projMatrixInverse, screenPos) / (screenPos.z * projMatrixInverse[2].w + projMatrixInverse[3].w);
}

vec3 ViewSpaceToScreenSpace(vec3 viewPos) {
	return projMAD(projMatrix, viewPos) / -viewPos.z * 0.5 + 0.5;
}

float ScreenToViewSpaceDepth(float depth) {
	depth = depth * 2.0 - 1.0;
	return -1.0 / (depth * projMatrixInverse[2][3] + projMatrixInverse[3][3]);
}

/*******************************************************************************
 - Lookups
 ******************************************************************************/

//#define USE_YCOCG	//This actually makes TAA more jittery TODO: Joey please fix!

// https://software.intel.com/en-us/node/503873
vec3 RGB_YCoCg(vec3 c) {
	return vec3(
		c.x  * 0.25 + c.y * 0.5 + c.z * 0.25,
		c.x  * 0.5  - c.z * 0.5,
		-c.x * 0.25 + c.y * 0.5 - c.z * 0.25
	);
}

vec3 YCoCg_RGB(vec3 c) {
	return clamp01(vec3(
		c.x + c.y - c.z,
		c.x + c.z,
		c.x - c.y - c.z
	));
}

vec3 SampleColor(vec2 coord) {
	vec3 c = srgbToLinear(texture2D(colortex0, coord).rgb);

	#ifdef USE_YCOCG
		c = RGB_YCoCg(c);
	#endif

	return c;
}

vec3 SamplePreviousColor(vec2 coord) {
	vec3 c = srgbToLinear(texture2D(colortex4, coord).rgb);

	#ifdef USE_YCOCG
		c = RGB_YCoCg(c);
	#endif

	return c;
}

vec3 ResolveColor(vec3 color) {
	#ifdef USE_YCOCG
		color = YCoCg_RGB(color);
	#endif

	return color;
}

vec3 find_closest_fragment_3x3(vec2 uv, vec2 pixelSize) {
	vec2 dd = abs(pixelSize);
	vec2 du = vec2(dd.x, 0.0);
	vec2 dv = vec2(0.0, dd.y);

	vec3 dtl = vec3(-1, -1, texture2D(depthtex0, uv - dv - du).x);
	vec3 dtc = vec3( 0, -1, texture2D(depthtex0, uv - dv).x);
	vec3 dtr = vec3( 1, -1, texture2D(depthtex0, uv - dv + du).x);

	vec3 dml = vec3(-1, 0, texture2D(depthtex0, uv - du).x);
	vec3 dmc = vec3( 0, 0, texture2D(depthtex0, uv).x);
	vec3 dmr = vec3( 1, 0, texture2D(depthtex0, uv + du).x);

	vec3 dbl = vec3(-1, 1, texture2D(depthtex0, uv + dv - du).x);
	vec3 dbc = vec3( 0, 1, texture2D(depthtex0, uv + dv).x);
	vec3 dbr = vec3( 1, 1, texture2D(depthtex0, uv + dv + du).x);

	vec3 dmin = dtl;
	if (dmin.z > dtc.z) dmin = dtc;
	if (dmin.z > dtr.z) dmin = dtr;

	if (dmin.z > dml.z) dmin = dml;
	if (dmin.z > dmc.z) dmin = dmc;
	if (dmin.z > dmr.z) dmin = dmr;

	if (dmin.z > dbl.z) dmin = dbl;
	if (dmin.z > dbc.z) dmin = dbc;
	if (dmin.z > dbr.z) dmin = dbr;

	return vec3(uv + dd.xy * dmin.xy, dmin.z);
}

/*******************************************************************************
  - TAA
 ******************************************************************************/

vec2 computeCameraVelocity(vec3 screenPos, bool leaves) {
	vec3 projection = mat3(gbufferModelViewInverse) * CalculateViewSpacePosition(screenPos) + gbufferModelViewInverse[3].xyz;

		 if(leaves) projection += CalculateWavingLeaves(projection, TIME) - CalculateWavingLeaves(projection, TIME - frameTime);
		 
	     projection = (cameraPosition - previousCameraPosition) + projection;
	     projection = mat3(gbufferPreviousModelView) * projection + gbufferPreviousModelView[3].xyz;
	     projection = (diagonal3(gbufferPreviousProjection) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;

	return (screenPos.xy - projection.xy);
}

vec3 clipAABB(vec3 aabbMin, vec3 aabbMax, vec3 p, vec3 q) {
	// note: only clips towards aabb center (but fast!)
	vec3 p_clip = 0.5 * (aabbMax + aabbMin);
	vec3 e_clip = 0.5 * (aabbMax - aabbMin) + 1e-8;

	vec3 v_clip = q - p_clip;
	vec3 v_unit = v_clip.xyz / e_clip;
	vec3 a_unit = abs(v_unit);
	float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

	if (ma_unit > 1.0)
		return p_clip + v_clip / ma_unit;
	else
		return q;// point inside aabb
}

vec3 TemporalReprojection(vec2 coord, vec2 velocity, vec2 dd) {
	vec3 previousSample = SamplePreviousColor(coord - velocity);
	
	coord = coord + temporalJitter() * 0.5;
	vec3 currentSample = SampleColor(coord);

	vec2 du = vec2(dd.x, 0.0);
	vec2 dv = vec2(0.0, dd.y);

	//Minmax3x3
	vec3 ctl = SampleColor(coord - dv - du);
	vec3 ctc = SampleColor(coord - dv     );
	vec3 ctr = SampleColor(coord - dv + du);
	vec3 cml = SampleColor(coord      - du);
	vec3 cmc = SampleColor(coord          );
	vec3 cmr = SampleColor(coord      + du);
	vec3 cbl = SampleColor(coord + dv - du);
	vec3 cbc = SampleColor(coord + dv     );
	vec3 cbr = SampleColor(coord + dv + du);

	vec3 cmin5 = min(ctc, min(cml, min(cmc, min(cmr, cbc))));
	vec3 cmax5 = max(ctc, max(cml, max(cmc, max(cmr, cbc))));

	vec3 cmin = min(cmin5, min(ctl, min(ctr, min(cbl, cbr))));
	vec3 cmax = max(cmax5, max(ctl, max(ctr, max(cbl, cbr))));

	//If 3x3rounded YCOCG or clipping
	vec3 cavg = (ctl + ctc + ctr + cml + cmc + cmr + cbl + cbc + cbr) * 0.1111111111;

	//3x3 rounding
	vec3 cavg5 = (ctc + cml + cmc + cmr + cbc) * 0.2;
	cmin = 0.5 * (cmin + cmin5);
	cmax = 0.5 * (cmax + cmax5);
	cavg = 0.5 * (cavg + cavg5);

	#ifdef USE_YCOCG
		float chroma_extent = 0.25 * 0.5 * (cmax.r - cmin.r);
		vec2 chroma_center = currentSample.gb;
		cmin.yz = chroma_center - chroma_extent;
		cmax.yz = chroma_center + chroma_extent;
		cavg.yz = chroma_center;
	#endif

	//Clipping
	previousSample = clipAABB(cmin.xyz, cmax.xyz, clamp(cavg, cmin, cmax), previousSample);

	//Lum, if using YCOCG just r channel
	float currentLum = dot(currentSample, vec3(0.2125, 0.7154, 0.0721));
	float previousLum = dot(previousSample, vec3(0.2125, 0.7154, 0.0721));

	float unbiasedDiff = abs(currentLum - previousLum) / max(currentLum, max(previousLum, 0.2));
	float unbiasedWeightSqr = pow(unbiasedDiff, 0.25);
	float kFeedback = mix(TAA_AGGRESSION, 0.99, unbiasedWeightSqr);

	coord -= velocity;
	if(clamp01(coord) != coord) {
		kFeedback = 0.0;
	}
	
	#ifdef TAA_SHARPEN
		vec3 sharpen = vec3(1.0) - exp(-(currentSample - clamp(cavg, cmin, cmax)));
		currentSample += sharpen * TAA_SHARPNESS;
	#endif

	return ResolveColor(mix(currentSample, previousSample, kFeedback));
}

vec3 CalculateTAA(vec2 coord, bool leaves) {
	#ifndef TAA
		return srgbToLinear(texture2D(colortex0, coord).rgb);
	#endif

	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	vec3 closest = find_closest_fragment_3x3(coord, pixelSize);
	if(closest.z < 0.7) return srgbToLinear(texture2D(colortex0, coord).rgb);
	
	vec2 velocity = computeCameraVelocity(closest, leaves);

	return TemporalReprojection(coord, velocity, pixelSize);
}

/* DRAWBUFFERS:4 */

void main() {
	float depth = texture2D(depthtex0, texcoord).x;
	vec4 sample1 = ScreenTex(colortex1);

	float matFlag = DecodeVec2(sample1.a).y;
	bool leaves = matFlag > 0.45 && matFlag < 0.55 && depth != 1.0;

	//CalculateTAA
	vec3 currentFrame = linearToSrgb(CalculateTAA(texcoord, leaves));

	//Write back to feedback loop
	gl_FragData[0] = vec4(currentFrame, 1.0);
	exit();
}
