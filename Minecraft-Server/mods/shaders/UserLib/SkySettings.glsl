/*******************************************************************************
 - 2D Clouds Settings
 ******************************************************************************/

#define CLOUDS_2D
#define CLOUDS_2D_DENSITY 3.0 //[1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
#define CLOUDS_2D_COVERAGE 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]

#define sky_atmosphereHeight 8228.0 // Physically-based thickness of the atmosphere.
#define sky_earthRadius 6371000.0 // Physically-based radius of the Earth.
#define sky_mieMultiplier 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define sky_ozoneMultiplier 1.0 // 1.0 for physically-based. [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define sky_rayleighDistribution 8.0 // Physically-based.
#define sky_mieDistribution 1.2 // Physically-based.
#define sky_sunLuminanceBase 107000 // Physically-based. [80000 85000 90000 95000 100000 107000 110000 120000 130000 140000]
#define sky_moonLuminanceBase 0.318 // Physically-based. [0.0 0.1 0.2 0.3 0.318 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define sky_sunColorTemperature 5500 // [4000 4500 5000 5500 6000 6500 7000]
#define sky_moonColorTemperature 6500 // [4500 5000 5500 6000 6500 7000 7500 8000 8500]
#define sky_sunColor (blackbody(sky_sunColorTemperature) * sky_sunLuminanceBase) // Physically-based.
#define sky_moonColor (blackbody(sky_moonColorTemperature)* sky_moonLuminanceBase)
#define sky_ozoneHeight 30000.0 // Physically-based (Kutz).
#define sky_ozoneCoefficient ( vec3(3.426, 8.298, 0.356) * 6.0e-7 * sky_ozoneMultiplier ) // Physically-based (Kutz).
#define sky_mieCoefficient ( 3.0e-6 * sky_mieMultiplier ) // Good default.

// ( Riley, Ebert, Kraus )
//#define sky_rayleighCoefficient vec3(5.8e-6  , 1.35e-5 , 3.31e-5 )
// ( Bucholtz )
//#define sky_rayleighCoefficient vec3(4.847e-6, 1.149e-5, 2.87e-5 )
// ( Thalman, Zarzana, Tolbert, Volkamer )
//#define sky_rayleighCoefficient vec3(5.358e-6, 1.253e-5, 3.062e-5)
// ( Penndorf )
//#define sky_rayleighCoefficient vec3(5.178e-6, 1.226e-5, 3.06e-5)
// ( Jodie )
#define sky_rayleighCoefficient vec3(4.593e-6, 1.097e-5, 2.716e-5)
