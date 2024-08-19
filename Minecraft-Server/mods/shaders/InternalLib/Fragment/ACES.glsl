/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, March 2018
 */

 /*
=============================================================================
	ACES: Academy Color Encoding System
	https://github.com/ampas/aces-dev/tree/v1.0

	License Terms for Academy Color Encoding System Components

	Academy Color Encoding System (ACES) software and tools are provided by the Academy under
	the following terms and conditions: A worldwide, royalty-free, non-exclusive right to copy, modify, create
	derivatives, and use, in source and binary forms, is hereby granted, subject to acceptance of this license.

	Copyright © 2013 Academy of Motion Picture Arts and Sciences (A.M.P.A.S.). Portions contributed by
	others as indicated. All rights reserved.

	Performance of any of the aforementioned acts indicates acceptance to be bound by the following
	terms and conditions:

	 *	Copies of source code, in whole or in part, must retain the above copyright
		notice, this list of conditions and the Disclaimer of Warranty.
	 *	Use in binary form must retain the above copyright notice, this list of
		conditions and the Disclaimer of Warranty in the documentation and/or other
		materials provided with the distribution.
	 *	Nothing in this license shall be deemed to grant any rights to trademarks,
		copyrights, patents, trade secrets or any other intellectual property of
		A.M.P.A.S. or any contributors, except as expressly stated herein.
	 *	Neither the name "A.M.P.A.S." nor the name of any other contributors to this
		software may be used to endorse or promote products derivative of or based on
		this software without express prior written permission of A.M.P.A.S. or the
		contributors, as appropriate.

	This license shall be construed pursuant to the laws of the State of California,
	and any disputes related thereto shall be subject to the jurisdiction of the courts therein.

	Disclaimer of Warranty: THIS SOFTWARE IS PROVIDED BY A.M.P.A.S. AND CONTRIBUTORS "AS
	IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
	NON-INFRINGEMENT ARE DISCLAIMED. IN NO EVENT SHALL A.M.P.A.S., OR ANY
	CONTRIBUTORS OR DISTRIBUTORS, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
	SPECIAL, EXEMPLARY, RESITUTIONARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
	NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
	OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
	NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
	EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

	WITHOUT LIMITING THE GENERALITY OF THE FOREGOING, THE ACADEMY SPECIFICALLY
	DISCLAIMS ANY REPRESENTATIONS OR WARRANTIES WHATSOEVER RELATED TO PATENT OR
	OTHER INTELLECTUAL PROPERTY RIGHTS IN THE ACADEMY COLOR ENCODING SYSTEM, OR
	APPLICATIONS THEREOF, HELD BY PARTIES OTHER THAN A.M.P.A.S.,WHETHER DISCLOSED
	OR UNDISCLOSED.
=============================================================================
*/

/*******************************************************************************
 - Color Space Conversion Matricies
 ******************************************************************************/

float log10(float x) {
	const float a = 1.0 / log(10.0);
	return log(x) * a;
}

vec3 log10(vec3 x) {
	const float a = 1.0 / log(10.0);
	return log(x) * a;
}

/*******************************************************************************
 - ACES Helper Functions.
 ******************************************************************************/

float sigmoid_shaper(float x) { // Sigmoid function in the range 0 to 1 spanning -2 to +2.
	float t = max(1.0 - abs(0.5 * x), 0.0);
	float y = 1.0 + sign(x) * (1.0 - t * t);

	return 0.5 * y;
}

float rgb_2_saturation(vec3 rgb) {
	float minrgb = min(min(rgb.r, rgb.g), rgb.b);
	float maxrgb = max(max(rgb.r, rgb.g), rgb.b);

	return (max(maxrgb, 1e-10) - max(minrgb, 1e-10)) / max(maxrgb, 1e-2);
}

float rgb_2_yc(vec3 rgb, float ycRadiusWeight) { // Converts RGB to a luminance proxy, here called YC. YC is ~ Y + K * Chroma.
	float chroma = sqrt(rgb.b * (rgb.b - rgb.g) + rgb.g * (rgb.g - rgb.r) + rgb.r * (rgb.r - rgb.b));

	return (rgb.b + rgb.g + rgb.r + ycRadiusWeight * chroma) / 3.0;
}

