/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

vec2 CalculateShadowSoftness(inout vec2 blockerDepth, vec3 shadowPosition, float dither, float depthBias, float offsetBias, const int samples, const float sampleSize, const float texelSize, const float maxSpread, const float penumbraAngle) {
	blockerDepth = vec2(0.0);

	for(int i = 0; i < samples; ++i) {
		vec3 offset    = circlemapL((dither + float(i)) * sampleSize, 4096.0 * float(samples));
			 offset.z *= maxSpread * texelSize;

		vec3 coord    = vec3(offset.xy, -offsetBias) * offset.z + shadowPosition;
			 coord.xy = DistortShadowSpaceProj(coord.xy);
			 coord.z -= depthBias;

		blockerDepth = max(blockerDepth, vec2(coord.z) - vec2(texture2D(shadowtex1, coord.xy).x, texture2D(shadowtex0, coord.xy).x));
	}

	return min(blockerDepth * vec2(penumbraAngle), vec2(maxSpread));
}

float CalculateDepthBias(vec3 shadowPosition, vec3 surfaceNormal, float offsetBias, float texelSize) {
	shadowPosition.xy = DistortShadowSpaceProj(shadowPosition.xy);
    vec3 shadowNormal = texture2D(shadowcolor1, (shadowPosition.xy)).xyz * 2.0 - 1.0;
    vec3 surfaceWorldNormal = mat3(gbufferModelViewInverse) * surfaceNormal;
	
	if(texture2D(shadowtex1, shadowPosition.xy).x != texture2D(shadowtex0, shadowPosition.xy).x) return offsetBias;

    return (dot(shadowNormal, surfaceWorldNormal) > 0.1 ? offsetBias : offsetBias);
}

vec3 CalculateShadow(vec3 shadowPosition, float dither, vec2 spread, float offsetBias, float depthBias, const int samples, const float sampleSize, const float texelSize, const float maxSpread) {
	#if SHADOW_TYPE == SHADOW_HARD
		shadowPosition.xy = DistortShadowSpaceProj(shadowPosition.xy);
		shadowPosition.z -= depthBias;

		float surface0 = texture2D(shadowtex0, shadowPosition.xy).x;
		float surface1 = texture2D(shadowtex1, shadowPosition.xy).x;

		float shadowSolid = fstep(shadowPosition.z, surface1);
		float shadowGlass = fstep(shadowPosition.z, surface0);

		vec4 shadowColor 	 = texture2D(shadowcolor, shadowPosition.xy);
			 shadowColor.rgb = pow(shadowColor.rgb, vec3(2.2));

		float shadowColor1Alpha = texture2D(shadowcolor1, shadowPosition.xy).a;

		float waterDepth0 = surface0 * 2.0 - 1.0;
		      waterDepth0 = waterDepth0 * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;

		float waterDepth = surface1 * 2.0 - 1.0;
		      waterDepth = waterDepth * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;

		shadowColor.rgb = mix(shadowColor.rgb, exp2(-waterTransmittanceCoefficient * (waterDepth0 - waterDepth) * 4.0 * rLOG2), clamp01(shadowColor1Alpha * 1.66666666666666667 - 0.66666666666666667));

		return mix(vec3(shadowGlass), shadowColor.rgb, clamp01(shadowSolid - shadowGlass));
	#endif

	spread *= texelSize * (shadowMapResolution * 0.0009765625); //Pixel Size non-distort to a factor of 4.0

	vec3 shadow = vec3(0.0);

	for(int i = 0; i < samples; ++i) {
		vec3 solidOffset = circlemapL((dither + float(i)) * sampleSize, 256.0 * float(samples));
		vec3 transparentOffset = solidOffset;

		solidOffset.z *= spread.x;
		transparentOffset.z *= spread.y;

		vec3 solidCoord    = vec3(solidOffset.xy, -offsetBias) * solidOffset.z + shadowPosition;
			 solidCoord.xy = DistortShadowSpaceProj(solidCoord.xy);
			 solidCoord.z -= depthBias;

		vec3 transparentCoord    = vec3(transparentOffset.xy, -offsetBias) * transparentOffset.z + shadowPosition;
			 transparentCoord.xy = DistortShadowSpaceProj(transparentCoord.xy);
			 transparentCoord.z -= depthBias;

		float surface0 = texture2D(shadowtex0, transparentCoord.xy).x;
		float surface1 = texture2D(shadowtex1, solidCoord.xy).x;

		float shadowSolid = fstep(solidCoord.z, surface1);
		float shadowGlass = fstep(transparentCoord.z, surface0);

		vec4 shadowColor     = texture2D(shadowcolor, transparentCoord.xy);
			 shadowColor.rgb = pow(shadowColor.rgb, vec3(2.2));

		float shadowColor1Alpha = texture2D(shadowcolor1, transparentCoord.xy).a;

		float waterDepth0 = surface0 * 2.0 - 1.0;
		      waterDepth0 = waterDepth0 * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;

	    float waterDepth = surface1 * 2.0 - 1.0;
		      waterDepth = waterDepth * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;

		shadowColor.rgb = mix(shadowColor.rgb, exp2(-waterTransmittanceCoefficient * (waterDepth0 - waterDepth) * 4.0 * rLOG2), clamp01(shadowColor1Alpha * 1.66666666666666667 - 0.66666666666666667));

		shadow += mix(vec3(shadowGlass), shadowColor.rgb, clamp01(shadowSolid - shadowGlass));
	}

	return clamp01(shadow * sampleSize);
}

