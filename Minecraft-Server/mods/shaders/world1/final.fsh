/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#version 120

varying vec2 texcoord;

uniform sampler2D colortex0;

void main() {
	vec3 color = texture2D(colortex0, texcoord).rgb;

	gl_FragColor = vec4(color, 1.0);
}
