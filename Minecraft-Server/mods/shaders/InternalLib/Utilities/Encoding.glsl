/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

float EncodeVec2(vec2 a) {
	const vec2 constant1 = vec2(1.0, 256.0) / 65535.0; //2^16-1
	return dot(floor(a * 255.0), constant1);
}

float EncodeVec2(float x,float y) {
	return EncodeVec2(vec2(x,y));
}

vec2 DecodeVec2(float a) {
	const vec2 constant1 = 65535.0 / vec2(256.0, 65536.0);
	const float constant2 = 256.0 / 255.0;
	return fract(a * constant1) * constant2;
}

float EncodeNormal(vec3 a) {
    vec3 b = abs(a);
    vec2 p = a.xy / (b.x + b.y + b.z);
    vec2 encoded = a.z <= 0. ? (1. - abs(p.yx)) * fsign(p) : p;
    encoded = encoded * .5 + .5;
	return EncodeVec2(encoded);
}

vec3 DecodeNormal(float encoded) {
	vec2 a = DecodeVec2(encoded);
	     a = a * 2.0 - 1.0;
	vec2 b = abs(a);
	float z = 1.0 - b.x - b.y;

	return normalize(vec3(z < 0.0 ? (1.0 - b.yx) * fsign(a) : a, z));
}

vec3 DecodeNormal(float encoded, mat4 gbufferModelView) {
	return mat3(gbufferModelView) * DecodeNormal(encoded);
}

vec4 EncodeRGBE8(vec3 rgb) {
    float exponentPart = floor(log2(max(max(rgb.r, rgb.g), rgb.b)));
    vec3  mantissaPart = clamp((128.0 / 255.0) * rgb / exp2(exponentPart), 0.0, 1.0);
          exponentPart = clamp((exponentPart + 127.0) / 255.0, 0.0, 1.0);

    return vec4(mantissaPart, exponentPart);
}

vec3 DecodeRGBE8(vec4 rgbe) {
    float exponentPart = exp2(rgbe.a * 255.0 - 127.0);
    vec3  mantissaPart = (510.0 / 256.0) * rgbe.rgb;

    return exponentPart * mantissaPart;
}

const vec2 EncodeHalfBits = vec2(6.0, 10.0);
const vec2 EncodeHalfValues = exp2(EncodeHalfBits);
const vec2 EncodeHalfMaxValues = (EncodeHalfValues - 1.0);

const vec2 rEncodeHalfMaxValues = (1.0 / EncodeHalfMaxValues);
const vec2 EncodeHalfPositions = vec2(1.0, EncodeHalfValues.x);
const vec2 rEncodeHalfPositions = (65535.0 / EncodeHalfPositions);

float EncodeFloat(float x) {
    float exponentPart = floor(log2(x));
    float mantissaPart = clamp(x * exp2(-exponentPart) - 1.0, 0.0, 1.0);
          exponentPart = clamp((exponentPart + 49.0) * 0.015625, 0.0, 1.0);
    
    return dot(floor(vec2(exponentPart, mantissaPart) * EncodeHalfMaxValues + 0.5), EncodeHalfPositions / 65535.0);
}

float DecodeFloat(float x) {
    vec2 var = mod(x * rEncodeHalfPositions, EncodeHalfValues) * rEncodeHalfMaxValues;
    float exponent = var.x * 64.0 - 49.0;
    float mantissa = var.y + 1.0;
    
    return exp2(exponent) * mantissa;
}