float glow_fwd(float ycIn, float glowGainIn, float glowMid) {
	float glowGainOut;

	if (ycIn <= 2.0 / 3.0 * glowMid) {
		glowGainOut = glowGainIn;
	} else if ( ycIn >= 2.0 * glowMid) {
		glowGainOut = 0;
	} else {
		glowGainOut = glowGainIn * (glowMid / ycIn - 0.5);
	}

	return glowGainOut;
}

float rgb_2_hue(vec3 rgb) { // Returns a geometric hue angle in degrees (0-360) based on RGB values.
	float hue;
	if (rgb[0] == rgb[1] && rgb[1] == rgb[2]) { // For neutral colors, hue is undefined and the function will return a quiet NaN value.
		hue = 0;
	} else {
		hue = (180.0 * rPI) * atan(2.0 * rgb[0] - rgb[1] - rgb[2], sqrt(3.0) * (rgb[1] - rgb[2])); // flip due to opengl spec compared to hlsl
	}

	if (hue < 0.0)
		hue = hue + 360.0;

	return clamp(hue, 0.0, 360.0);
}

float center_hue(float hue, float centerH) {
	float hueCentered = hue - centerH;

	if (hueCentered < -180.0) {
		hueCentered += 360.0;
	} else if (hueCentered > 180.0) {
		hueCentered -= 360.0;
	}

	return hueCentered;
}

// Transformations between CIE XYZ tristimulus values and CIE x,y
// chromaticity coordinates
vec3 XYZ_2_xyY( vec3 XYZ ) {
	float divisor = max(XYZ[0] + XYZ[1] + XYZ[2], 1e-10);

	vec3 xyY    = XYZ.xyy;
	     xyY.rg = XYZ.rg / divisor;

	return xyY;
}

vec3 xyY_2_XYZ(vec3 xyY) {
	vec3 XYZ   = vec3(0.0);
	     XYZ.r = xyY.r * xyY.b / max(xyY.g, 1e-10);
	     XYZ.g = xyY.b;
	     XYZ.b = (1.0 - xyY.r - xyY.g) * xyY.b / max(xyY.g, 1e-10);

	return XYZ;
}

mat3 ChromaticAdaptation( vec2 src_xy, vec2 dst_xy ) {
	// Von Kries chromatic adaptation

	// Bradford
	const mat3 ConeResponse = mat3(
		 vec3(0.8951,  0.2664, -0.1614),
		vec3(-0.7502,  1.7135,  0.0367),
		 vec3(0.0389, -0.0685,  1.0296)
	);
	const mat3 InvConeResponse = mat3(
		vec3(0.9869929, -0.1470543,  0.1599627),
		vec3(0.4323053,  0.5183603,  0.0492912),
		vec3(-0.0085287,  0.0400428,  0.9684867)
	);

	vec3 src_XYZ = xyY_2_XYZ( vec3( src_xy, 1 ) );
	vec3 dst_XYZ = xyY_2_XYZ( vec3( dst_xy, 1 ) );

	vec3 src_coneResp = src_XYZ * ConeResponse;
	vec3 dst_coneResp = dst_XYZ *  ConeResponse;

	mat3 VonKriesMat = mat3(
		vec3(dst_coneResp[0] / src_coneResp[0], 0.0, 0.0),
		vec3(0.0, dst_coneResp[1] / src_coneResp[1], 0.0),
		vec3(0.0, 0.0, dst_coneResp[2] / src_coneResp[2])
	);

	return (ConeResponse * VonKriesMat) * InvConeResponse;
}

/*******************************************************************************
 - Color CorrectionUE4 Style
 ******************************************************************************/

 // Accurate for 1000K < Temp < 15000K
