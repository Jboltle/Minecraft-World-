/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, March 2018
 */

#version 120
#extension GL_EXT_gpu_shader4 : enable

#define frag
#define composite1
#define ShaderStage 11

#include "/InternalLib/Syntax.glsl"

const bool colortex5MipmapEnabled = true;

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex5;

uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float centerDepthSmooth;
uniform float frameTime;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float near;
uniform float far;

uniform int frameCounter;

#include "/InternalLib/Uniform/Matrices.glsl"
#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Debug.glsl"

/*******************************************************************************
 - Space Conversions
 ******************************************************************************/

float ScreenToViewSpaceDepth(float depth) {
	depth = depth * 2.0 - 1.0;
	return -1.0 / (depth * projMatrixInverse[2][3] + projMatrixInverse[3][3]);
}

/*******************************************************************************
  - Functions
 ******************************************************************************/

float GetFocus(float depth) {
    const float focalLength = CAMERA_FOCAL_LENGTH / 1000.0;
    const float aperture    = (CAMERA_FOCAL_LENGTH / CAMERA_APERTURE) / 1000.0;

    #if CAMERA_FOCUS_MODE == 0
        float focus = ScreenToViewSpaceDepth(centerDepthSmooth);
    #else
        float focus = ScreenToViewSpaceDepth(getDepthExp(CAMERA_FOCAL_POINT));
    #endif

    return aperture * (focalLength * (focus - depth)) / (focus * (depth - focalLength));
}

vec2 GetDistOffset(const vec2 prep, const float angle, const vec2 offset, const vec2 anamorphic) {
    vec2 oldOffset = offset * anamorphic;
    return oldOffset * angle + prep * dot(prep, oldOffset) * (1.0 - angle);
}

vec3 DepthOfField() {
    #ifndef DOF
        return texture2DLod(colortex5, texcoord, 0).rgb;
    #endif

    if(texture2D(depthtex2, texcoord).x > texture2D(depthtex1, texcoord).x) return texture2DLod(colortex5, texcoord, 0).rgb;

    vec3 dof = vec3(0.0);
    vec3 weight = vec3(0.0);

    float r = 1.0;
    const mat2 rot = mat2(
        cos(goldenAngle), -sin(goldenAngle),
        sin(goldenAngle),  cos(goldenAngle)
    );

    // Lens specifications referenced from Sigma 32mm F1.4 art.
    // Focal length of 32mm (assuming lens does not zoom), with a diaphram size of 25mm at F1.4.
    // For more accuracy to lens settings, set blades to 9.
    const float focalLength = 35.0 / 1000.0;
    const float aperture    = (35.0 / CAMERA_APERTURE) / 1000.0;

    float depth = ScreenToViewSpaceDepth(texture2D(depthtex1, texcoord).x);
    float pcoc = GetFocus(depth);

    vec2 pcocAngle   = vec2(0.0, pcoc);
    vec2 sampleAngle = vec2(0.0, 1.0);

    const float sizeCorrect   = 1.0 / (sqrt(float(DOF_SAMPLES)) * 1.35914091423) * 0.5;
    const float apertureScale = sizeCorrect * aperture * 1000.0;

	const float inverseItter05 = 0.1 / DOF_SAMPLES;
	float lod = log2(abs(pcoc) * viewHeight * viewWidth * inverseItter05);

    vec2 distOffsetScale = apertureScale * vec2(1.0, aspectRatio);

	vec2 toCenter = texcoord.xy - 0.5;
    vec2 prep = normalize(vec2(toCenter.y, -toCenter.x));
	float lToCenter = length(toCenter);
	float angle = cos(lToCenter * 2.221 * DISTORTION_BARREL);

    for(int i = 0; i < DOF_SAMPLES; ++i) {
        r += 1.0 / r;

        sampleAngle = rot * sampleAngle;
		vec2 pcocAngle = sampleAngle * pcoc;

        vec2 pos = GetDistOffset(prep, 1.0, (r - 1.0) * sampleAngle, vec2(1.0)) * sizeCorrect + 0.5;
        vec3 bokeh = texture2D(colortex0, pos * 0.25 + bokehOffset).rgb;

        pos = GetDistOffset(prep, angle, (r - 1.0) * pcocAngle, vec2(DISTORTION_ANAMORPHIC, 1.0 / DISTORTION_ANAMORPHIC)) * distOffsetScale;

        dof += texture2DLod(colortex5, texcoord + pos, lod).rgb * bokeh;
        weight += bokeh;
    }

    return dof / weight;
}

