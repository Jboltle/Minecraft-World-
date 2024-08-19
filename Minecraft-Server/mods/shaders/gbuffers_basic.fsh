/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, march 2018
 */

#version 120
#include "/InternalLib/Syntax.glsl"

varying vec4 color;
varying vec2 lmcoord;

flat varying vec3 flatNormal;

#include "/InternalLib/Utilities.glsl"

/* DRAWBUFFERS:01 */

void main() {
    gl_FragData[0] = vec4(color);
    gl_FragData[1] = vec4(EncodeNormal(flatNormal), EncodeVec2(lmcoord.x, lmcoord.y), EncodeVec2(1.0, 1.0), 1.0);
}
