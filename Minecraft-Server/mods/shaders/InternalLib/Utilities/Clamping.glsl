/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

#define clamp01(x) clamp(x, 0.0, 1.0)

#define max0(x) max(x, 0.0)
#define max1(x) max(x, 1.0)
#define min0(x) min(x, 0.0)
#define min1(x) min(x, 1.0)

#define min3(x, y, z)    min(x, min(y, z))
#define min4(x, y, z, w) min(x, min(y, min(z, w)))

#define minVec2(x) min(x.x, x.y)
#define minVec3(x) min(x.x, min(x.y, x.z))
#define minVec4(x) min(x.x, min(x.y, min(x.z, x.w)))

#define max3(x, y, z)    max(x, max(y, z))
#define max4(x, y, z, w) max(x, max(y, max(z, w)))

#define maxVec2(x) max(x.x, x.y)
#define maxVec3(x) max(x.x, max(x.y, x.z))
#define maxVec4(x) max(x.x, max(x.y, max(x.z, x.w)))
