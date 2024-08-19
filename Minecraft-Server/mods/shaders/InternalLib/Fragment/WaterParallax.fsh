/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, Febuary 2018
 */

vec3 GetWaterParallaxCoord(vec3 position, vec3 viewVector) {
    #ifndef WATER_PARALLAX
        return position;
    #endif

    const int iterations    = WATER_PARALLAX_SAMPLES;
    const float rIterations = 1.0 / iterations;

    const float depth = WATER_PARALLAX_DEPTH * rIterations * 6.0;
	float dist = inversesqrt(dot(viewVector, viewVector));

	vec2 offset = viewVector.xy * (dist * depth);

    for(int i = 0; i < iterations; ++i) {
        position.xz = GetWavesHeight(position) * offset - position.xz;
    }

    return position;
}
