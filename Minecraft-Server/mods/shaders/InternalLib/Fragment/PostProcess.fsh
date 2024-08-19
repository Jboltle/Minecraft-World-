/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, Febuary 2018
 */

struct ColorCorrection {
	float saturation;
	float vibrance;
	vec3 lum;
	float contrast;
	float contrastMidpoint;

	vec3 gain;
	vec3 lift;
	vec3 InvGamma;
} m;

vec3 Saturation(vec3 color, ColorCorrection m) {
	float grey = dot(color, m.lum);
	return grey + m.saturation * (color - grey);
}

vec3 Vibrance(vec3 color, ColorCorrection m) {
	float maxColor = max3(color.r, color.g, color.b);
	float minColor = min3(color.r, color.g, color.b);

	float colorSaturation = maxColor - minColor;

	float grey = dot(color, m.lum);
	color = mix(vec3(grey), color, 1.0 + m.vibrance * (1.0 - sign(m.vibrance) * colorSaturation));

	return color;
}

float LogContrast(float x, const float eps, float logMidpoint, float contrast) {
	float logX = log2(x + eps);
	float adjX = (logX - logMidpoint) / contrast + logMidpoint;

	return max0(exp2(adjX) - eps);
}

vec3 Contrast(vec3 color, ColorCorrection m) {
	const float contrastEpsilon = 1e-5;

	vec3 ret;
	     ret.x = LogContrast(color.x, contrastEpsilon, log2(0.18), m.contrast);
		 ret.y = LogContrast(color.y, contrastEpsilon, log2(0.18), m.contrast);
		 ret.z = LogContrast(color.z, contrastEpsilon, log2(0.18), m.contrast);

	return ret;
}

vec3 LiftGammaGain(vec3 v, ColorCorrection m) {
	vec3 lerpV = clamp01(pow(v, m.InvGamma));
	return m.gain * lerpV + m.lift * (1.0 - lerpV);
}

vec3 jodieReinhardTonemap(vec3 c) {
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (c + 1.0);
    return mix(c / (l + 1.0), tc, tc);
}

vec3 hableTonemap(vec3 x) {
	const float hA = 0.15;
	const float hB = 0.50;
	const float hC = 0.10;
	const float hD = 0.20;
	const float hE = 0.02;
	const float hF = 0.30;

	const float hW = 11.3;
	const float whiteScale = 1.0f / ((hW*(hA*hW+hC*hB)+hD*hE) / (hW*(hA*hW+hB)+hD*hF)) - hE/hF;

	x *= 2.0; //Solve for log factor of 2, dont ask its math stuff in the function this is right.

	return (((x*(hA*x+hC*hB)+hD*hE) / (x*(hA*x+hB)+hD*hF)) - hE/hF) * whiteScale;
}