vec3 GetBloomTile(const float lod, vec2 pixelSize, vec2 offset) {
    #ifndef BLOOM
        return vec3(0.0);
    #endif

	vec2 coord = (texcoord - offset) * exp2(lod);
	vec2 scale = pixelSize * exp2(lod);

    if (any(greaterThanEqual(abs(coord - 0.5), scale + 0.5)))
        return vec3(0.0);

	vec3 bloom = vec3(0.0);
	float totalWeight = 0.0;

	const int bloomSamples = BLOOM_SAMPLES - 1;
	const float invSamples = 1.0 / float(bloomSamples + 1.0);

	for (int y = -bloomSamples; y <= bloomSamples; ++y) { // 5
		for (int x = -bloomSamples; x <= bloomSamples; ++x) { // 5
			float sampleLength = 1.0 - length(vec2(x, y)) * invSamples; //div by sqrt of total samples
            float sampleWeight = clamp01(pow(sampleLength, BLOOM_CURVE));

            bloom += texture2DLod(colortex5, coord + vec2(x, y) * scale, lod).rgb * sampleWeight;

            totalWeight += sampleWeight;
        }
    }

    return bloom / totalWeight;
}

vec3 CalculateBloomTiles() {
    #ifndef BLOOM
        return vec3(0.0);
    #endif

    vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

    vec3 bloom  = vec3(0.0);
         bloom += GetBloomTile(2.0, pixelSize, vec2(0.0, 0.0));
         bloom += GetBloomTile(3.0, pixelSize, vec2(0.0, 0.25 + pixelSize.y * 2.0));
         bloom += GetBloomTile(4.0, pixelSize, vec2(0.125 + pixelSize.x * 2.0, 0.25 + pixelSize.y * 2.0));
         bloom += GetBloomTile(5.0, pixelSize, vec2(0.1875 + pixelSize.x * 4.0, 0.25 + pixelSize.y * 2.0));
         bloom += GetBloomTile(6.0, pixelSize, vec2(0.125 + pixelSize.x * 2.0, 0.3125 + pixelSize.y * 4.0));
         bloom += GetBloomTile(7.0, pixelSize, vec2(0.140625 + pixelSize.x * 4.0, 0.3125 + pixelSize.y * 4.0));

    return max0(bloom);
}

float ComputeAverageLum() {
	vec3 currentFrame = max0(texture2DLod(colortex5, vec2(0.5), 10).rgb);

	//float currentLum = dot(currentFrame, vec3(0.33333));
	//float currentLum = min3(currentFrame.r, currentFrame.g, currentFrame.b);
	float currentLum = dot(currentFrame, vec3(0.2125, 0.7154, 0.0721));
	float previousLum = texture2D(colortex5, vec2(0.5)).a;

	return mix(currentLum, previousLum, clamp((1.0 - frameTime), 0.0, 0.99)); //Prevents mixing time from being very long when having a lower framerate.
}


/* DRAWBUFFERS:235 */

void main() {
	vec3 bloomTiles = (CalculateBloomTiles());
	
	gl_FragData[0] = EncodeRGBE8(DepthOfField());
	gl_FragData[1] = EncodeRGBE8(bloomTiles);
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, ComputeAverageLum());

	exit();
}
