/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

 /*******************************************************************************
  - Geometry Terms
  ******************************************************************************/

float ExactCorrelatedG2(float alpha2, float NoV, float NoL) {
    float x = 2.0 * NoL * NoV;
    float y = (1.0 - alpha2);

    return x / (NoV * sqrt(alpha2 + y * (NoL * NoL)) + NoL * sqrt(alpha2 + y * (NoV * NoV)));
}

float HammonCorrelatedG2(float alpha, float NoV, float NoL) {
    float x = 2.0 * NoL * NoV;

    return x / ((NoL + NoV - x) * alpha + x);
}

/*******************************************************************************
 - Fresnel
 ******************************************************************************/

float SchlickFresnel(float f0, float f90, float LoH) {
    return (f90 - f0) * pow5(1. - LoH) + f0;
}

vec3 ExactFresnel(const vec3 n, const vec3 k, float c) {
    const vec3 k2= k * k;
	const vec3 n2k2 = n * n + k2;

    vec3 c2n = (c * 2.0) * n;
    vec3 c2 = vec3(c * c);

    vec3 rs_num = n2k2 - c2n + c2;
    vec3 rs_den = n2k2 + c2n + c2;

    vec3 rs = rs_num / rs_den;

    vec3 rp_num = n2k2 * c2 - c2n + 1.0;
    vec3 rp_den = n2k2 * c2 + c2n + 1.0;

    vec3 rp = rp_num / rp_den;

    return clamp01(0.5 * (rs + rp));
}

vec3 ExactFresnelF0(const vec3 f0, const float LoH){
    vec3 f = sqrt(f0);
    vec3 f01 = f + 1.0;
    vec3 f0n1 = f - 1.0;

    vec3 alpha = f0n1 * f0n1 * (1.0 - LoH * LoH) / (f01 * f01);
    vec3 f01a = f01 * alpha;
    vec3 f0n1a = f0n1 * alpha;

    vec3 x_num = f01 * LoH + f0n1a;
    vec3 x_den = f01 * LoH - f0n1a;
    vec3 x = x_num / x_den;

    vec3 y_num = f0n1 * LoH + f01a;
    vec3 y_den = f0n1 * LoH - f01a;
    vec3 y = y_num / y_den;

    return clamp01(0.5 * (y * y + x * x));
}

vec3 Fresnel(float f0, float f90, float LoH, vec3 albedo) {
    int matID = int(f0 * 255.0);
    switch(matID) {
        case 230: // Iron
            return ExactFresnel(vec3(2.9114, 2.9497, 2.5845), vec3(3.0893, 2.9318, 2.7670), LoH);
        case 231: // Gold
            return ExactFresnel(vec3(0.18299, 0.42108, 1.3734), vec3(3.4242, 2.3459, 1.7704), LoH);
        case 232: // Aluminum
            return ExactFresnel(vec3(1.3456, 0.96521, 0.61722), vec3(7.4746, 6.3995, 5.3031), LoH);
        case 233: // Chrome
            return ExactFresnel(vec3(3.1071, 3.1812, 2.3230), vec3(3.3314, 3.3291, 3.1350), LoH);
        case 234: // Copper
            return ExactFresnel(vec3(0.27105, 0.67693, 1.3164), vec3(3.6092, 2.6248, 2.2921), LoH);
        case 235: // Lead
            return ExactFresnel(vec3(1.9100, 1.8300, 1.4400), vec3(3.5100, 3.4000, 3.1800), LoH);
        case 236: // Platinum
            return ExactFresnel(vec3(2.3757, 2.0847, 1.8453), vec3(4.2655, 3.7153, 3.1365), LoH);
        case 237: // Silver
            return ExactFresnel(vec3(0.15943, 0.14512, 0.13547), vec3(3.9291, 3.1900, 2.3808), LoH);
        case 255: // Other Metal (use albedo as F0)
            return ExactFresnelF0(albedo, LoH);
        default:
            return vec3(SchlickFresnel(f0, f90, LoH));
    }
}

/*******************************************************************************
 - Distribution
 ******************************************************************************/

float GGX(float alpha2, float NoH) {
	float d = (NoH * alpha2 - NoH) * NoH + 1.0;

	return alpha2 / (d * d);
}

vec3 MakeSample(const float p, const float alpha2, const int steps) {
	#ifdef SPECULAR_CLAMP
		float px = mix(p, 0.0, SPECULAR_TAIL_CLAMP);
	#else
		float px = p;
	#endif

    float x = (alpha2 * px) / (1.0 - px);
    float y = p * float(steps) * 64.0 * 64.0 * goldenAngle;

    float c = inversesqrt(x + 1.0);
    float s = sqrt(x) * c;

    return vec3(cos(y) * s, sin(y) * s, c);
}

