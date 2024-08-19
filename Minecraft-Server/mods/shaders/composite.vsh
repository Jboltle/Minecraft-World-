/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#version 120
#define vert

#include "/InternalLib/Syntax.glsl"

flat varying vec3 sunColor;
flat varying vec3 skyColor;
flat varying vec3 lightVector;

varying vec2 texcoord;
varying vec2 jitter;

varying float transitionFading;

uniform mat4 gbufferModelViewInverse;

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;
uniform vec3 sunPosition;

uniform float viewWidth, viewHeight;
uniform float eyeAltitude;
uniform float wetness;
uniform int worldTime;
uniform int frameCounter;

#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Fragment/Sky.fsh"
#include "/InternalLib/Uniform/TemporalJitter.glsl"

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);

    texcoord = gl_Vertex.xy;
	jitter = temporalJitter() * 0.5;

    lightVector = (worldTime > 23075 || worldTime < 12925 ? sunPosition * 0.01 : -sunPosition * 0.01);

	vec3 viewAbsorb = vec3(1.0);

	// Temp fix for switching shadowmaps between day and night
	transitionFading = clamp01(clamp01(float(worldTime - 23215) / 50.0) + (1.0 - clamp01(float(worldTime - 12735) / 50.0)) + clamp01(float(worldTime - 12925) / 50.0) * (1.0 - clamp01(float(worldTime - 23075) / 50.0)));

	sunColor = GetSunColorZom() + GetMoonColorZom();
	skyColor = vec3(0.0);
	skyColor = sky_atmosphere(vec3(0.0), upPosition * 0.01, upPosition * 0.01, sunPosition * 0.01, -sunPosition * 0.01, sky_sunColor, sky_moonColor, 10, viewAbsorb);
}
