/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, Febuary 2018
 */

#include "/InternalLib/Misc/NoiseTexture.glsl"

//Globals (These are bad use as few as possible)
float time = TIME * VOLUMETRIC_CLOUDS_SPEED;
vec3 wLightVector = mat3(gbufferModelViewInverse) * lightVector;

//Structs

struct VolumetricCloudSettings {
	float minAltitude;
	float maxAltitude;
	float cloudHeight;
	float cloudCoverage;
	float cloudDensity;
	float cloudScale;
};

float remap(float value, const float originalMin, const float originalMax, const float newMin, const float newMax) {
	return (((value - originalMin) / (originalMax - originalMin)) * (newMax - newMin)) + newMin;
}

float powder(float sampleDensity, float VoL) {
	float powd = 1.0 - exp2(-sampleDensity * 2.0);
	return mix(1.0, powd, clamp01(-VoL * 0.5 + 0.5));
}

//Mie constants
#define gMultiplierClouds 0.7
#define mixergClouds 0.8

float phaseg8(float x) {
	const float g = 0.8 * gMultiplierClouds;
	const float g2 = g * g;
	const float g3 = log2((g2 * -0.25 + 0.25) * mixergClouds);
	const float g4 = 1.0 + g2;
	const float g5 = -2.0 * g;

	return exp2(log2(g5 * x + g4) * -1.5 + g3);
}

float phasegm5(float x) {
	const float g = -0.5 * gMultiplierClouds;
	const float g2 = g * g;
	const float g3 = log2((g2 * -0.25 + 0.25) * (1.0 - mixergClouds));
	const float g4 = 1.0 + g2;
    const float g5 = -2.0 * g;

    return exp2(log2(g5 * x + g4) * -1.5 + g3);
}

float phase2lobes(float x) {
    return phaseg8(x) + phasegm5(x);
}

const float rad = radians(105.0);
const mat2 rotateMatrix = mat2(
	cos(rad), -sin(rad),
	sin(rad),  cos(rad)
);

//Cloud FBM
float getCloudNoise(vec3 position, const bool isLowQ) {
	position.xz *= rotateMatrix;
	const mat4x3 cloudMul = mat4x3(vec3(0.6),
	                         vec3(15.0),
	                         vec3(5.0),
	                         vec3(8.0));

	mat4x3 CloudAdd = mat4x3(vec3(time * 0.5),
	                         vec3(0.0, 0.0, time * 2.0),
	                         vec3(time * -0.5),
	                         vec3(0.0, -time, 0.0));

	float cloudNoise = Get3DNoise(position * cloudMul[0] + CloudAdd[0]);
	position.xz *= rotateMatrix;
	cloudNoise += Get3DNoise(position * cloudMul[2] + CloudAdd[2]) * 0.25;

	if (!isLowQ) {
		cloudNoise += Get3DNoise(position * cloudMul[3] + CloudAdd[3]) * 0.1;
		cloudNoise += Get3DNoise(position * cloudMul[1] + CloudAdd[1]) * 0.05;

	#ifdef HQ_CLOUD_FBM
		position.xz *= rotateMatrix;
		cloudNoise += Get3DNoise(position * 16.0) * 0.05;
		cloudNoise -= Get3DNoise(position * 20.0) * 0.05;
	#endif
		return cloudNoise;
	}

	cloudNoise += 0.1;

	return cloudNoise;
}

//Volumetric cloud modifiers
float GetVolumetricClouds(vec3 position, const VolumetricCloudSettings vcs, const bool isLowQ) {
#ifndef VOLUMETRIC_CLOUDS
	return 0.0;
#endif

	if (position.y < vcs.minAltitude || position.y > vcs.maxAltitude) return 0.0;

	vec3 p = position * 0.00066666666666 / vcs.cloudScale - vec3(time, 0.0, time);

	float cumulusClouds = getCloudNoise(p, isLowQ);

	float height = position.y - vcs.minAltitude;
	float scaledHeight = height / vcs.cloudHeight;

	//float localCoverage = clamp01(texture2D(noisetex, (p.xz + vec2(time * 4.0, -time * 2.0)) * 0.001).x * 2.0 - 1.2);
	float localCoverage = 0.0;

	float heightAtten = remap(scaledHeight, 0.0, 0.4, 0.0, 1.0) * remap(scaledHeight, 0.6, 1.0, 1.0, 0.0);
	cumulusClouds = max0(cumulusClouds * heightAtten - 0.65
	                       - vcs.cloudCoverage + (wetness * 0.4) + localCoverage);

	return cubesmooth(cumulusClouds);
}

float CalculateCloudSunVisibility(vec3 position, const VolumetricCloudSettings vcs, const int steps) {
	float stepSize = vcs.cloudHeight / steps;

	vec3 increment = wLightVector * stepSize;

	float opticalDepth = 0.0;

	for (int i = 0; i < steps; i++) {
		position += increment;
		opticalDepth += GetVolumetricClouds(position, vcs, true);
	}

	return exp2(-opticalDepth * stepSize * vcs.cloudDensity * rLOG2);
}

float CalculateCloudSkyVisibility(vec3 position, const VolumetricCloudSettings vcs) { // 0.125 helps make clouds look like they have multiple scattering
#if VOLUMETRIC_CLOUDS_INDIRECT_QUALITY == VCL_LOW
	return exp2(-vcs.cloudDensity * clamp(vcs.cloudHeight - position.y, 0.0, vcs.minAltitude) * rLOG2 * 0.125);
#endif

	const int   steps = VOLUMETRIC_CLOUDS_INDIRECT_QUALITY;
	const float stepSize = vcs.cloudHeight / steps;

	const vec3 increment = vec3(0.0, 1.0, 0.0) * stepSize;

	float opticalDepth = 0.0;

	for (int i = 0; i < steps; i++) {
		position += increment;
		opticalDepth += GetVolumetricClouds(position, vcs, true);
	}

	return exp2(-opticalDepth * stepSize * vcs.cloudDensity * rLOG2 * 0.125);
}

