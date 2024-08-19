/*******************************************************************************
 - Material Settings
 ******************************************************************************/

#define SPECULAR_OLD 0
#define SPECULAR_NEW 1
#define SPECULAR_LAB 2

#define SPECULAR_MODE SPECULAR_LAB // [SPECULAR_LAB SPECULAR_OLD SPECULAR_NEW]

/*******************************************************************************
 - Shadow Settings
 ******************************************************************************/

#define SHADOW_MINIMUM 2
#define SHADOW_LOW 3
#define SHADOW_MEDIUM 9
#define SHADOW_HIGH 18
#define SHADOW_ULTRA 25
#define SHADOW_CINEMATIC 81

#define SHADOW_QUALITY SHADOW_MEDIUM // [SHADOW_MINIMUM SHADOW_LOW SHADOW_MEDIUM SHADOW_HIGH SHADOW_ULTRA SHADOW_CINEMATIC]
#define SHADOW_PENUMBRA_ANGLE 8.0 // [0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0]

#define SHADOW_HARD 0
#define SHADOW_SOFT 1
#define SHADOW_PCSS 2

#define SHADOW_TYPE SHADOW_SOFT // [SHADOW_HARD SHADOW_SOFT SHADOW_PCSS]

const int shadowMapResolution = 2048; // [256 512 1024 2048 4096 8192 16384]
const float rShadowMapResolution = 1.0 / float(shadowMapResolution);
const float shadowDistance    = 120.0;

//#define CAUSTICS
#define REFRACTION

/*******************************************************************************
 - AO Settings
 ******************************************************************************/

#define AMBIENT_MINIMUM 2
#define AMBIENT_LOW 3
#define AMBIENT_MEDIUM 4
#define AMBIENT_HIGH 8
#define AMBIENT_ULTRA 12
#define AMBIENT_CINEMATIC 16

#define AMBIENT_SAMPLES AMBIENT_LOW // [AMBIENT_MINIMUM AMBIENT_LOW AMBIENT_MEDIUM AMBIENT_HIGH AMBIENT_ULTRA AMBIENT_CINEMATIC]
//#define AO_CHEAP


/*******************************************************************************
 - Specular Settings
 ******************************************************************************/

#define SPECULAR_MINIMUM 1
#define SPECULAR_LOW 2
#define SPECULAR_MEDIUM 3
#define SPECULAR_HIGH 8
#define SPECULAR_ULTRA 16
#define SPECULAR_CINEMATIC 32

#define SPECULAR_QUALITY SPECULAR_MEDIUM // [SPECULAR_MINIMUM SPECULAR_LOW SPECULAR_MEDIUM SPECULAR_HIGH SPECULAR_ULTRA SPECULAR_CINEMATIC]

#define RAYTRACE_MINIMUM 4
#define RAYTRACE_LOW 8
#define RAYTRACE_MEDIUM 12
#define RAYTRACE_HIGH 12
#define RAYTRACE_ULTRA 32
#define RAYTRACE_CINEMATIC 64

#define RAYTRACE_QUALITY RAYTRACE_MEDIUM // [RAYTRACE_MINIMUM RAYTRACE_LOW RAYTRACE_MEDIUM RAYTRACE_HIGH RAYTRACE_ULTRA RAYTRACE_CINEMATIC]

#define REFINES_MINIMUM 1
#define REFINES_LOW 2
#define REFINES_MEDIUM 6
#define REFINES_HIGH 8
#define REFINES_ULTRA 12
#define REFINES_CINEMATIC 16

#define RAYTRACE_REFINES REFINES_MEDIUM // [REFINES_MINIMUM REFINES_LOW REFINES_MEDIUM REFINES_HIGH REFINES_ULTRA REFINES_CINEMATIC]

#define SPECULAR_CLAMP
#define SPECULAR_TAIL_CLAMP 0.3 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7]

#define REFLECT_2D_CLOUDS
//#define REFLECT_3D_CLOUDS

//#define RAIN_PUDDLES

#define REFLECTED_CLOUDS_MINIMUM 2
#define REFLECTED_CLOUDS_LOW 3
#define REFLECTED_CLOUDS_MEDIUM 4
#define REFLECTED_CLOUDS_HIGH 8
#define REFLECTED_CLOUDS_ULTRA 12
#define REFLECTED_CLOUDS_CINEMATIC 16

#define REFLECTED_CLOUDS_QUALITY REFLECTED_CLOUDS_MEDIUM // [REFLECTED_CLOUDS_MINIMUM REFLECTED_CLOUDS_LOW REFLECTED_CLOUDS_MEDIUM REFLECTED_CLOUDS_HIGH REFLECTED_CLOUDS_ULTRA REFLECTED_CLOUDS_CINEMATIC]
#define REFLECTED_CLOUDS_QUALITY_DIRECT REFLECTED_CLOUDS_MEDIUM // [REFLECTED_CLOUDS_MINIMUM REFLECTED_CLOUDS_LOW REFLECTED_CLOUDS_MEDIUM REFLECTED_CLOUDS_HIGH REFLECTED_CLOUDS_ULTRA REFLECTED_CLOUDS_CINEMATIC]

/*******************************************************************************
 - Global Illumination Settings
 ******************************************************************************/
#define GI_MINIMUM 2.0
#define GI_LOW 3.0
#define GI_MEDIUM 4.0
#define GI_HIGH 8.0
#define GI_ULTRA 32.0
#define GI_CINEMATIC 64.0

//#define GLOBAL_ILLUMINATION

#define GI_RADIUS 16.0 // [1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0]
#define GI_QUALITY GI_MEDIUM // [GI_MINIMUM GI_LOW GI_MEDIUM GI_HIGH GI_ULTRA GI_CINEMATIC]

/*******************************************************************************
 - Misc settings
 ******************************************************************************/

//#define WHITE_WORLD
#define TORCH_LUMINANCE 200 // [50 100 150 200 250 300 350 400 450 500]
#define TORCH_TEMPERATURE 2500 // [1000 1500 2000 2500 3000 3500 4000]

#define UNDERGROUND_LIGHT_LEAK_FIX
