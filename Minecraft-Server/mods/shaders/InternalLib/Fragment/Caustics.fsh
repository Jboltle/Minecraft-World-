vec2 DistributeCausticSamples(const float i, const float numSamples) {
    const float angle = pow(16.0, 2.0) * numSamples * 0.5 * goldenAngle;
    vec2 p = sincos(i * angle);

    return p * (sqrt(i * 0.97 + 0.03) * fsign(p.x));
}

vec3 refract_1_33(vec3 i, vec3 n) {
    const vec4 C = vec4(0.75187969924, -0.666308423880957, 0.7518796992481197, -0.34853799144237796);
    float cosi = dot(-i, n);
    return C.x * i + ((C.w * cosi + C.z) * cosi + C.y) * n;
}

float waterCaustics(vec3 position, vec3 shadowPosition, float waterDepth, float bayer) {
	if (waterDepth <= 0.0) return 1.0;

	position += cameraPosition;

	const int   samples           = 9;
  	const float rSamples          = 1.0 / samples;
	const float radius            = 0.55;
	const float defocus           = 1.05;
	const float distanceThreshold = sqrt(samples * rPI) / (radius * defocus);
	const float resultPower       = 2.0;

	vec4 shadowNormalPreCheck = texture2D(shadowcolor1, shadowPosition.xy);
	if (shadowNormalPreCheck.a < 0.5) return 1.0;

	vec3  lightVector       = mat3(gbufferModelViewInverse) * -lightVector;
	vec3  flatRefractVector = refract_1_33(lightVector, vec3(0.0, 1.0, 0.0));
	float surfDistUp        = waterDepth * abs(lightVector.y);
	float dither            = bayer * rSamples;

	#ifdef CAUSTICS_DEPTH_CLAMPED
	position.xz += flatRefractVector.xz * min(surfDistUp + CAUSTICS_MAX_DEPTH, 0.0);
	surfDistUp = max(surfDistUp, -CAUSTICS_MAX_DEPTH);
	#endif

	vec3 refractCorrection = flatRefractVector * (surfDistUp / flatRefractVector.y);
	vec3 surfacePosition = position - refractCorrection;

	float result = 0.0;
	for (float i = 0.0; i < samples; ++i) {
		vec3 samplePos     = surfacePosition;
		     samplePos.xz += DistributeCausticSamples(i * rSamples + dither, samples) * radius;

	 	vec3 shadowPos = WorldSpaceToShadowSpace(samplePos - cameraPosition + refractCorrection);
			 shadowPos.xy = DistortShadowSpaceProj(shadowPos.xy);

		vec4 shadowSample = texture2D(shadowcolor1, shadowPos.xy);
		vec3 shadowNormal = shadowSample.xyz * 2.0 - 1.0;

		vec3 refractVector = refract_1_33(lightVector, shadowNormal); // Sample from shadow normal.
		     samplePos     = refractVector * (surfDistUp / refractVector.y) + samplePos;

		result += 1.0 - clamp01(distance(position, samplePos) * distanceThreshold);
	}

	return pow(result / (defocus * defocus), resultPower);
}
