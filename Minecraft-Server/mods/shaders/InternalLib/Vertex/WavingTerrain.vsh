/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, March 2018
 */

#define WAVING_GRASS
#define WAVING_LEAVES


#if defined gbuffers_terrain || defined shadow
vec3 CalculateWavingGrass(vec3 worldPosition, const bool doubleTall) {
    #ifndef WAVING_GRASS
        return vec3(0.0);
    #endif

    float time = TIME;

    bool topVertex = texcoord.t < mc_midTexCoord.t;
    bool topBlock  = mc_Entity.x == 176.0;

    float magnitude = 1.0;

    if(doubleTall)
        magnitude *= mix(mix(0.0, 0.6, float(topVertex)), mix(0.6, 1.2, float(topVertex)), float(topBlock));
    else
        magnitude *= float(topVertex);

    vec3 wave = vec3(0.0);

    float intensity = sin((time * 2.24399475256) + worldPosition.x + worldPosition.z) * 0.1 + 0.1;

    float d0 = sin(time * 0.515015189115) * 3.0 - 1.5 + worldPosition.z;
    float d1 = sin(time * 0.413367454418) * 3.0 - 1.5 + worldPosition.x;
    float d2 = sin(time * 0.515015189115) * 3.0 - 1.5 + worldPosition.x;
    float d3 = sin(time * 0.413367454418) * 3.0 - 1.5 + worldPosition.z;

    wave.x += sin((time * 2.24399475256) + (worldPosition.x + d0) * 0.1 + (worldPosition.z + d1) * 0.1) * intensity;
    wave.z += sin((time * 2.24399475256) + (worldPosition.z + d2) * 0.1 + (worldPosition.x + d3) * 0.1) * intensity;

    return wave * magnitude;
}
#endif

vec3 CalculateWavingLeaves(vec3 worldPosition, float frametime) {
    #ifndef WAVING_LEAVES
        return vec3(0.0);
    #endif
    float time = frametime;

    vec3 wave = vec3(0.0);
    const float magnitude = 0.9;

    float intensity = sin(((worldPosition.y + worldPosition.x) * 0.5 + (time * 0.0356999165181))) * 0.0175 + 0.0525;

	float d0 = sin(time * 0.367867992224) * 3.0 - 1.5;
	float d1 = sin(time * 0.295262467443) * 3.0 - 1.5;
	float d2 = sin(time * 0.233749453392) * 3.0 - 1.5;
	float d3 = sin(time * 0.316055598953) * 3.0 - 1.5;

	wave.x += sin((time * 2.80499344071) + (worldPosition.x + d0) * 0.5 + (worldPosition.z + d1) * 0.5 + worldPosition.y) * intensity;
	wave.z += sin((time * 2.49332750285) + (worldPosition.z + d2) * 0.5 + (worldPosition.x + d3) * 0.5 + worldPosition.y) * intensity;
	wave.y += sin((time * 4.48798950513) + (worldPosition.z + d2)       + (worldPosition.x + d3)                        ) * intensity * 0.5;

    return wave * magnitude;
}