#if defined composite2
#ifdef LENS_FLARE
	float GetFocus(float depth) {
		const float focalLength = CAMERA_FOCAL_LENGTH / 1000.0;
		const float aperture = (CAMERA_FOCAL_LENGTH / CAMERA_APERTURE) / 1000.0;

		#if CAMERA_FOCUS_MODE == 0
			float focus = ScreenToViewSpaceDepth(centerDepthSmooth);
		#else
			float focus = ScreenToViewSpaceDepth(getDepthExp(CAMERA_FOCAL_POINT));
		#endif

		return aperture * (focalLength * (focus - depth)) / (focus * (depth - focalLength));
	}

	float GetLensDefraction(vec2 position, vec2 sunpos) {
		vec2 aspectCorrect = 1.0 / vec2(1.0, aspectRatio);

		position *= aspectCorrect;
		sunpos *= aspectCorrect;

		vec2 t = position.xy - sunpos.xy;
		float bladeMask = atan(t.x, t.y)*CAMERA_BLADES;
		float dist = pow4(0.05 / distance(sunpos, position.xy) - 0.05);
		float blade = pow8(sin(PI * 0.5 + bladeMask) + 0.5) * abs(sin(bladeMask * 2.0));

		return dist * (1.0 + blade);
	}

    vec3 ThinFilmInterference(const float deg) {
        const float nf = sqrt(1.5176);
        const float d = 570.0 / (4.0 * nf);
        const float twoNFD = 2.0 * nf * d;

        const vec3 lensCoeff = vec3(750.0, 570.0, 495.0);
        const vec3 oneOverLensCoeff = 1.0 / lensCoeff;

        return (twoNFD * cos(radians(deg))) * oneOverLensCoeff + 0.5;
    }

	float SmoothCircleDist(vec2 lightPos, float lensDist) {
        lightPos  = lightPos * 2.0 - 1.0;
        lightPos *= lensDist;
        lightPos  = lightPos * 0.5 + 0.5;

        float xvect = lightPos.x * aspectRatio - texcoord.x * aspectRatio;
 		float yvect = lightPos.y - texcoord.y;

		return sqrt(xvect * xvect + (yvect*yvect));
	}

	vec2 GhostVector(vec2 lightPos, float dist, float distFromFocal, out float size) {
        const float oneOverExp2 = 1.0 / exp2(2.0);

        size = GetFocus((distFromFocal + CAMERA_FOCAL_LENGTH) * 0.001) / aspectRatio;
        vec2 aspectCorrect = 1.0 / vec2(1.0, aspectRatio);

        vec2 coord = ((texcoord * 2.0 - 1.0) * aspectCorrect / size) * 0.5 + 0.5;
        vec2 flarePos = coord * oneOverExp2 + bokehOffset;
             flarePos = flarePos + ((lightPos * 2.0 - 1.0) * aspectCorrect) * ((-dist * 0.25) / size);
		return flarePos;
	}

    vec3 GhostBokeh(vec2 lightPos, float dist, float distFromFocal) {
        const float oneOverExp2 = 1.0 / exp2(2.0);

        float size = 0.0;
        vec2 coord = GhostVector(lightPos, dist, distFromFocal, size);
        vec3 crop  = vec3(1.0, 1.0, 0.0) * oneOverExp2 + bokehOffset.xyx;
        return texture2D(colortex0, coord).rgb * float(coord.x < crop.r && coord.y < crop.g && coord.x > crop.b && coord.y > bokehOffset.y);
    }

    float GhostSoft(vec2 lightPos, float dist, float distFromFocal) {
        float size = GetFocus((distFromFocal + CAMERA_FOCAL_LENGTH) * 0.001) / aspectRatio;
        float ghost = inversesqrt((SmoothCircleDist(lightPos, dist) * 10.0 + size) + 0.001);
        return pow2(ghost * 0.5);
    }

	void GetLensFlare(inout vec3 color) {
		#ifndef LENS_FLARE
			return;
		#endif

		vec2 lightPos = ViewSpaceToScreenSpace(sunPosition).xy;

		float distof = min(min(1.0 - lightPos.x, lightPos.x),
                       min(    1.0 - lightPos.y, lightPos.y));
		float fading = clamp01(1.0 - step(distof, 0.0) + pow5(distof * 10.0));

		float sunvisibility  = 1.0 - float(texture2D(depthtex1, lightPos).x < 1.0);
		      sunvisibility *= fading;

		vec3 lightVector = normalize(sunPosition);

		vec3 lens = vec3(0.0);
		vec3 sunlightColor = DecodeColor(DecodeRGBE8(texture2D(colortex2, texcoord))) * LENS_FLARE_STRENGTH;
        vec3 lensColor = ThinFilmInterference(140.0);

        lens += GhostBokeh(lightPos, -0.25,  -3.0);
		lens += GhostBokeh(lightPos, -0.30,   2.5);
		lens += GhostBokeh(lightPos, -0.35,  -4.0);
		lens += GhostBokeh(lightPos, -0.40,  -5.0);
		lens += GhostBokeh(lightPos, -0.70,  -4.0);
		lens += GhostBokeh(lightPos, -0.80,   2.5);
		lens += GhostBokeh(lightPos, -0.90,   4.0);
		lens += GhostBokeh(lightPos, -0.95,  -3.0);
		lens += GhostBokeh(lightPos, -1.00,  -4.0);
		lens += GhostSoft(lightPos, -0.70 / SmoothCircleDist(lightPos, 0.0), 1.5) * 8.0;

		lens += GhostSoft(lightPos, -0.3, 1.0) * 0.3;
		lens += GhostSoft(lightPos, -0.5, 1.0) * 0.3;
		lens += GhostSoft(lightPos, -0.6, 2.0) * 3.0;
		lens += GhostSoft(lightPos, -0.7, 1.0) * 0.3;
        lens *= lensColor;

		lens *= sunlightColor * (1.0 - clamp01(lightVector.z / abs(lightVector.z))) * sunvisibility;

		color.rgb += lens;
	}
#endif
#endif

vec3 Lookup(vec3 color, sampler2D lookupTable) {
    float blueColor = color.b * 63.0;

    vec4 quad = vec4(0.0);
    quad.y = floor(floor(blueColor) * 0.125);
    quad.x = floor(blueColor) - (quad.y * 8.0);
	quad.w = floor(ceil(blueColor) * 0.125);
    quad.z = ceil(blueColor) - (quad.w * 8.0);

    vec4 texPos = (quad * 0.125) + (0.123046875 * color.rg).xyxy + 0.0009765625;

    vec3 newColor1 = texture2D(lookupTable, texPos.xy).rgb;
    vec3 newColor2 = texture2D(lookupTable, texPos.zw).rgb;

    return mix(newColor1, newColor2, fract(blueColor));
}
