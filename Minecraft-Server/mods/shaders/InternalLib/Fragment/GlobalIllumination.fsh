/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, March 2018
 */

vec3 CalculateGlobalIllumination(mat2x3 position, vec3 normal, float dither){
	#if !defined deffered0
		return vec3(0.0);
	#endif

	float weight = 0.0;
	vec3 indirectLight = vec3(0.0);

	float rotateMult = dither * TAU;	//Make sure the offset rotates 360 degrees.

	vec3 shadowSpaceNormal = mat3(shadowModelView) * mat3(gbufferModelViewInverse) * normal * vec3(1.0, 1.0, -1.0);
	vec3 shadowPosition = WorldSpaceToShadowSpace(position[1]) * 2.0 - 1.0;
	     shadowPosition.z *= 4.0;

	float blockDistance = length(position[0]);
	float diffTresh = 0.0025 * pow(smoothstep(0.0, 255.0, blockDistance), 0.75) + 0.0002;

	float giDistanceMask = clamp(1.0 - (blockDistance * 0.003125), 0.0, 1.0);

	const float giSteps = 1.0 / GI_QUALITY;

	vec2 circleDistribution = rotate(vec2(0.03125), rotateMult) * GI_RADIUS;

	for (float i = giSteps; i < 1.0; i += giSteps) {
		weight++;

		vec2 offset = circleDistribution;
			 offset *= 0.0441942 * i*i;

		vec2 offsetPosition = vec2(shadowPosition.xy + offset);
		vec2 biasedPosition = DistortShadowSpaceProj(offsetPosition * 0.5 + 0.5);

		float shadow = texture2D(shadowtex1, biasedPosition).x;
		vec3 sampleVector = vec3(offsetPosition, (shadow * 8.0 - 4.0) + diffTresh) - shadowPosition.xyz;

		float distFromX2 = dot(sampleVector, sampleVector);
		vec3 lPos = sampleVector * inversesqrt(distFromX2);
		float diffuse = clamp01(dot(lPos, shadowSpaceNormal));

		if (diffuse <= 0.0) continue;

		vec3 normalSample    = mat3(shadowModelView) * (texture2D(shadowcolor1, biasedPosition).rgb * 2.0 - 1.0);
			 normalSample.xy = -normalSample.xy;

		float sDir = clamp01(dot(lPos, normalSample.rgb));

		if (sDir <= 0.0) continue;

		float giFalloff = 1.0 / (distFromX2 * 1000.0 + 0.5);

		//float skyLM = normalSample.a - aux;
		//	  skyLM = 0.02 / (max(0.0, skyLM * skyLM) + 0.02);

		indirectLight = pow(texture2D(shadowcolor, biasedPosition).rgb, vec3(2.2)) * sDir * diffuse * giFalloff + indirectLight;
	}

	indirectLight /= weight;
	indirectLight = max(indirectLight * sunColor, 0.0) * giDistanceMask;

	return indirectLight;
}
