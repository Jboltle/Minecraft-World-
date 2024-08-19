/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_shader_texture_lod : enable

#define ShaderStage 9

#include "/InternalLib/Syntax.glsl"

varying vec4 color;
varying vec3 worldSpacePosition;
varying vec2 texcoord;
varying vec2 lmcoord;

flat varying mat3 tbn;
flat varying vec3 lightVector;
flat varying vec3 tbnNormal;
flat varying float material;

varying vec3 tangentSpaceViewVector;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float rainStrength;

uniform int frameCounter;

#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Debug.glsl"

#if defined gbuffers_water
	#include "/InternalLib/Fragment/WaterWaves.fsh"
    #include "/InternalLib/Fragment/WaterParallax.fsh"
#endif

/* DRAWBUFFERS:10 */

void main() {
    bool isWater = material == 8.0 || material == 9.0;

	mat2 texD = mat2(dFdx(texcoord), dFdy(texcoord));

	vec3 tangentVector = -normalize(tangentSpaceViewVector);

	vec3 viewVector = -normalize(worldSpacePosition);
	float dither = bayer64(gl_FragCoord.xy);
    #ifdef TAA
	      dither = fract(frameCounter * 0.109375 + dither);
    #endif

    vec4 data0 = texture2DGradARB(texture,  texcoord, texD[0], texD[1]);
	vec4 data1 = texture2DGradARB(normals,  texcoord, texD[0], texD[1]);
	vec4 data2 = texture2DGradARB(specular, texcoord, texD[0], texD[1]);

    vec4 albedo = data0 * color;

	#ifdef WHITE_WORLD
		albedo = vec4(1.0);
	#endif

    float roughness = 1.0 - data2.z;
    float f0 = data2.x;

	vec3 normal = clampNormal(data1.xyz * 2.0 - 1.0, tangentVector);
		 normal = data1.xyz == vec3(0, 0, 0) ? vec3(0, 0, 1) : normal;

    #if defined gbuffers_water
        if(isWater) {
            albedo = vec4(0.0, 0.0, 0.0, 0.0);
            roughness = 0.03;
            f0 = 0.021;
			normal = GetWavesNormal(GetWaterParallaxCoord(worldSpacePosition + cameraPosition, -tangentVector));
        }
    #endif

	normal = tbn * normal;

	//gl_FragData[1] = vec4(0.0); //Flush buffer to assure overwite not blend.
	gl_FragData[1] = vec4(albedo.rgb, albedo.a);

    gl_FragData[0] = vec4(EncodeNormal(normal), EncodeVec2(lmcoord.x, lmcoord.y), EncodeVec2(roughness, f0), 1.0);

	exit();
}
