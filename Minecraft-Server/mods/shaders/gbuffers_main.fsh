/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_shader_texture_lod : enable

#define ShaderStage -1

#include "/InternalLib/Syntax.glsl"

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;

flat varying mat3 tbn;
flat varying vec2 entity;
flat varying float material;
flat varying float materialFlag;

flat varying vec2 midCoord;
flat varying vec2 tileSize;
flat varying float parallaxDepth;
flat varying vec2 wrap;

varying vec3 tangentSpaceViewVector;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

#if defined gbuffers_entities
    uniform vec4 entityColor;
#endif

uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelView;

#if defined gbuffers_block
    uniform int blockEntityId;
#endif

uniform float frameTimeCounter;

#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Fragment/TerrainParallax.fsh"
#include "/InternalLib/Debug.glsl"

#define getHemisphereVisibility(x) clamp( x * .5 + .5 , 0., 1. )

float getTorchLight(const vec3 normal, const mat2x3 positionD) {
	#if defined gbuffers_hand
		return lmcoord.x;
	#endif

	if(lmcoord.x >= 0.98) return lmcoord.x;
	// torch light hemisphere direction
	vec3 torchL = normalize(positionD * vec2(dFdx(lmcoord.x), dFdy(lmcoord.x)));

	// nanfix
	torchL = torchL!=torchL ? vec3(1,0,0) : torchL;

	// torch light intensity
	float torchLightLevel = getHemisphereVisibility(dot(normal, torchL));

	// torch light brdf
	torchL = normalize(torchL + normal);

	return lmcoord.x * clamp01(dot(torchL, normal));
}

#if MATERIAL_FORMAT == OLD
	float CalculateOldFormatF0(float metalness) {
		float metalF0 = 1.0; // Default (Chrome)

		switch(int(entity.x)) {
			case 147:
			case 41: metalF0 = 0.97; break; // Gold
			case 142:
			case 48: metalF0 = 0.46; break; // Iron
			default: break;
		}

		return mix(0.02, metalF0, metalness);
	}
#endif

/* DRAWBUFFERS:01 */

void main() {
	mat2 texD = mat2(dFdx(texcoord), dFdy(texcoord));
	vec3 tangentVector = -normalize(tangentSpaceViewVector);
	float shadow = 1.0;

  	float dither = bayer16(gl_FragCoord.xy) * 0.00392157;

	#if (defined gbuffers_terrain) && defined TERRAIN_PARALLAX
		vec2 pomcoord  = (material == 10.0 || material == 11.0) ? texcoord : pom(texcoord, texD, shadow);
		vec2 wrapcoord = (material == 10.0 || material == 11.0) ? texcoord : wrapCoord(pomcoord);
	#else
		vec2 pomcoord  = texcoord;
		vec2 wrapcoord = texcoord;
	#endif

    vec4 data0 = texture2DGrad(texture, wrapcoord, texD[0], texD[1]);
	if(data0.a < 0.1000003) discard; // Discard invisible fragments.

	vec4 data1 = texture2DGrad(normals,  wrapcoord, texD[0], texD[1]);
	vec4 data2 = texture2DGrad(specular, wrapcoord, texD[0], texD[1]);

	#ifdef WHITE_WORLD
		vec4 albedo = vec4(vec3(1.0), data0.a);
	#else
		vec4 albedo = data0 * color;
	#endif

	#ifdef TERRAIN_PARALLAX
	//This a line.
	#endif

	#if (defined gbuffers_terrain) && defined TERRAIN_PARALLAX
		if( abs(midCoord.x - pomcoord.x) > tileSize.x * 0.5 && wrap.x < 0.5) albedo.a = 0.0;
		if( abs(midCoord.y - pomcoord.y) > tileSize.y * 0.5 && wrap.y < 0.5) albedo.a = 0.0;
	#endif

	#if defined gbuffers_entities
		if (dot(entityColor.rgb, entityColor.rgb) > 0.0) albedo.rgb *= entityColor.rgb;
	#endif

	vec3 normal = data1.xyz * 2.0 - 1.0;
	float ao = data1.z;

	#if SPECULAR_MODE == SPECULAR_OLD
		float roughness = 1.0 - data2.x;
		float porosity = 0.0; // TODO: Hardcode when we start using porosity.

		float f0 = CalculateOldFormatF0(data2.y);
		float sss = data2.z;
	#elif SPECULAR_MODE == SPECULAR_LAB
        float roughness = 1.0 - data2.x;
		float porosity = 1.0 - data2.z; // TODO: Hardcode when we start using porosity.

		float f0 = data2.y;
		float sss = 1.0 - data2.a;

		normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));
    #else
		float roughness = 1.0 - data2.z;
		float porosity = data2.y;

		float f0 = data2.x;
		float sss = data2.w;

		if(lmcoord.x >= 0.96) lmcoord.x * pow2(sss); //Fake emmissive
	#endif

	#if defined gbuffers_terrain
		normal = clampNormal(normal, tangentVector);
	#endif

	normal = data1.xyz == vec3(0, 0, 0) ? vec3(0, 0, 1) : normal;
	normal = tbn * normal;
	
	float matFlag = materialFlag;
	
	#if defined gbuffers_hand || defined gbuffers_entities || defined gbuffers_textured
		shadow = 1.0;
		matFlag = 0.0;
	#endif

    gl_FragData[0] = vec4(albedo.rgb, albedo.a); //RGBA8
	
	#if !defined gbuffers_armor_glint
		gl_FragData[1] = vec4(EncodeNormal(normal), EncodeVec2(lmcoord.x + dither, lmcoord.y * sqrt(ao) + dither), EncodeVec2(roughness, f0), EncodeVec2(clamp01(shadow + 0.5), 1.0 - matFlag)); //RGBA16
	#else //Glint
		gl_FragData[1] = vec4(EncodeNormal(vec3(0.0)), EncodeVec2(0.0, 0.0), EncodeVec2(1.0, 0.0), EncodeVec2(1.0, 1.0)); //RGBA16
	#endif

	exit();
}
