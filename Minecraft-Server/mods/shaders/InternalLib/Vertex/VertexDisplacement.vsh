/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, March 2018
 */

vec3 CalculateVertexDisplacement(vec3 worldPosition) {
    worldPosition += cameraPosition;

    vec3 displacement = worldPosition;

    switch(int(mc_Entity.x)) {
        case 31:
        case 37:
        case 38:
        case 59:
        case 141:
        case 142:
        case 207: displacement += CalculateWavingGrass(worldPosition, false); break;
        case 175:
        case 176: displacement += CalculateWavingGrass(worldPosition,  true); break;
        case 106:
        case 18:
        case 161: displacement += CalculateWavingLeaves(worldPosition, TIME); break;
    }

    return displacement - cameraPosition;
}
