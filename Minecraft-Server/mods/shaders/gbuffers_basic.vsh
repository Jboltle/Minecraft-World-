/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, march 2018
 */

#version 120
#extension GL_EXT_gpu_shader4 : enable
#include "/InternalLib/Syntax.glsl"

varying vec4 color;
varying vec2 lmcoord;

flat varying vec3 flatNormal;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;

#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Uniform/TemporalJitter.glsl"

void main() {

    vec3 viewSpacePosition = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
    gl_Position = viewSpacePosition.xyzz * diagonal4(gbufferProjection) + gbufferProjection[3];
	
	gl_Position.xy += temporalJitter() * gl_Position.w;

    color = gl_Color;
    lmcoord = gl_MultiTexCoord1.xy * 0.00392157; // 1.0 / 255.0 = ~0.00392157
    flatNormal = (mat3(gl_ModelViewMatrix) * gl_Normal) * mat3(gbufferModelView);

}
