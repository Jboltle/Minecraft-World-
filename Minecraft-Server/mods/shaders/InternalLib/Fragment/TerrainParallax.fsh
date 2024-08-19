/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

// wrap coord so it stays within the current atlas tile
#define wrapCoord(p) (round( (midCoord - p ) / tileSize ) * tileSize + p)
#define getDepth(p) (texture2DGrad(normals, wrapCoord(p), texD[0], texD[1]).a * parallaxDepth - parallaxDepth)

vec2 pom(const vec2 coord, const mat2 texD, inout float pomShadow) {
    float texHeight = texture2D(normals, coord).a;
    if(texHeight <= 0.0 || texHeight >= 1.0) return coord;

    vec3 step = tangentSpaceViewVector * inversesqrt(dot(tangentSpaceViewVector.xy,tangentSpaceViewVector.xy));
         step = length(step.xy * texD) * step;
            
    bool fix = step.z < -1e-5; // prevent infinite loops at extreme grazing angles (needs to be inside the loop to make retarded nvidia drivers happy)
    vec3 p = vec3(coord, 0.0);
    
    while(getDepth(p.xy) <= p.z && fix) p += step;

    vec3 stepL = (shadowLightPosition * mat3(gbufferModelView)) * tbn;
         stepL = stepL * inversesqrt(dot(stepL.xy, stepL.xy));
         stepL = length(stepL.xy * texD) * stepL;
            
    vec3 lightP = vec3(p.xy, getDepth(p.xy));
    bool lightFix = stepL.z > 1e-6;
    while(getDepth(lightP.xy) <= lightP.z && lightFix && lightP.z < 0.0) lightP += stepL;

    pomShadow = lightP.z < -1e-6 ? 0.0 : 1.0;
    
    return p.xy;
}
