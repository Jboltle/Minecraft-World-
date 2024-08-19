/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

//http://gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
#define ggxDiffuse_facing LoV * 0.5 + 0.5
#define ggxDiffuse_rough (ggxDiffuse_facing * (0.9 - 0.4 * ggxDiffuse_facing) * clamp01(0.5 / NoH + 1.0))
#define ggxDiffuse_smooth 1.05 * (1.0 - pow5(1.0 - NoL)) * (1.0 - pow5(1.0 - NoV))
#define ggxDiffuse_single (mix(ggxDiffuse_smooth, ggxDiffuse_rough, alpha))

float ggxDiffuseModifier(float alpha, float NoL, float NoV, float NoH, float LoV) {
    return 0.1159 * alpha + ggxDiffuse_single;
}

vec3 ggxDiffuse(vec3 diffuseColor, float NoH, float NoV, float LoV, float NoL, float alpha) {
    float multi = 0.1159 * alpha;
    return diffuseColor * (diffuseColor * multi + ggxDiffuse_single);
}

vec3 ggxDiffuse(vec3 diffuseColor, vec3 V, vec3 L, vec3 N, float alpha) {
    float NoH = dotNorm(V + L, N);
    float NoV = dot(V, N);
    float LoV = dot(L, V);
    float NoL = dot(L, N);
	
    return ggxDiffuse(diffuseColor, NoH, NoV, LoV, NoL, alpha) * clamp01(NoL);
}

#if defined deffered0
#include "/InternalLib/Fragment/SkyLighting.fsh"
#include "/InternalLib/Fragment/SpecularLighting.fsh"
#endif

#if defined deffered0 || defined composite0

#include "/InternalLib/Uniform/ShadowDistortion.glsl"
#include "/InternalLib/Fragment/Shadows.fsh"
#include "/InternalLib/Fragment/WaterWaves.fsh"
#include "/InternalLib/Fragment/Caustics.fsh"
#include "/InternalLib/Fragment/GlobalIllumination.fsh"

float GetTorchLightmapDistance(float lightmap) {
	return clamp((1.0 - lightmap) * 16.0, 1.0, 16.0);
}

vec3 CalculateTorchLightmap(float dist, bool islightmap) {
	const float torchLuminance = TORCH_LUMINANCE; // Correct Lum
    vec3 torchColor = blackbody(TORCH_TEMPERATURE);

    float squareDistance = dist * dist;
  	float atten = (torchLuminance / squareDistance) * (islightmap ? smoothstep(256, 16.0, squareDistance) : 1.0);

	return torchColor * (atten * PI);
}

vec3 CalculateHandlight(float dist, vec3 albedo, vec3 viewVector, vec3 lightVector, vec3 normal, float alpha) {
	bool mask = heldItemId == 89 || heldItemId == 50 || heldItemId == 169 || heldItemId == 198;
	if (!mask) return vec3(0.0);
	dist = max(1.0, dist);

	return CalculateTorchLightmap(dist, false) * ggxDiffuse(albedo, viewVector, lightVector, normal, alpha);
}

float CalculateUndergroundShadowMask(float surfaceSkylight, float eyeSkylight) {
    float surfaceMask = clamp01(surfaceSkylight * 10.0 - 1.0);
    float eyeMask = clamp01(eyeSkylight * 4.0);
    eyeMask = pow4(eyeMask);

    return surfaceMask * (1.0 - eyeMask) + eyeMask;
}

vec3 CalculateLighting(mat2x3 position, vec3 albedo, vec3 viewVector, vec3 normal, vec3 worldNormal, vec2 lightmaps, float normFactor, float roughness, float f0, float dither, inout vec3 shadows, float materialFlag) {
    float alpha = roughness * roughness;

	vec3 shadowPosition = WorldSpaceToShadowSpace(position[1]);
    float cloudShadow = CloudShadow(position[1] + cameraPosition);

    vec3 handPosition = position[1] - vec3(0.0, 1.5, 0.0);
    vec3 handVector = normalize(-handPosition);

    bool isVeg = materialFlag < 2.0 && materialFlag > 0.0;

    #ifdef UNDERGROUND_LIGHT_LEAK_FIX
        float undergroundLeakFix = CalculateUndergroundShadowMask(lightmaps.y, eyeBrightnessSmooth.y / 240.0);
    #else
        #define undergroundLeakFix 1.0
    #endif

    shadows *= CalculateShadows(shadowPosition, normal, dither, isVeg) * cloudShadow;
	shadowPosition.xy = DistortShadowSpaceProj(shadowPosition.xy);

	float hCone = 0.0;

    vec3 diffuse  = ggxDiffuse(albedo, viewVector, lightVector, normal, alpha);
         diffuse  = mix(diffuse, albedo * rPI, float(isVeg));

    // Direct lighting.
         diffuse *= sunColor * (0.5 * transitionFading); //Multiply By Sunlight Color/Luminance //TODO: Find out why this is half.
         diffuse *= shadows * undergroundLeakFix; //Multiply By Shadows
	#ifdef CAUSTICS
         diffuse *= waterCaustics(position[1], shadowPosition, abs(texture2D(shadowtex1, shadowPosition.xy).x - texture2D(shadowtex0, shadowPosition.xy).x) * 1024.0, dither);
	#endif
    
    // Sky lighting.
	#if defined deffered0
         diffuse += CalculateSkyConeDiffuse(position[0], normal, normFactor, viewVector, alpha, dither, hCone) * albedo * (lightmaps.y * lightmaps.y); //Add Sky Lighting
	#endif

    // Block lighting.
         diffuse += CalculateTorchLightmap(GetTorchLightmapDistance(lightmaps.x), true) * albedo * hCone;

    // Hand lighting.
         diffuse += CalculateHandlight(length(handPosition), albedo, handVector, handVector, worldNormal, alpha) * hCone;

    // GI.
	#ifdef GLOBAL_ILLUMINATION
         diffuse += CalculateGlobalIllumination(position, normal, dither) * albedo * (cloudShadow * cloudShadow * (1.0 - isEyeInWater) * undergroundLeakFix);
	#endif

	vec3 specular = CalclulateBRDF(viewVector, lightVector, normal, albedo, pow2(alpha), f0) * sunColor * shadows * undergroundLeakFix;

    return BlendMaterial(diffuse, max0(specular), albedo, f0);
}

#endif