/*******************************************************************************
 - Helpers
 ******************************************************************************/

float ComputeLod(int numSamples, float alpha2, float NoH) {
	return 0.125 * (log2(float(viewWidth * viewHeight) / numSamples) - log2(GGX(alpha2, NoH)));
}

vec3 BlendMaterial(vec3 Kdiff, vec3 Kspec, vec3 diffuseColor, float f0) {
	if(f0 < 0.004) return Kdiff;
	
    float scRange = smoothstep(0.25, 0.45, f0);
    vec3  dielectric = Kdiff + Kspec;
    vec3  metal = diffuseColor * Kspec;

    return mix(dielectric, metal, scRange);
}

vec3 CalclulateBRDF(vec3 viewVector, vec3 L, vec3 normal, vec3 albedo, float alpha2, float f0) {
	alpha2 = clamp(alpha2, 1e-8, 1.0);
    vec3 H = normalize(L + viewVector);

    float NoL = clamp01(dot(normal, L));
    float NoV = abs(dot(normal, viewVector) + 1e-6);
    float NoH = clamp01(dot(normal, H));
    float VoH = clamp01(dot(H, L));

    return max0((Fresnel(f0, 1.0, VoH, albedo) * GGX(alpha2, NoH)) * ExactCorrelatedG2(alpha2, NoV, NoL) / (4.0 * NoL * NoV)) * NoL;
}

/*******************************************************************************
 - Specular Lighting
 ******************************************************************************/
 
float getRainPuddles(vec3 p, vec3 normal, float skyLightmap) {
	#ifndef	RAIN_PUDDLES
		return 0.0;
	#endif
	if (wetness <= 0.0) return 0.0;
	vec2 noisePosition = p.xz + cameraPosition.xz;
	     noisePosition = noisePosition * 0.004;

	float cover = smoothstep(0.8, 0.95, skyLightmap);

	float noise = texture2D(noisetex, noisePosition).x;
	      noise += texture2D(noisetex, noisePosition * 2.0).x * 0.5;
	      noise += texture2D(noisetex, noisePosition * 8.0).x * 0.125;

          noise = clamp01(noise * (1.4 * clamp01(wetness * 3.0)) - 0.7);
          noise *= dot(normal, upPosition * 0.01);

	return noise * cover;
}

#if !defined deffered0

#include "/InternalLib/Fragment/Raytracer.fsh"

void CalculateSpecularReflections(io vec3 color, vec3 diffuseColor, mat2x3 position, vec3 viewVector, vec3 clipPosition, vec3 normal, float roughness, float f0, float skyLightmap, vec3 shadows, float dither, bool isTransparent) {
	const int steps = SPECULAR_QUALITY;
	const float rSteps = 1.0 / float(steps);
	float alpha = roughness * roughness;
	float alpha2 = clamp(alpha * alpha, 1e-8, 1.0);

    vec3 colorSun = sunColor;

	if(isTransparent && f0 < 0.004) { color = BlendMaterial(color, vec3(CalclulateBRDF(viewVector, lightVector, normal, diffuseColor, alpha2, f0)) * shadows * colorSun, diffuseColor, f0); return; }
	if(f0 < 0.004) return;
	
	#if RAYTRACE_QUALITY == RAYTRACE_MINIMUM
		return;
	#endif

	float NoV = clamp01(dot(normal, viewVector));

	vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
	mat3 tbn = mat3(tangent, cross(normal, tangent), normal);

	float offset = dither * rSteps;
	vec3 reflection = vec3(0.0);

	for(int i = 0; i < steps; ++i) {
		vec3 halfVector = tbn * MakeSample((offset + float(i)) * rSteps, alpha2, steps);

		float VoH = dot(viewVector, halfVector);
		vec3 lightDirection = (2.0 * VoH) * halfVector - viewVector;
		float NoL = clamp01(dot(normal, lightDirection));
		float G = ExactCorrelatedG2(alpha2, NoV, NoL);

		reflection += Raytrace(lightDirection, position[0], clipPosition, skyLightmap) * Fresnel(f0, 1.0, VoH, diffuseColor) * G * rSteps;
	}

	 if(isTransparent || f0 > 0.5) reflection += CalclulateBRDF(viewVector, lightVector, normal, diffuseColor, alpha2, f0) * colorSun * shadows;
	 color = BlendMaterial(color, max0(reflection), diffuseColor, f0);
}

#endif
