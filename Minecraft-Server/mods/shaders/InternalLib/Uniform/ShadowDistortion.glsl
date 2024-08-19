/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#define SHADOW_DISTORTION_FACTOR 0.85 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95]

vec2 DistortShadowSpace(vec2 p) {
	return p / (length(p.xy * 1.165) * SHADOW_DISTORTION_FACTOR + (1.0 - SHADOW_DISTORTION_FACTOR));
}

vec2 DistortShadowSpaceProj(vec2 p) {
	p = p * 2.0 - 1.0;

	return (p / (length(p.xy * 1.165) * SHADOW_DISTORTION_FACTOR + (1.0 - SHADOW_DISTORTION_FACTOR))) * 0.5 + 0.5;
}

#if !defined shadow	
	vec3 WorldSpaceToShadowSpace(vec3 p) {
	//	vec4 w = vec4(p, 0.0);
	//	w = gbufferProjection * gbufferModelView * w;
	//	vec2 ebin = temporalJitter() * w.w;
	//	w.xy -= ebin;
	//	w = gbufferModelViewInverse * gbufferProjectionInverse * w;
	//	p = w.xyz;

		p = mat3(shadowModelView) * p + shadowModelView[3].xyz;
		p = diagonal3(shadowProjection) * p + shadowProjection[3].xyz;
		p.z *= 0.25;

		return p * 0.5 + 0.5;
	}
#endif
