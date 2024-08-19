/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, April 2018
 */

#include "/InternalLib/Misc/NoiseTexture.glsl"

#define gMultiplierCloudsPlanar 0.65
#define mixergCloudsPlanar 0.7

float PhaseG8Planar(float x) {
    const float g = 0.8 * gMultiplierCloudsPlanar;
    const float g2 = g * g;
    const float g3 = log2((g2 * -0.25 + 0.25) * mixergCloudsPlanar);
    const float g4 = 1.0 + g2;
    const float g5 = -2.0 * g;

    return exp2(log2(g5 * x + g4) * -1.5 + g3);
}

float PhaseGM5Planar(float x) {
	const float g = -0.5 * gMultiplierCloudsPlanar;
	const float g2 = g * g;
	const float g3 = log2((g2 * -0.25 + 0.25) * (1.0 - mixergCloudsPlanar));
	const float g4 = 1.0 + g2;
    const float g5 = -2.0 * g;

    return exp2(log2(g5 * x + g4) * -1.5 + g3);
}

float Phase2LobesPlanar(float x) {
    return PhaseG8Planar(x) + PhaseGM5Planar(x);
}

float PlanarCloudFBM(vec2 cloudCoord, float t) {
    #if !defined gbuffers_hand_water
        #if 0
            cloudCoord.x -= t;

            float offsetOct1 = texture2D(noisetex, cloudCoord * 0.5).x;
            float offsetOct2 = texture2D(noisetex, cloudCoord * 5.0).x;
            float offsetOct3 = texture2D(noisetex, vec2(cloudCoord.x, cloudCoord.y * 0.25) * 4.0).x;

            float oct1 = texture2D(noisetex, cloudCoord + offsetOct1 * 0.05 + t * 0.5).x;
            float oct2 = texture2D(noisetex, vec2(cloudCoord.x + cloudCoord.y, cloudCoord.y) * 5.0 - offsetOct1 * 0.01 - t * 0.3).x * pow4(oct1);
            float oct3 = texture2D(noisetex, vec2(cloudCoord.x * 4.0 - (offsetOct2 * offsetOct1) * 0.01 - t, cloudCoord.y) * 6.0 - offsetOct3 * 0.1).x * pow2(oct1);
            float oct4 = texture2D(noisetex, vec2(cloudCoord.x * 4.0 - (offsetOct2 * offsetOct1) * 0.04, cloudCoord.y * 7.0 - (offsetOct2 * offsetOct1) * 0.04 - t * 0.25) * 10.0 - offsetOct3 * 0.2).x * pow2(oct1);

            float cloudNoise  = 0.0;
                cloudNoise += oct2 * 0.1;
                cloudNoise -= oct3 * 0.02;
                cloudNoise += oct4 * 0.01;
                cloudNoise  = clamp01(cloudNoise);

            return cloudNoise * (CLOUDS_2D_DENSITY * 3.0) * (wetness * 2.0 + 1.0);
        #else
            const vec3 weights = vec3(0.5, 0.135, 0.075);
            const float weight = weights.x + weights.y + weights.z;

            const float curve = 0.003;
            const float curveHalf = curve * 0.5;

            const float coverage = CLOUDS_2D_COVERAGE * 0.7;
            const float density = CLOUDS_2D_DENSITY * 0.225;

            mat4x2 c;

            c[0]  = cloudCoord;
            c[0] += Get2DNoiseSmooth(c[0]).xy * curve - curveHalf;
            c[0].x = c[0].x * 0.25 + t;

            float cloud = -Get2DNoiseSmooth(c[0]).x;

            c[1] = c[0] * 2.0 - cloud * 0.03 * vec2(0.5, 1.35);
            c[1].x += t;

            cloud += Get2DNoiseSmooth(c[1]).x * weights.x;

            c[2] = c[1] * vec2(9.0, 1.65) + t * vec2(3.0, 0.55) - cloud * 0.05 * vec2(1.5, 0.75);

            cloud += Get2DNoiseSmooth(c[2]).x * weights.y;

            c[3] = c[2] * 3.0 + t;

            cloud += Get2DNoiseSmooth(c[3]).x * weights.z;

            cloud = weight - cloud;

            cloud += Get2DNoiseSmooth(c[3] * 3.0 + t).x * 0.022;
            cloud += Get2DNoiseSmooth(c[3] * 9.0 + t * 3.0).x * 0.014;

            cloud *= 0.63;

            return cubesmooth(clamp01((coverage + cloud - 1.0) * 1.1 - 0.2)) * density;
        #endif
    #else
        return 0.0;
    #endif
}

float CalculatePlanarCloudVisibility(vec3 direction, vec2 cloudCoord, float t) {
    const int   steps  = 3;
    const float rSteps = 1.0 / steps;

    vec2 increment = direction.xz * rSteps * 0.007;

    float opticalDepth = 0.0;

    for(int i = 0; i < steps; ++i, cloudCoord += increment) {
        opticalDepth += PlanarCloudFBM(cloudCoord, t);
    }

    return exp2(-opticalDepth * rSteps);
}

vec3 CalculateCloudScattering(vec3 wLightVector, vec2 cloudCoord, vec3 pColorSun, vec3 pColorSky, float phase, float t) {

    vec3 sunScattering = (CalculatePlanarCloudVisibility(wLightVector, cloudCoord, t) * pColorSun) * phase * HPI;
    vec3 skyScattering = pColorSky * phaseg0;

    return (sunScattering + skyScattering) * PI;
}

vec3 CalculatePlanarClouds(vec3 background, vec3 worldPosition, float VdotL) {
    #ifndef CLOUDS_2D
      return background;
    #endif

    #if !defined gbuffers_hand_water
		const float cirrusCloudHeight = 6000.0;

        if((worldPosition.y < 0.0 && cameraPosition.y < cirrusCloudHeight) || (worldPosition.y > 0.0 && cameraPosition.y > cirrusCloudHeight)) return background;
		worldPosition.y = abs(worldPosition.y);

        float t = TIME * 0.0001;

        vec3 scatter = vec3(0.0);
        vec3 transmittance = vec3(1.0);

        float phaseCloud = Phase2LobesPlanar(VdotL);

		float cloudHeight = cirrusCloudHeight - cameraPosition.y;
		float height = cloudHeight / worldPosition.y;

		vec3 cloudPosition = worldPosition * height;

        vec3 pColorSun = sunColor;
        vec3 pColorSky = skyColor;

        vec3 wLightVector = mat3(gbufferModelViewInverse) * lightVector;
        vec2 cloudCoord = (cloudPosition.xz + cameraPosition.xz) * 0.000006;

        float opticalDepth = PlanarCloudFBM(cloudCoord, t);

        scatter += (CalculateCloudScattering(wLightVector, cloudCoord, pColorSun, pColorSky, phaseCloud, t) * transmittance) * opticalDepth;
        transmittance *= exp2(-opticalDepth);

        return mix(background * transmittance + scatter, background, exp2(-4.0 * cirrusCloudHeight * worldPosition.y / abs(cameraPosition.y - cirrusCloudHeight)));
    #else
        return background;
    #endif
}
