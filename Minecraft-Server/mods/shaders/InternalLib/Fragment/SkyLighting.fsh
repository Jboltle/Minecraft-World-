/* Copyright (C) Continuum Graphics - All Rights Reserved
* Unauthorized copying of this file, via any medium is strictly prohibited
* Proprietary and confidential
* Written by Joseph Conover <support@continuum.graphics>, Febuary 2018
*/

const float ambientBayerSize = 64.0;

vec3 CalculateHorizonVector(const vec2 offset, const float r, const vec3 normal, const float PdotN, const vec3 position) {
    vec2 screenPosition = offset * r + texcoord;
    vec3 occluder = CalculateViewSpacePosition(screenPosition);

    // get intersection with tangent plane
    float OdotN = dot(occluder, normal);
    float tangent = PdotN / OdotN;
          tangent = OdotN >= 0.0 ? 16.0 : tangent;

    // prevent occlusion behind the tangent plane
    float correction = min(1.0, tangent);
          correction = mix(tangent, correction, clamp01(r / (occluder.z - position.z)));
          correction = clamp01(screenPosition) != screenPosition ? tangent : correction;

    return normalize(occluder * correction - position);
}


vec4 CalculateHorizonAngle(const vec2 offset, const vec3 normal, const float PdotN, const vec3 position) {
    // get horizon vectors on both sides
    vec3 d0 = CalculateHorizonVector( offset, 8.0, normal, PdotN, position);
    vec3 d1 = CalculateHorizonVector(-offset, 8.0, normal, PdotN, position);
    // get horizon vectors closer to texcoord to catch occlusion by smaller objects
    vec3 d2 = CalculateHorizonVector( offset, 1.0, normal, PdotN, position);
    vec3 d3 = CalculateHorizonVector(-offset, 1.0, normal, PdotN, position);

    // get horizon angles
    float dot01 = dot(d0, d1);
    float dot03 = dot(d0, d3);
    float dot21 = dot(d2, d1);
    float dot23 = dot(d2, d3);

    // select smallest horizon angle
    float cosSkyAngle = max4(dot01, dot03, dot21, dot23);

    d1 = (dot03 == cosSkyAngle || dot23 == cosSkyAngle) ? d3 : d1;
    d0 = (dot21 == cosSkyAngle || dot23 == cosSkyAngle) ? d2 : d0;

    vec3 horizonDirection = d1 + d0;
         horizonDirection = dot(horizonDirection, normal) <= 0.0 ? normal : horizonDirection;

    cosSkyAngle = min(cosSkyAngle, 0.3);

    return vec4(normalize(horizonDirection.xyz), facos(cosSkyAngle));
}


// to be used with vanilla ao
vec4 CalculateHorizonAngleCheap(vec2 offset, vec3 normal, float PdotN, vec3 position) {
    vec3 d0 = CalculateHorizonVector( offset, 1.0, normal, PdotN, position);
    vec3 d1 = CalculateHorizonVector(-offset, 1.0, normal, PdotN, position);

    return vec4(
        normalize( normal * 1e-4 + d1 + d0 ),
        facos(dot(d0, d1)));
}


vec2 DistributeAmbiantSamples(const float i) {
    const float angle = ambientBayerSize*ambientBayerSize * float(AMBIENT_SAMPLES) * 0.5 * goldenAngle;
    vec2 p = sincos(i * angle);

    return p * (sqrt(i * 0.97 + 0.03) * fsign(p.x));
}

vec4 CalculateHorizonCone(const vec3 normal, float normFactor, const vec3 position, const float screenDither) {
    float PdotN = dot(position, normal);

    normFactor = min(normFactor, 0.4);

    vec2 screenSamplingRadius = vec2(viewHeight / viewWidth * normFactor, normFactor);
    const float rSteps = 1.0 / float(AMBIENT_SAMPLES);
    float dither = screenDither * rSteps;

    vec4 data = vec4(0);
    for (int i = 0; i < AMBIENT_SAMPLES; ++i) {
        float index = float(i) * rSteps + dither;
        vec2 point = DistributeAmbiantSamples(index) * screenSamplingRadius;
		
		#ifdef AO_CHEAP
			data += CalculateHorizonAngleCheap(point, normal, PdotN, position);
		#else
        	data += CalculateHorizonAngle(point, normal, PdotN, position);
		#endif
    }

    data.a *= rSteps;
    data.xyz = normalize(data.xyz);

    return vec4(data.xyz, data.a);
}

vec3 CalculateSkyConeDiffuse(const vec3 viewSpacePosition, const vec3 normal, const float normFactor, const vec3 viewVector, const float alpha, float dither, out float horizonRatio) {
    vec4 horizonCone = CalculateHorizonCone(
            normal,
            normFactor,
            viewSpacePosition,
            dither
         );

    float NoV = clamp01(dot(viewVector, normal));

    //solid angle
    horizonRatio = 1.0 - cos(horizonCone.a * 0.5);

    // sky illumination
	vec3 sky = FromSH(skySH[0], skySH[1], skySH[2], mat3(gbufferModelViewInverse) * horizonCone.xyz) * PI;

    float LoV = dot(horizonCone.xyz, viewVector);
    float NoH = dotNorm(viewVector + horizonCone.xyz, normal);
          NoH = max(NoH, 0.1);

    float NoL = clamp01(dot(horizonCone.xyz, normal));
          NoL = mix(NoL, 0.5, horizonRatio);

    float ggxDiffuse = ggxDiffuseModifier(alpha, NoL, NoV, NoH, LoV) * NoL;
    float totalLighting = horizonRatio * ggxDiffuse;

    return totalLighting * sky;
}
