/*******************************************************************************
 - Camera Setup
 ******************************************************************************/

#define CAMERA_AUTO 0
#define CAMERA_MANUAL 1

#define CAMERA_MODE CAMERA_AUTO // [CAMERA_AUTO CAMERA_MANUAL]
#define CAMERA_APERTURE 2.8 // [1.4 2 2.8 4 5.6 8.0 11.0 16.0 22.0]
#define CAMERA_ISO 50 // [50 75 100 200 400 800 1600 3200 6400]
#define CAMERA_EV 0.0 // [-4.0 -3.9 -3.8 -3.7 -3.6 -3.5 -3.4 -3.3 -3.2 -3.1 -3.0 -2.9 -2.8 -2.7 -2.6 -2.5 -2.4 -2.3 -2.2 -2.1 -2.0 -1.9 -1.8 -1.7 -1.6 -1.5 -1.4 -1.3 -1.2 -1.1 -1.0 -0.9 -0.8 -0.7 -0.6 -0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define CAMERA_SHUTTER_SPEED 1600 // [1 2 4 8 10 20 25 50 75 100 125 200 300 400 500 600 700 800 900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000]
#define CAMERA_FOCAL_LENGTH 40 // [10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 65 70 75 80 85 90 95 100 110 120 130 140 150 160 170 180 190 200 220 240 260 280 300 320 340 360 380 400 420 440 460 480 500]

/*******************************************************************************
 - Depth Of Field Settings
 ******************************************************************************/

#define DOF_MINIMUM 16
#define DOF_LOW 32
#define DOF_MEDIUM 64
#define DOF_HIGH 128
#define DOF_ULTRA 256
#define DOF_CINEMATIC 1024

//#define DOF
#define DOF_SAMPLES DOF_LOW // [DOF_MINIMUM DOF_LOW DOF_MEDIUM DOF_HIGH DOF_ULTRA DOF_CINEMATIC]
#define CAMERA_FOCUS_MODE 0 // [0 1]
#define CAMERA_FOCAL_POINT 72 // [0.5 1 2 4 8 16 24 32 40 48 56 64 72 80 88 96 104 112 120 128 136 144 152 160 168 176 184 192 200 208 216 224 232 240 248 256]

#define DISTORTION_ANAMORPHIC 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define DISTORTION_BARREL 0.6

#define CAMERA_BLADES 5 // [3 4 5 6 7 8]
#define BLADE_ROTATION 1.0 // [0.0 0.2 0.4 0.6 0.8 1.0]
#define BLADE_ROUNDING 0.4 // [0.0 0.2 0.4 0.6 0.8 1.0]
#define CAMERA_BIAS 0.4 // [0.0 0.2 0.4 0.6 0.8 1.0]
#define LENS_SHIFT_AMOUNT 0.2 // [0.1 0.2 0.3 0.4 0.5]

const vec2 bokehOffset = vec2(0.375, 0.35); // Positions the bokeh in the center of the screen to avoid it being cut off.

/*******************************************************************************
 - Post Process Settings
 ******************************************************************************/

#define TAA
#define TAA_AGGRESSION 0.50 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.8]
#define TAA_SHARPEN
#define TAA_SHARPNESS 0.5 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 3.5 4.0]
#define LUT

#define LENS_FLARE
#define LENS_FLARE_STRENGTH 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define BLOOM_LOW 3
#define BLOOM_MEDIUM 4
#define BLOOM_HIGH 5
#define BLOOM_ULTRA 6

#define BLOOM
#define BLOOM_SAMPLES BLOOM_MEDIUM // [BLOOM_LOW BLOOM_MEDIUM BLOOM_HIGH BLOOM_ULTRA]
#define BLOOM_EV 0.0 // [-4.0 -3.9 -3.8 -3.7 -3.6 -3.5 -3.4 -3.3 -3.2 -3.1 -3.0 -2.9 -2.8 -2.7 -2.6 -2.5 -2.4 -2.3 -2.2 -2.1 -2.0 -1.9 -1.8 -1.7 -1.6 -1.5 -1.4 -1.3 -1.2 -1.1 -1.0 -0.9 -0.8 -0.7 -0.6 -0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define BLOOM_CURVE 2.0 // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]
