#version 120
#extension GL_EXT_gpu_shader4 : enable

#define vsh
#define shadow
#include "/InternalLib/Syntax.glsl"

attribute vec3 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

varying vec2 texcoord;
varying vec3 worldSpaceViewVector;
varying vec3 worldSpacePosition;

flat varying mat3 tbn;
flat varying vec3 normal;
flat varying vec4 color;

flat varying int blockID;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform float frameTimeCounter;
uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;

uniform vec3 cameraPosition;

#include "/InternalLib/Utilities.glsl"
#include "/InternalLib/Uniform/ShadowDistortion.glsl"

#include "/InternalLib/Vertex/WavingTerrain.vsh"
#include "/InternalLib/Vertex/VertexDisplacement.vsh"

vec4 ProjectViewSpace(vec3 viewSpacePosition) {
	return vec4(projMAD(gbufferProjection, viewSpacePosition), viewSpacePosition.z * gbufferProjection[2].w);
}

void main() {
    texcoord = gl_MultiTexCoord0.st;
    color = gl_Color;

    normal = (gl_NormalMatrix * gl_Normal) * mat3(shadowModelView);

    worldSpacePosition = transMAD(shadowModelViewInverse, transMAD(gl_ModelViewMatrix, gl_Vertex.xyz));
    worldSpacePosition = CalculateVertexDisplacement(worldSpacePosition);

    vec3 viewSpacePosition = transMAD(shadowModelView, worldSpacePosition);

    gl_Position = (viewSpacePosition).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
    gl_Position.xy = DistortShadowSpace(gl_Position.xy);
    gl_Position.z *= 0.25;

    blockID = int(mc_Entity.x);

    vec3 tangent = (at_tangent.xyz / at_tangent.w);

    vec3 tbnNormal = (gl_NormalMatrix * gl_Normal) * mat3(shadowModelView);
    tangent = (gl_NormalMatrix * tangent) * mat3(shadowModelView);

    tbn = mat3(tangent, cross(tangent, tbnNormal), tbnNormal);
}
