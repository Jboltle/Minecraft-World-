#version 120
#extension GL_EXT_gpu_shader4 : enable

#define fsh
#define shadow
#include "/InternalLib/Syntax.glsl"

varying vec2 texcoord;
varying vec3 worldSpaceViewVector;
varying vec3 worldSpacePosition;

flat varying mat3 tbn;
flat varying vec3 normal;
flat varying vec4 color;

flat varying int blockID;

uniform sampler2D texture;

uniform sampler2D noisetex;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float rainStrength;

#include "/InternalLib/Utilities.glsl"

#include "/InternalLib/Fragment/WaterWaves.fsh"

void main() {
    if(!gl_FrontFacing && (blockID == 18 || blockID == 31 || blockID == 175 || blockID == 176)) discard;

    vec4 albedo = texture2D(texture, texcoord) * color;

	#ifdef WHITE_WORLD
		albedo = vec4(vec3(1.0), albedo.a);
	#endif

    vec3 shadowNormal = normal;

	albedo = (blockID == 51) ? vec4(0.0) : albedo;

    bool isWater = blockID == 8 || blockID == 9;
    if(isWater) {
        albedo = vec4(1.0);

        #ifdef CAUSTICS
            shadowNormal = (tbn * GetWavesNormal(worldSpacePosition + cameraPosition));
        #endif
    }

    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(shadowNormal * 0.5 + 0.5, clamp01(float(isWater) + 0.4));
}