// [Krystek 1985, "An algorithm to calculate correlated colour temperature"]
vec2 PlanckianLocusChromaticity(float Temp) {
	float u = ( 0.860117757f + 1.54118254e-4f * Temp + 1.28641212e-7f * Temp*Temp ) / ( 1.0f + 8.42420235e-4f * Temp + 7.08145163e-7f * Temp*Temp );
	float v = ( 0.317398726f + 4.22806245e-5f * Temp + 4.20481691e-8f * Temp*Temp ) / ( 1.0f - 2.89741816e-5f * Temp + 1.61456053e-7f * Temp*Temp );

	float x = 3.0*u / ( 2.0*u - 8.0*v + 4.0 );
	float y = 2.0*v / ( 2.0*u - 8.0*v + 4.0 );

	return vec2(x, y);
}

 vec2 D_IlluminantChromaticity(float Temp) {
	// Accurate for 4000K < Temp < 25000K
	// in: correlated color temperature
	// out: CIE 1931 chromaticity
	// Correct for revision of Plank's law
	// This makes 6500 == D65
	Temp *= 1.000556328;

	float x =	Temp <= 7000 ?
				0.244063 + ( 0.09911e3 + ( 2.9678e6 - 4.6070e9 / Temp ) / Temp ) / Temp :
				0.237040 + ( 0.24748e3 + ( 1.9018e6 - 2.0064e9 / Temp ) / Temp ) / Temp;

	float y = -3 * x*x + 2.87 * x - 0.275;

	return vec2(x,y);
}

vec2 PlanckianIsothermal( float Temp, float Tint ) {
	float u = ( 0.860117757f + 1.54118254e-4f * Temp + 1.28641212e-7f * Temp*Temp ) / ( 1.0f + 8.42420235e-4f * Temp + 7.08145163e-7f * Temp*Temp );
	float v = ( 0.317398726f + 4.22806245e-5f * Temp + 4.20481691e-8f * Temp*Temp ) / ( 1.0f - 2.89741816e-5f * Temp + 1.61456053e-7f * Temp*Temp );

	float ud = ( -1.13758118e9f - 1.91615621e6f * Temp - 1.53177f * Temp*Temp ) / pow( 1.41213984e6f + 1189.62f * Temp + Temp*Temp, 2.0 );
	float vd = (  1.97471536e9f - 705674.0f * Temp - 308.607f * Temp*Temp ) / pow( 6.19363586e6f - 179.456f * Temp + Temp*Temp , 2.0); //don't pow2 this

	vec2 uvd = normalize( vec2( u, v ) );

	// Correlated color temperature is meaningful within +/- 0.05
	u += -uvd.y * Tint * 0.05;
	v +=  uvd.x * Tint * 0.05;

	float x = 3*u / ( 2*u - 8*v + 4 );
	float y = 2*v / ( 2*u - 8*v + 4 );

	return vec2(x,y);
}

vec3 WhiteBalance(vec3 LinearColor) {
	const float WhiteTemp = float(WHITE_BALANCE);
	const float WhiteTint = float(TINT_BALANCE) * 0.25;
	vec2 SrcWhiteDaylight = D_IlluminantChromaticity( WhiteTemp );
	vec2 SrcWhitePlankian = PlanckianLocusChromaticity( WhiteTemp );

	vec2 SrcWhite = WhiteTemp < 4000 ? SrcWhitePlankian : SrcWhiteDaylight;
	const vec2 D65White = vec2(0.31270,  0.32900);

	// Offset along isotherm
	vec2 Isothermal = PlanckianIsothermal( WhiteTemp, WhiteTint ) - SrcWhitePlankian;
	SrcWhite += Isothermal;

	mat3x3 WhiteBalanceMat = ChromaticAdaptation( D65White, SrcWhite );
	WhiteBalanceMat = (sRGB_2_XYZ_MAT * WhiteBalanceMat) * XYZ_2_sRGB_MAT;

	return LinearColor * WhiteBalanceMat;
}

/*******************************************************************************
 - ACES Fimic Curve Approx.
 ******************************************************************************/