vec3 CalculateCloudScattering(vec3 position, vec3 directColor, vec3 skyLight, float phase, float VoL, const VolumetricCloudSettings vcs, float odSample, const int dirLightSteps) {
	vec3 sunLighting    = directColor * (CalculateCloudSunVisibility(position, vcs, dirLightSteps) * powder(odSample, VoL)) * phase * TAU; //2.0 PI to help simulate multiple scattering.
	vec3 skyLighting    = skyLight * CalculateCloudSkyVisibility(position, vcs) * phaseg0 * PI;

	return (sunLighting + skyLighting);
}

const float cloudAltitude = VOLUMETRIC_CLOUDS_ALTITUDE;
const float cloudScale = cloudAltitude / 1600.0;
const float cloudHeight = 3000.0 * cloudScale * VOLUMETRIC_CLOUDS_HEIGHT;
const float cloudCoverage = 1.0 / VOLUMETRIC_CLOUDS_COVERAGE;
const float cloudDensity = 0.015 / cloudScale * VOLUMETRIC_CLOUDS_DENSITY;

vec3 CalculateVolumetricClouds(vec3 background, vec3 sky, vec3 directColor, mat2x3 backPosition, float depth, float dither, float arealLength, const int steps, const int dirLightSteps) {
#ifndef VOLUMETRIC_CLOUDS
	return background;
#endif

	const float maxAltitude = cloudAltitude + cloudHeight;
	const float cloudScale = cloudAltitude / 1600.0;

	const VolumetricCloudSettings vcs = VolumetricCloudSettings(cloudAltitude, maxAltitude, cloudHeight, cloudCoverage, cloudDensity, cloudScale);
	vec3 worldVector = normalize(backPosition[1]);

	if (worldVector.y <= 0.0 && cameraPosition.y <= vcs.minAltitude) return background;
	if (worldVector.y >= 0.0 && cameraPosition.y >= vcs.maxAltitude) return background;

	float VoL = dotNorm(backPosition[0], lightVector);
	float phase = phase2lobes(VoL);

	float rSteps = 1.0 / steps;

	vec3 startPosition = backPosition[1] * (vcs.minAltitude - cameraPosition.y) / backPosition[1].y;

	if (cameraPosition.y >= vcs.minAltitude && cameraPosition.y <= vcs.maxAltitude) {
		startPosition = vec3(0.0);
	} else if (cameraPosition.y >= vcs.maxAltitude) {
		startPosition = backPosition[1] * (vcs.maxAltitude - cameraPosition.y) / backPosition[1].y;
	}

	startPosition = depth >= 1.0 ? startPosition : gbufferModelViewInverse[3].xyz;

	vec3 increment = worldVector * vcs.cloudHeight * rSteps / clamp01(abs(worldVector.y));
	     increment = depth >= 1.0 ? increment : (backPosition[1] - startPosition) * rSteps;

	vec3 position  = increment * dither + startPosition + cameraPosition;
	float stepSize = length(increment);

	vec3 skyLight = skyColor;

	//* Should be a bit faster. Previous version commented out below for comparison, might not be noticably faster though.
	float transmittance = 1.0;
	vec3  scattering    = vec3(0.0);

	for (int i = 0; i < steps; i++, position += increment) {
		float odSample = GetVolumetricClouds(position, vcs, false) * vcs.cloudDensity * stepSize;
		if (-odSample >= 0.0) continue;

		vec3 cloudScattering = CalculateCloudScattering(position, directColor, skyLight, phase, VoL, vcs, odSample, dirLightSteps);

		float sampleTransmittance = exp2(-odSample * rLOG2);
		scattering += cloudScattering * (-transmittance * sampleTransmittance + transmittance);
		transmittance *= sampleTransmittance;
	}

	vec3 back1 = background * transmittance + scattering;
	return mix(back1, (depth >= 1.0) ? sky : background, 1.0 - exp2(-length(startPosition) * 0.0000166666666667));

}

//lighting functions
float CloudShadow(vec3 position) {
	#if !defined VOLUMETRIC_CLOUDS_SHADOWS || !defined VOLUMETRIC_CLOUDS
		return 1.0;
	#endif

	const float maxAltitude = cloudAltitude + cloudHeight;
	const VolumetricCloudSettings vcs = VolumetricCloudSettings(cloudAltitude, maxAltitude, cloudHeight, cloudCoverage, cloudDensity, cloudScale);

	const int steps = VOLUMETRIC_CLOUDS_SHADOWS_STEPS;
	const float stepSize = vcs.cloudHeight / steps;

	float stepLength = stepSize / max(1e-7, wLightVector.y);
	vec3 increment = wLightVector * stepLength;
	float sampleLength = length(increment);

	position += position.y <= vcs.minAltitude ? wLightVector * ((vcs.minAltitude - position.y) / wLightVector.y) : vec3(0.0);

	const float fade = 10000.0;
	float opticalDepth = 0.0;

	for (int i = 0; i < steps; i++) {
		position += increment;
		opticalDepth += GetVolumetricClouds(position, vcs, true);
	}

	return max(0.05 * wetness, exp2(-opticalDepth * stepLength * vcs.cloudDensity * rLOG2) * smoothstep(fade*0.5 + fade, fade, sampleLength));
}
