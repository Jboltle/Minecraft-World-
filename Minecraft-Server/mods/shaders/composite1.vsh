/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, March 2018
 */

#version 120
#define vert

#include "/InternalLib/Syntax.glsl"

varying vec2 texcoord;

void main() {
	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);

    texcoord = gl_Vertex.xy;

}