// ACES settings
vec3 FilmToneMap(vec3 LinearColor) {
    const mat3 AP1_2_sRGB = (AP1_2_XYZ_MAT * D60_2_D65_CAT) * XYZ_2_sRGB_MAT;

    const mat3 AP0_2_AP1 = AP0_2_XYZ_MAT * XYZ_2_AP1_MAT;
    const mat3 AP1_2_AP0 = AP1_2_XYZ_MAT * XYZ_2_AP0_MAT;

    vec3 ColorAP1 = LinearColor * AP0_2_AP1;
    float LumaAP1 = dot( ColorAP1, AP1_RGB2Y );

    vec3 ChromaAP1 = ColorAP1 / LumaAP1;

    float ChromaDistSqr = dot(ChromaAP1 - 1.0, ChromaAP1 - 1);
    float ExpandAmount = (1.0 - exp2(-4.0 * ChromaDistSqr)) * ( 1.0 - exp2(-4.0 * ACES_EXPAND_GAMUT * LumaAP1 * LumaAP1));

    const mat3 Wide_2_XYZ_MAT = mat3(
        vec3(0.5441691,  0.2395926,  0.1666943),
        vec3(0.2394656,  0.7021530,  0.0583814),
        vec3(-0.0023439,  0.0361834,  1.0552183)
    );

    const mat3 Wide_2_AP1 = Wide_2_XYZ_MAT * XYZ_2_AP1_MAT;
    const mat3 ExpandMat = AP1_2_sRGB * Wide_2_AP1;

    vec3 ColorExpand = ColorAP1 * ExpandMat;
    ColorAP1 = mix(ColorAP1, ColorExpand, ExpandAmount);

    vec3 ColorAP0 = ColorAP1 * AP1_2_AP0;

    // "Glow" module constants
    const float RRT_GLOW_GAIN = 0.05;
    const float RRT_GLOW_MID = 0.08;

    float saturation = rgb_2_saturation(ColorAP0);
    float ycIn = rgb_2_yc(ColorAP0, 1.75);

    float s = sigmoid_shaper((saturation - 0.4) * 5.0);
    float addedGlow = 1.0 + glow_fwd(ycIn, RRT_GLOW_GAIN * s, RRT_GLOW_MID);
    ColorAP0 *= addedGlow;

    // Use ACEScg primaries as working space
    vec3 WorkingColor = ColorAP0 * AP0_2_AP1;
         WorkingColor = max(vec3(0.0), WorkingColor);

    const float ToeScale      = 1.0 + ACES_BLACK_CLIP - ACES_TOE;
    const float ShoulderScale = 1.0 + ACES_WHITE_CLIP - ACES_SHOULDER;

    const float InMatch  = 0.18;
    const float OutMatch = 0.18;

    float ToeMatch = 0.0;
    if(ACES_TOE > 0.8) {
        // 0.18 will be on straight segment
        ToeMatch = (1.0 - ACES_TOE - OutMatch) / ACES_SLOPE + log10(InMatch);
    } else {
        // 0.18 will be on toe segment
        // Solve for ToeMatch such that input of InMatch gives output of OutMatch.
        const float bt = (OutMatch + ACES_BLACK_CLIP) / ToeScale - 1.0;
        ToeMatch = log10(InMatch) - 0.5 * log((1.0 + bt) / (1.0 - bt)) * (ToeScale / ACES_SLOPE);
    }

    float StraightMatch = (1.0 - ACES_TOE) / ACES_SLOPE - ToeMatch;
    float ShoulderMatch = ACES_SHOULDER / ACES_SLOPE - StraightMatch;

    vec3 LogColor = log10(WorkingColor);
    vec3 StraightColor = ACES_SLOPE * (LogColor + StraightMatch);

    vec3 ToeColor        = (-ACES_BLACK_CLIP) + (2.0 * ToeScale) / (1.0 + exp2((-2.0 * ACES_SLOPE / ToeScale) * (LogColor - ToeMatch) * rLOG2));
    vec3 ShoulderColor   = (1.0 + ACES_WHITE_CLIP) - (2.0 * ShoulderScale) / (exp2(( 2.0 * ACES_SLOPE / ShoulderScale) * (LogColor - ShoulderMatch) * rLOG2) + 1.0);

    for(int i = 0; i < 3; ++i) {
        ToeColor[i] = LogColor[i] < ToeMatch ? ToeColor[i] : StraightColor[i];
        ShoulderColor[i] = LogColor[i] > ShoulderMatch ? ShoulderColor[i] : StraightColor[i];
    }

    vec3 t = clamp((LogColor - ToeMatch) / (ShoulderMatch - ToeMatch), 0.0, 1.0);
         t = ShoulderMatch < ToeMatch ? 1.0 - t : t;
         t = (3.0 - 2.0 * t) * t * t;

    vec3 ToneColor = mix(ToeColor, ShoulderColor, t);

    // Returning positive AP1 values
    return max(vec3(0.0), ToneColor * AP1_2_sRGB);
}

