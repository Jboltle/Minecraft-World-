/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, Febuary 2018
 */

vec3 Raytrace(const vec3 viewSpaceDirection, const vec3 viewSpacePosition, vec3 p, float skyLightmap) {
	const float quality = RAYTRACE_QUALITY;
	int refines = RAYTRACE_REFINES;
	const float maxLength = 1.0 / quality;
	const float minLength = 0.1 / quality;

	// get screen space direction
	vec3 direction = normalize(ViewSpaceToScreenSpace(viewSpacePosition + viewSpaceDirection) - p);
	float rz = 1.0 / abs(direction.z);

	vec3 skyReflection  = DecodeRGBE8(texture2D(colortex3, UnprojectSpherical(mat3(gbufferModelViewInverse) * -viewSpaceDirection) * 0.5));
	     skyReflection *= pow2(skyLightmap);

	float stepLength = minLength;
	float depth = p.z;
	
	int i = 0;

	while(depth >= p.z && i < RAYTRACE_QUALITY + 4) {
		i++;
		stepLength = clamp((depth - p.z) * rz, minLength, maxLength);
		p += direction * stepLength;
		if(clamp01(p) != p) return skyReflection; //early out when offscreen
		depth = texture2D(depthtex1, p.xy).x;
	}

	while(--refines > 0) { // binary search
		vec3 reflectp = p + direction * clamp((depth - p.z) * rz, -stepLength, stepLength);
		float reflectdepth = texture2D(depthtex1, reflectp.xy).x;
		bool isIntersect = reflectdepth < reflectp.z;

		p = isIntersect ? reflectp : p;
		depth = isIntersect ? reflectdepth : depth;

		stepLength *= 0.5;
	}

	//Fuck off it doesnt work anyways leave it.
	
	bool visible = abs(p.z - depth) * min(rz, 400.0) <= maxLength;
	return visible ? DecodeRGBE8(texture2D(colortex2, p.xy)) : skyReflection;
}
