/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */


#version 120
#define vert
#define gbuffers_weather

varying vec4 color;
varying vec2 texcoord;

#include "/InternalLib/Utilities.glsl"

void main() {
	color = gl_Color;
	texcoord = gl_MultiTexCoord0.st;
	
	vec3 viewSpacePosition = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
	
	gl_Position = viewSpacePosition.xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
}
