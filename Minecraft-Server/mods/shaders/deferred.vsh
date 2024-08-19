/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#version 120
#define vert

#include "/InternalLib/Syntax.glsl"

varying mat3x4 skySH;

flat varying vec3 sunColor;
flat varying vec3 moonColor;
flat varying vec3 skyColor;
flat varying vec3 lightVector;

varying vec2 texcoord;
varying vec2 jitter;

varying float transitionFading;

uniform mat4 gbufferModelView;
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


vec4 ToSH(float value, vec3 dir) {
    const float transferl1 = 0.3849 * PI;
    const float sqrt1OverPI = sqrt(rPI);
    const float sqrt3OverPI = sqrt(rPI * 3.0);

    const vec2 halfnhalf = vec2(0.5, -0.5);
    const vec2 transfer = vec2(PI * sqrt1OverPI, transferl1 * sqrt3OverPI);

    const vec4 foo = halfnhalf.xyxy * transfer.xyyy;

    return foo * vec4(1.0, dir.yzx) * value;
}


void CalculateSkySH(vec3 viewAbsorb, vec3 skyColor) {
	const int latSamples = 5;
	const int lonSamples = 5;
	const float rLatSamples = 1.0 / latSamples;
	const float rLonSamples = 1.0 / lonSamples;
	const float sampleCount = rLatSamples * rLonSamples;

	const float latitudeSize = rLatSamples * PI;
	const float longitudeSize = rLonSamples * TAU;

	vec4 shR = vec4(0.0), shG = vec4(0.0), shB = vec4(0.0);
	const float offset = 0.1;

	for (int i = 0; i < latSamples; ++i) {
		float latitude = float(i) * latitudeSize;

		for (int j = 0; j < lonSamples; ++j) {
			float longitude = float(j) * longitudeSize;

			float c = cos(latitude);
			vec3 kernel = vec3(c * cos(longitude), sin(latitude), c * sin(longitude));

			vec3 skyCol = sky_atmosphere(vec3(0.0), mat3(gbufferModelView) * normalize(kernel + vec3(0.0, offset, 0.0)), upPosition * 0.01, sunPosition * 0.01, -sunPosition * 0.01, sky_sunColor, sky_moonColor, 10, viewAbsorb);

			 shR += ToSH(skyCol.r, kernel);
			 shG += ToSH(skyCol.g, kernel);
			 shB += ToSH(skyCol.b, kernel);
		}
	}

	skySH = mat3x4(shR, shG, shB) * sampleCount;
}

void main() {
	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);

    texcoord = gl_Vertex.xy;
	jitter = temporalJitter() * 0.5;

	vec3 viewAbsorb = vec3(1.0);
	skyColor = vec3(0.0);

    lightVector = (worldTime > 23075 || worldTime < 12925 ? sunPosition * 0.01 : -sunPosition * 0.01);

	// Temp fix for switching shadowmaps between day and night
	transitionFading = clamp01(clamp01(float(worldTime - 23215) / 50.0) + (1.0 - clamp01(float(worldTime - 12735) / 50.0)) + clamp01(float(worldTime - 12925) / 50.0) * (1.0 - clamp01(float(worldTime - 23075) / 50.0)));

	sunColor = (GetSunColorZom() + GetMoonColorZom());
	skyColor = sky_atmosphere(vec3(0.0), upPosition * 0.01, upPosition * 0.01, sunPosition * 0.01, -sunPosition * 0.01, sky_sunColor, sky_moonColor, 10, viewAbsorb);

	CalculateSkySH(viewAbsorb, skyColor);
}