/*******************************************************************************
 - ACES Real, slow, never actually use in production.
 ******************************************************************************/
/*
float cubic_basis_shaper(float x, float w) {
	//return Square( smoothstep( 0, 1, 1 - abs( 2 * x/w ) ) );

	const mat4 M = mat4(
		vec4(-1.0 / 6.0,  3.0 / 6.0, -3.0 / 6.0,  1.0 / 6.0),
		vec4(3.0 / 6.0, -6.0 / 6.0,  3.0 / 6.0,  0.0 / 6.0),
		vec4(-3.0 / 6.0,  0.0 / 6.0,  3.0 / 6.0,  0.0 / 6.0),
		vec4(1.0 / 6.0,  4.0 / 6.0,  1.0 / 6.0,  0.0 / 6.0)
	);

	float knots[5] = float[5](-0.5 * w, -0.25 * w, 0, 0.25 * w, 0.5 * w);

	float y = 0;
	if ((x > knots[0]) && (x < knots[4])) {
		float knot_coord = (x - knots[0]) * 4.0 / w;
		int j = int(knot_coord);
		float t = knot_coord - j;

		vec4 monomials = vec4(t * t * t, t * t, t, 1.0);

		// (if/else structure required for compatibility with CTL < v1.5.)
		if (j == 3) {
			y = monomials[0] * M[0][0] + monomials[1] * M[1][0] +
				monomials[2] * M[2][0] + monomials[3] * M[3][0];
		} else if (j == 2) {
			y = monomials[0] * M[0][1] + monomials[1] * M[1][1] +
				monomials[2] * M[2][1] + monomials[3] * M[3][1];
		} else if (j == 1) {
			y = monomials[0] * M[0][2] + monomials[1] * M[1][2] +
				monomials[2] * M[2][2] + monomials[3] * M[3][2];
		} else if (j == 0) {
			y = monomials[0] * M[0][3] + monomials[1] * M[1][3] +
				monomials[2] * M[2][3] + monomials[3] * M[3][3];
		} else {
			y = 0.0;
		}
	}

	return y * 1.5; //Why do dis?
}

#include "/InternalLib/Fragment/ACESSplines.glsl"

vec3 RRT(vec3 aces) {
	// "Glow" module constants. No idea what the actual fuck this even means.
	const float RRT_GLOW_GAIN = 0.05;
	const float RRT_GLOW_MID = 0.08;

	float saturation = rgb_2_saturation(aces);
	float ycIn = rgb_2_yc(aces, 1.75);
	float s = sigmoid_shaper((saturation - 0.4) / 0.2);
	float addedGlow = 1.0 + glow_fwd(ycIn, RRT_GLOW_GAIN * s, RRT_GLOW_MID);
	aces *= addedGlow;

	// --- Red modifier --- //
	const float RRT_RED_SCALE = 0.82;
	const float RRT_RED_PIVOT = 0.03;
	const float RRT_RED_HUE = 0;
	const float RRT_RED_WIDTH = 135;
	float hue = rgb_2_hue(aces);
	float centeredHue = center_hue(hue, RRT_RED_HUE);
	float hueWeight = cubic_basis_shaper(centeredHue, RRT_RED_WIDTH);

	aces.r += hueWeight * saturation * (RRT_RED_PIVOT - aces.r) * (1.0 - RRT_RED_SCALE);

	// --- ACES to RGB rendering space --- //
	aces = clamp(aces, 0, 65535.0);  // avoids saturated negative colors from becoming positive in the matrix
	vec3 rgbPre = aces * AP0_2_AP1_MAT;
	rgbPre = clamp(rgbPre, 0.0, 65535.0);

	// --- Global desaturation --- //
	const float RRT_SAT_FACTOR = 0.96;
	rgbPre = mix(vec3(dot(rgbPre, AP1_RGB2Y)), rgbPre, vec3(RRT_SAT_FACTOR));

	// --- Apply the tonescale independently in rendering-space RGB --- //
	vec3 rgbPost = vec3(0.0);
	rgbPost.r = segmented_spline_c5_fwd(rgbPre.r);
	rgbPost.g = segmented_spline_c5_fwd(rgbPre.g);
	rgbPost.b = segmented_spline_c5_fwd(rgbPre.b);

	// --- RGB rendering space to OCES --- //
	return rgbPost * AP1_2_AP0_MAT;
}

vec3 Y_2_linCV(vec3 Y, float Ymax, float Ymin)  {
	return (Y - Ymin) / (Ymax - Ymin);
}

const float DIM_SURROUND_GAMMA = 0.9811;

vec3 darkSurround_to_dimSurround(vec3 linearCV) {
	vec3 XYZ = linearCV * AP1_2_XYZ_MAT;

	vec3 xyY = XYZ_2_xyY(XYZ);
	xyY[2] = clamp(xyY[2], 0, 65535.0);
	xyY[2] = pow(xyY[2], DIM_SURROUND_GAMMA);
	XYZ = xyY_2_XYZ(xyY);

	return XYZ * XYZ_2_AP1_MAT;
}

vec3 ODT_sRGB_D65(vec3 oces) {
	// OCES to RGB rendering space
	vec3 rgbPre = oces * AP0_2_AP1_MAT;

	const SegmentedSplineParams_c9 ODT_48nits = SegmentedSplineParams_c9(
		float[10] ( -1.6989700043, -1.6989700043, -1.4779000000, -1.2291000000, -0.8648000000, -0.4480000000, 0.0051800000, 0.4511080334, 0.9113744414, 0.9113744414 ), // coefsLow[10]
		float[10] ( 0.5154386965, 0.8470437783, 1.1358000000, 1.3802000000, 1.5197000000, 1.5985000000, 1.6467000000, 1.6746091357, 1.6878733390, 1.6878733390 ), // coefsHigh[10]
		0.0, // slopeLow
		0.04 // slopeHigh
	);

	vec3 splines = vec3(0.0);
	splines.r = segmented_spline_c5_fwd(0.18 * exp2(-6.5)); // vec3(minPoint, midPoint, MaxPoint)
	splines.g = segmented_spline_c5_fwd(0.18);
	splines.b = segmented_spline_c5_fwd(0.18 * exp2(6.5));

	mat3x2 toningPoints = mat3x2(
		splines.x, 0.02,
		splines.y, 4.8,
		splines.z, 48.0
	);

	// Apply the tonescale independently in rendering-space RGB
	vec3 rgbPost = vec3(0.0);
	rgbPost.r = segmented_spline_c9_fwd(rgbPre.r, ODT_48nits, toningPoints);
	rgbPost.g = segmented_spline_c9_fwd(rgbPre.g, ODT_48nits, toningPoints);
	rgbPost.b = segmented_spline_c9_fwd(rgbPre.b, ODT_48nits, toningPoints);

	// Target white and black points for cinema system tonescale
	const float CINEMA_WHITE = 48.0;
	const float CINEMA_BLACK = 0.02; // CINEMA_WHITE / 2400.

	// Scale luminance to linear code value
	vec3 linearCV = Y_2_linCV(rgbPost, CINEMA_WHITE, CINEMA_BLACK);

	// Apply gamma adjustment to compensate for dim surround
	//linearCV = darkSurround_to_dimSurround(linearCV);

	// Apply desaturation to compensate for luminance difference
	const float ODT_SAT_FACTOR = 0.93;
	linearCV = mix(vec3(dot(linearCV, AP1_RGB2Y)), linearCV, vec3(ODT_SAT_FACTOR));

	// Convert to display primary encoding
	// Rendering space RGB to XYZ
	vec3 XYZ = linearCV * AP1_2_XYZ_MAT;

	// Apply CAT from ACES white point to assumed observer adapted white point
	XYZ = XYZ * D60_2_D65_CAT;

	// CIE XYZ to display primaries
	linearCV = XYZ * XYZ_2_sRGB_MAT;

	return clamp(linearCV, 0.0, 1.0);
}

vec3 ACESOutputTransformsRGBD65(vec3 aces) {
	vec3 oces = RRT(aces);
	vec3 OutputReferredLinearsRGBColor =  ODT_sRGB_D65(oces);

	return OutputReferredLinearsRGBColor;
}*/
