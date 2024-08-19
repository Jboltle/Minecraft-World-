/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#version 120

#define frag
#define gbuffers_weather

varying vec4 color;
varying vec2 texcoord;

uniform sampler2D texture;
uniform sampler2D colortex4;

/* DRAWBUFFERS:4 */

void main() {
	gl_FragData[0] = vec4(texture2D(colortex4, texcoord).rgb, (texture2D(texture, texcoord).a * color.a));
}
