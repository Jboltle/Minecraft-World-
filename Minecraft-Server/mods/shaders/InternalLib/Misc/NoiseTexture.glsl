/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, Febuary 2018
 */
 
 
#ifndef NoiseTextureInclude
#define NoiseTextureInclude

vec3 Get2DNoise(vec2 pos) {
    return texture2D(noisetex, fract(pos)).xyz;
}

vec3 Get2DNoiseSmooth(vec2 pos) {
    const vec2 resolution  = vec2(64.0);
    const vec2 rResolution = 1.0 / resolution;

	pos = pos * resolution + 0.5;

	vec2 whole = floor(pos);
	vec2 part  = pos - whole;

	part *= part * (3.0 - 2.0 * part);

    pos = whole + part;

    pos -= 0.5;
    pos *= rResolution;

    return texture2D(noisetex, fract(pos)).xyz;
}

#if !defined shadow && !defined gbuffers_water
float Get3DNoise(vec3 pos) {
   float p = floor(pos.y);
   float f = pos.y - p;
   
   const float zStretch = 17.0 * invNoiseRes;
   
   vec2 coord = pos.xz * invNoiseRes + (p * zStretch);
   vec2 noise = texture2D(noisetex, coord).xy;
   
   return mix(noise.x, noise.y, f);
}
#endif
#endif
