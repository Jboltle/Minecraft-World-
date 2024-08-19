/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

 float bayer2(vec2 a) {
     a = floor(a);

     return fract(dot(a, vec2(0.5, a.y * 0.75)));
 }

 float bayer4(const vec2 a)   { return bayer2 (0.5   * a) * 0.25     + bayer2(a); }
 float bayer8(const vec2 a)   { return bayer4 (0.5   * a) * 0.25     + bayer2(a); }
 float bayer16(const vec2 a)  { return bayer4 (0.25  * a) * 0.0625   + bayer4(a); }
 float bayer32(const vec2 a)  { return bayer8 (0.25  * a) * 0.0625   + bayer4(a); }
 float bayer64(const vec2 a)  { return bayer8 (0.125 * a) * 0.015625 + bayer8(a); }
 float bayer128(const vec2 a) { return bayer16(0.125 * a) * 0.015625 + bayer8(a); }

 #define dither2(p)   (bayer2(  p) - 0.375      )
 #define dither4(p)   (bayer4(  p) - 0.46875    )
 #define dither8(p)   (bayer8(  p) - 0.4921875  )
 #define dither16(p)  (bayer16( p) - 0.498046875)
 #define dither32(p)  (bayer32( p) - 0.499511719)
 #define dither64(p)  (bayer64( p) - 0.49987793 )
 #define dither128(p) (bayer128(p) - 0.499969482)
