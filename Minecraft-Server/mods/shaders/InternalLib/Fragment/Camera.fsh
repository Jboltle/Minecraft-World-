/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, Febuary 2018
 */

float ComputeEV100(const float aperture2, const float shutterTime, const float ISO) {
    return log2(aperture2 / shutterTime * 100.0 / ISO);
}

float ComputeEV100Auto(float avgLuminance) {
    return log2(avgLuminance * 8.0);
}

float ConvertEV100ToExposure(float EV100) {
    return 0.833333 * exp2(-EV100);
}

float ComputeEV(float avgLuminance) {
    const float aperture  = CAMERA_APERTURE;
    const float aperture2 = aperture * aperture;
    const float shutterTime = 1.0 / CAMERA_SHUTTER_SPEED;
    const float ISO = CAMERA_ISO;
    const float EC = CAMERA_EV;

    #if CAMERA_MODE == CAMERA_MANUAL
        float EV100 = ComputeEV100(aperture2, shutterTime, ISO);
    #else
        float EV100 = ComputeEV100Auto(clamp(avgLuminance, 1.0, 4096.0)); //Dolby Standard Clamp
    #endif

    return ConvertEV100ToExposure(EV100 - EC) * PI;
}
