/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#include "/InternalLib/Fragment/DiffuseLighting.fsh"

vec3 TransmittedScatteringIntegral(const float opticalDepth, const vec3 coeff) {
    const vec3 a = -coeff / log(2.0);
    const vec3 b = -1.0 / coeff;
    const vec3 c =  1.0 / coeff;

    return exp2(a * opticalDepth * rLOG2) * b + c;
}

float TransmittedScatteringIntegral(const float opticalDepth, const float coeff) {
    const float a = -coeff / log(2.0);
    const float b = -1.0 / coeff;
    const float c =  1.0 / coeff;

    return exp2(a * opticalDepth * rLOG2) * b + c;
}

float CalculateSkyLightValue() {
	float lightValue = clamp01((eyeBrightnessSmooth.y * 0.00416666666666666666667) * 1.5 - 0.5);

	return lightValue * lightValue;
}

struct VolumetricData {
	vec3 sunlightColor;
	vec3 skylightColor;

	vec2 phases;
};

VolumetricData CalculateVolumetricVariables(vec3 viewVector, float VoL) {
	VolumetricData vd;
	vd.phases = vec2(sky_rayleighPhase(VoL), sky_miePhase(VoL, atmosphere_mieg));

	vd.sunlightColor = sunColor;
	vd.skylightColor = skyColor * CalculateSkyLightValue();

	return vd;
}

//Morning fog
float CalculateMorningFogDensity(float height) {
	const float minHeight = 63.0;
	const float morningFogDensity = MORNING_FOG_DENSITY;

	return exp2(-max0(height - minHeight) * MORNING_FOG_FALLOFF) * morningFogDensity * (1.0 - wetness * 0.8);
}

float CalculateRainOD(float centerDistance, const float pr) {
    float maxCenterDist = -max0(centerDistance - pr) * rLOG2;
    return exp2(maxCenterDist * 0.001) * 500.0 * wetness;
}

// Optical depths functions.
vec2 CalculateOpticalDepth(float height, float sunRise) {

	vec2 od = exp2(height * -atmosphere_inverseScaleHeights * rLOG2);
	     od.y += CalculateMorningFogDensity(height) * sunRise;
		 od.y += CalculateRainOD(height, 0.0);

	return od;
}

vec3 CalculateVolumetricShadowing(vec3 shadowPosition) {
	#ifndef VL_COLOURED_SHADOW
		float shadow = float(texture2D(shadowtex1, shadowPosition.xy).x > shadowPosition.z);

		return vec3(shadow);
	#endif

	float shadowSolid = float(texture2D(shadowtex1, shadowPosition.xy).x > shadowPosition.z);
	float shadowGlass = float(texture2D(shadowtex0, shadowPosition.xy).x > shadowPosition.z);

	vec4 shadowColor = texture2D(shadowcolor, shadowPosition.xy);
	vec4 shadowColor1 = texture2D(shadowcolor1, shadowPosition.xy);

	shadowColor.rgb = mix(shadowColor.rgb, vec3(1.0), (shadowColor1.a - 0.4) * 1.66666666666666667);

	return mix(vec3(shadowGlass), shadowColor.rgb, clamp01(shadowSolid - shadowGlass));
}

vec3 CalculateVolumetricShadows(vec3 shadowPosition, vec3 worldPosition, bool isWater) {
	shadowPosition.xy = DistortShadowSpaceProj(shadowPosition.xy);

	vec3 sunVisibility = CalculateVolumetricShadowing(shadowPosition);

	#if defined VL_CLOUD_SHADOW_ENABLE
		sunVisibility *= CloudShadow(worldPosition); // This is really expensive, so yeah.
	#endif

	if(!isWater) return sunVisibility;

	float waterDepth = texture2D(shadowtex0, shadowPosition.xy).x * 8.0 - 4.0;
		  waterDepth = waterDepth * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
		  waterDepth = (transMAD(shadowModelView, worldPosition - cameraPosition)).z - waterDepth;

	if(waterDepth >= 0.0) return sunVisibility;

	return sunVisibility * exp2(waterTransmittanceCoefficient * waterDepth * rLOG2);
}

#define partialWaterAbsorption \
	( exp2(-waterTransmittanceCoefficient * distFront * float(isEyeInWater == 1) * rLOG2) )