vec3 CalculateEarlyOut(vec3 shadowPosition, float depthBias, float blockerDepth) {
	return vec3(fstep(shadowPosition.z - depthBias, texture2D(shadowtex1, DistortShadowSpaceProj(shadowPosition.xy)).x));
}

vec3 CalculateShadows(vec3 shadowPosition, vec3 surfaceNormal, float dither, bool isVeg) {
	float NdotL = isVeg ? 1.0 : dot(surfaceNormal, lightVector);
	if (NdotL <= 0.0) return vec3(0.0);
	if (any(greaterThanEqual(abs(vec3(DistortShadowSpaceProj(shadowPosition.xy), shadowPosition.z)), vec3(1.0)))) return vec3(1.0);

	// Constants. The user doesn't ever need to modify these through code, so these are passed in to the functions as constants.
	const int samples = SHADOW_QUALITY;
	const float sampleSize = 1.0 / samples;

	const float maxSpread = SHADOW_PENUMBRA_ANGLE;
	#if SHADOW_TYPE == SHADOW_PCSS
		const float penumbraAngle = SHADOW_PENUMBRA_ANGLE * 4.0;
	#else
		const float penumbraAngle = SHADOW_PENUMBRA_ANGLE * 0.015625;
	#endif

	NdotL = clamp(NdotL, 0.0, 1.0);
	
	float distFactor = 1.0 + length(shadowPosition.xy * 2.0 - 1.0) * ((length((shadowPosition.xy * 2.0 - 1.0) * 1.165) * SHADOW_DISTORTION_FACTOR + (1.0 - SHADOW_DISTORTION_FACTOR)));
	float texelSize = rShadowMapResolution;
		  
	float offsetBias = sqrt(1.0 - NdotL * NdotL) / NdotL + 1.0;
	      offsetBias = sqrt(offsetBias) * texelSize * distFactor * 0.25;

	//float depthBias = CalculateDepthBias(shadowPosition, surfaceNormal, offsetBias, texelSize);
	float depthBias = offsetBias;

	// Shadow spread. This controls how soft shadows appear. Again, the user can override the built-in shadow spread function if they wish.
	#if SHADOW_TYPE == SHADOW_PCSS
		vec2 blockerDepth = vec2(0.0);
		vec2 penumbraSpread = CalculateShadowSoftness(blockerDepth, shadowPosition, dither, depthBias, offsetBias, samples, sampleSize, texelSize, maxSpread, penumbraAngle);
	#else
		vec2 blockerDepth = vec2(1.0);
		vec2 penumbraSpread = vec2(penumbraAngle);
	#endif

	// Early out. Maybe have this on an option, so if the user doesn't want the artifacts that come from this, they can turn this off if they want. Again, the user has control over the value returned if they wish to.
	#if SHADOW_TYPE != SHADOW_HARD
		if(blockerDepth.y <= 0.0) return CalculateEarlyOut(shadowPosition, depthBias, blockerDepth.y);
	#endif

	// And finally, the actual filter itself. Yet again, the user can override this if they wish.
	return CalculateShadow(shadowPosition, dither, penumbraSpread, offsetBias, depthBias, samples, sampleSize, texelSize, maxSpread);
}

