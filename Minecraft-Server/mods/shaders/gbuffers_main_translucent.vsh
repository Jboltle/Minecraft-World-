/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#extension GL_EXT_gpu_shader4 : enable

#include "/InternalLib/Syntax.glsl"

attribute vec3 mc_Entity;
attribute vec4 at_tangent;

varying vec4 color;
varying vec3 worldSpacePosition;
varying vec2 texcoord;
varying vec2 lmcoord;

flat varying mat3 tbn;
flat varying vec3 lightVector;
flat varying vec3 tbnNormal;
flat varying float material;

varying vec3 tangentSpaceViewVector;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 shadowLightPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform int frameCounter;

#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Uniform/TemporalJitter.glsl"

void main() {
    vec3 viewSpacePosition = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
	vec3 tangent = (at_tangent.xyz / at_tangent.w);

	#if defined gbuffers_water
		if (mc_Entity.x < 8.0) {
			vec3 vertexOffset = gl_Normal * (inversesqrt(dot(gl_Normal, gl_Normal)) * 0.003);
			viewSpacePosition += vertexOffset; // Push vertex out. This is for CTM overlays.
		}
	#endif

    color = gl_Color;
    material = mc_Entity.x;

    texcoord = gl_MultiTexCoord0.st;
    lmcoord = gl_MultiTexCoord1.xy * 0.00392157; // 1.0 / 255.0 = ~0.00392157

	lightVector = normalize(mat3(gbufferModelViewInverse) * (shadowLightPosition * 0.01));

	tbnNormal = (gl_NormalMatrix * gl_Normal) * mat3(gbufferModelView);
	tangent = (gl_NormalMatrix * tangent) * mat3(gbufferModelView);
	vec3 worldSpaceViewVector = mat3(gbufferModelViewInverse) * viewSpacePosition;
	worldSpacePosition = worldSpaceViewVector + gbufferModelViewInverse[3].xyz;

	tbn = mat3(tangent, cross(tangent, tbnNormal), tbnNormal);
	tangentSpaceViewVector = worldSpaceViewVector * tbn;

	gl_Position    = viewSpacePosition.xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
	#if !defined gbuffers_hand_water && defined TAA
	gl_Position.xy = temporalJitter() * gl_Position.w + gl_Position.xy;
	#endif
}