vec3 CalculateVolumetricLight(VolumetricData vd, vec3 background, vec3 start, vec3 end, float distFront, float dither) {
	#ifndef VOLUMETRIC_LIGHT
		return background;
	#endif

	const int steps    = VL_QUALITY;
	const float rSteps = 1.0 / steps;

	end = vec3(end.x, min(end.y, 256.0), end.z);

    float sunRise = clamp01(dot(wLightVector, vec3(1.0, 0.0, 0.0)));
	      sunRise = pow4(sunRise);

	vec3 worldIncrement = (end - start) * rSteps;
	vec3 worldPosition  = dither * worldIncrement + start;
	     worldPosition += cameraPosition;

	float stepLength = length(worldIncrement);

	vec3 shadowStart 	 = WorldSpaceToShadowSpace(start);
	vec3 shadowIncrement = (WorldSpaceToShadowSpace(end) - shadowStart) * rSteps;
	vec3 shadowPosition  = dither * shadowIncrement + shadowStart;

	vec3 scatter = vec3(0.0);
	vec3 transmittance = vec3(1.0);

	vd.sunlightColor *= transitionFading;

	for(int i = 0; i < steps; ++i, worldPosition += worldIncrement, shadowPosition += shadowIncrement) {
		vec2 opticalDepth   = CalculateOpticalDepth(worldPosition.y, sunRise) * stepLength;
		vec3 sunVisibility  = CalculateVolumetricShadows(shadowPosition, worldPosition, false);

        mat2x3 scatterCoeffs = mat2x3(
            atmosphere_coefficientsScattering[0] * TransmittedScatteringIntegral(opticalDepth.x, atmosphere_coefficientsAttenuation[0]),
            atmosphere_coefficientsScattering[1] * TransmittedScatteringIntegral(opticalDepth.y, atmosphere_coefficientsAttenuation[1])
        );

		scatter += (vd.sunlightColor * (scatterCoeffs * vd.phases.xy) * sunVisibility + vd.skylightColor * (scatterCoeffs * vec2(phaseg0))) * partialWaterAbsorption * transmittance;
		transmittance *= exp2(mat2x3(atmosphere_coefficientsAttenuation) * -opticalDepth * rLOG2);
	}

	return max0(background * transmittance + scatter);
}

vec3 CalculateAerialLight(VolumetricData vd, mat2x3 position, vec3 background, vec3 increment, float distFront, float dither) {
	#if !defined VOLUMETRIC_LIGHT || !defined AERIAL_VL
		return background;
	#endif

	const int steps    = 4;
	const float rSteps = 1.0 / steps;

    float sunRise = clamp01(dot(wLightVector, vec3(1.0, 0.0, 0.0)));
	      sunRise = pow4(sunRise);

	increment = increment * rSteps;
	vec3 worldPosition = (increment * dither + position[1]) + cameraPosition;
	float stepLength = length(increment);

	vec3 scatter = vec3(0.0);
	vec3 transmittance = vec3(1.0);
	float sunVisibility = 1.0;

	vd.sunlightColor *= transitionFading;

	for(int i = 0; i < steps; ++i, worldPosition += increment) {
		vec2 opticalDepth   = CalculateOpticalDepth(worldPosition.y, sunRise) * stepLength;

		#if defined VL_CLOUD_SHADOW_ENABLE
			sunVisibility  = CloudShadow(worldPosition);
		#endif

        mat2x3 scatterCoeffs = mat2x3(
            atmosphere_coefficientsScattering[0] * TransmittedScatteringIntegral(opticalDepth.x, atmosphere_coefficientsAttenuation[0]),
            atmosphere_coefficientsScattering[1] * TransmittedScatteringIntegral(opticalDepth.y, atmosphere_coefficientsAttenuation[1])
        );

		scatter += (vd.sunlightColor * (scatterCoeffs * vd.phases.xy) * sunVisibility + vd.skylightColor * (scatterCoeffs * vec2(phaseg0)));
        transmittance *= exp2(mat2x3(atmosphere_coefficientsAttenuation) * -opticalDepth * rLOG2);
	}

	return max0(background * transmittance + scatter);
}

vec3 CalculateVolumetricWater(VolumetricData vd, vec3 background, vec3 start, vec3 end, float dither) {
	const int steps    = VL_QUALITY;
	const float rSteps = 1.0 / steps;

	vec3 worldIncrement = (end - start) * rSteps;
	vec3 worldPosition  = dither * worldIncrement + start;
	     worldPosition += cameraPosition;

	float opticalDepth = length(worldIncrement);

	vec3 scatterCoeff = waterScatterCoefficient * TransmittedScatteringIntegral(opticalDepth, waterAbsorptionCoefficient);
	vec3 stepTransmittance = exp2(waterTransmittanceCoefficient * -opticalDepth * rLOG2);

	vec3 shadowStart 	 = WorldSpaceToShadowSpace(start);
	vec3 shadowIncrement = (WorldSpaceToShadowSpace(end) - shadowStart) * rSteps;
	vec3 shadowPosition  = dither * shadowIncrement + shadowStart;

	vec3 scatter = vec3(0.0);
	vec3 transmittance = vec3(1.0);

	vd.sunlightColor *= transitionFading;

	for(int i = 0; i < steps; ++i, worldPosition += worldIncrement, shadowPosition += shadowIncrement) {
		vec3 sunVisibility  = CalculateVolumetricShadows(shadowPosition, worldPosition, true);

		scatter += (vd.sunlightColor * sunVisibility + vd.skylightColor * phaseg0) * transmittance; // Need to add a sunlight phase back here.
		transmittance *= stepTransmittance;
	}
	scatter *= scatterCoeff;

	return max0(background * transmittance + scatter);
}

#undef partialWaterAbsorption
