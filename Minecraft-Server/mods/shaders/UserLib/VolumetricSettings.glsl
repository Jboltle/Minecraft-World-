/*******************************************************************************
 - Volumetric Settings
 ******************************************************************************/

 #define VC_MINIMUM 10
 #define VC_LOW 15
 #define VC_MEDIUM 20
 #define VC_HIGH 25
 #define VC_ULTRA 50
 #define VC_CINEMATIC 100

//#define VOLUMETRIC_CLOUDS
#define VOLUMETRIC_CLOUDS_QUALITY VC_MINIMUM // [VC_MINIMUM VC_LOW VC_MEDIUM VC_HIGH VC_ULTRA VC_CINEMATIC]

#define VOLUMETRIC_CLOUDS_DENSITY 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define VOLUMETRIC_CLOUDS_COVERAGE 2.0 // [1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0 4.25 4.5 4.75 5.0 5.25 5.5 5.75 6.0]

#define VOLUMETRIC_CLOUDS_SPEED 0.02 // [0.0 0.01 0.02 0.03 0.04 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]

#define VOLUMETRIC_CLOUDS_ALTITUDE 1600 // [100 160 260 300 350 400 450 500 550 600 650 700 750 800 1600]
#define VOLUMETRIC_CLOUDS_HEIGHT 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define VOLUMETRIC_CLOUDS_FALLOFF 0.00045 // [0.0003 0.0006 0.0009 0.0014 0.0016]
#define VOLUMETRIC_CLOUDS_ATTACK 0.015 // [0.1 0.2 0.4 0.6 0.8 1.1 1.2]

#define VCL_LOW 5
#define VCL_MEDIUM 10
#define VCL_HIGH 15

#define VOLUMETRIC_CLOUDS_DIRECT_QUALITY VCL_MEDIUM // [VCL_LOW VCL_MEDIUM VCL_HIGH]
#define VOLUMETRIC_CLOUDS_INDIRECT_QUALITY VCL_LOW // [VCL_LOW VCL_MEDIUM VCL_HIGH]

#define VCS_MINIMUM 2
#define VCS_LOW 3
#define VCS_MEDIUM 3
#define VCS_HIGH 5
#define VCS_ULTRA 7
#define VCS_CINEMATIC 9

//#define VOLUMETRIC_CLOUDS_SHADOWS
#define VOLUMETRIC_CLOUDS_SHADOWS_STEPS VCS_MEDIUM // [VCS_MINIMUM VCS_LOW VCS_MEDIUM VCS_HIGH VCS_ULTRA VCS_CINEMATIC]

//#define HQ_CLOUD_FBM

//ifdef guard for opti
#ifdef VOLUMETRIC_CLOUDS_SHADOWS
	//Guard
#endif

/*******************************************************************************
 - Volumetric Settings
 ******************************************************************************/

#define VL_MINIMUM 2
#define VL_LOW 4
#define VL_MEDIUM 8
#define VL_HIGH 16
#define VL_ULTRA 32
#define VL_CINEMATIC 64

#define VOLUMETRIC_LIGHT
#define VL_QUALITY VL_LOW // [VL_MINIMUM VL_LOW VL_MEDIUM VL_HIGH VL_ULTRA VL_CINEMATIC]

//#define VL_CLOUD_SHADOW // Forced with VL quality of ultra and higher.
//#define VL_SELF_SHADOW // TODO: MAKE WORK. Forced with VL quality of ultra and higher.

#if VL_QUALITY > 31 || defined VL_CLOUD_SHADOW
	#define VL_CLOUD_SHADOW_ENABLE
	#define VL_SELF_SHADOW_ENABLE
#endif

//#define AERIAL_VL
//#define VL_COLOURED_SHADOW

#define MORNING_FOG_FALLOFF 0.005 // [0 0.001 0.002 0.003 0.004 0.005 0.006 0.007 0.008 0.009 0.01 0.011 0.012 0.013 0.014 0.015 0.016 0.017 0.018 0.019]
#define MORNING_FOG_DENSITY 60 // [0 15 30 45 60 75 90 105 120 135 150 165 180 195 210 225 240 255 270 285 300 315 330 345 360 375 390 405 420 435 450 465 480 495 510 525 540 555 570 585 600 615 630 645 660 675 690 705 720 735 750 765 780 795 810 825 840 855 870 885 900 915 930 945 960 975 990]

//ifdef guard for opti
#ifdef VL_CLOUD_SHADOW
	//Guard
#endif

#ifdef VL_SELF_SHADOW
	//Guard
#endif

#ifdef AERIAL_VL
  //Guard
#endif

/*******************************************************************************
 - Water Settings
 ******************************************************************************/

#define WATER_DENSITY 2.0

const vec3 waterScatterCoefficient = vec3(0.001 * WATER_DENSITY) / log(2.0);
const vec3 waterAbsorptionCoefficient = vec3(0.996078, 0.406863, 0.25098) * (0.25 * WATER_DENSITY) / log(2.0);
const vec3 waterTransmittanceCoefficient = waterScatterCoefficient + waterAbsorptionCoefficient;
