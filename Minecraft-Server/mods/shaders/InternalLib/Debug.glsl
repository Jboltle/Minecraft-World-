//#define DEBUG
#define DEBUG_VIEW -1 // [-1 0 9 10 11 12 13 20]

vec3 Debug = vec3(0.0);

void show(bool  x) { Debug = vec3(float(x)); }
void show(float x) { Debug = vec3(x); }
void show(vec2  x) { Debug = vec3(x, 0.0); }
void show(vec3  x) { Debug = x; }
void show(vec4  x) { Debug = x.rgb; }

#define show(x) show(x);

/*
=== ShaderStage indices ===

shadow              : [-2] // Unused
gbuffer opaque      : [-1]
deferredX           : [ 0 1 2 3 4 5 6 7] = [X]
gbuffer translucent : [ 9]
compositeX          : [10 11 12 13 14 15 16 17] = [1X]
final               : [20]
*/

void exit() {
#ifdef DEBUG
	
	#if ShaderStage == DEBUG_VIEW
		
		#if ShaderStage == -1
			gl_FragData[0] = vec4(Debug, 1.0);
		#elif ShaderStage == 0
			gl_FragData[0] = vec4(Debug, 1.0);
		#elif ShaderStage == 9
			gl_FragData[0] = vec4(Debug, 1.0);
		#elif ShaderStage == 10
			gl_FragData[1] = vec4(Debug, 1.0);
		#elif ShaderStage == 11
			gl_FragData[0] = vec4(Debug, 1.0);
		#elif ShaderStage == 12
			gl_FragData[0] = vec4(Debug, 1.0);
		#elif ShaderStage == 13
			gl_FragData[1] = vec4(Debug, 1.0);
		#elif ShaderStage == 20
			gl_FragColor = vec4(Debug, 1.0);
		#endif
		
	#elif ShaderStage > DEBUG_VIEW
		
		#if ShaderStage == 0
			gl_FragData[0] = vec4(texture2D(colortex0, texcoord).rgb, 1.0);
		#elif ShaderStage == 9
			discard;
		#elif ShaderStage == 10
			gl_FragData[1] = vec4(texture2D(colortex0, texcoord).rgb, 1.0);
		#elif ShaderStage == 11
			gl_FragData[0] = vec4(texture2D(colortex0, texcoord).rgb, 1.0);
		#elif ShaderStage == 12
			gl_FragData[0] = vec4(texture2D(colortex0, texcoord).rgb, 1.0);
		#elif ShaderStage == 13
			gl_FragData[1] = vec4(texture2D(colortex4, texcoord).rgb, 1.0);
		#elif ShaderStage == 20
			gl_FragColor = vec4(texture2D(colortex4, texcoord).rgb, 1.0);
		#endif
		
	#endif
	
#endif
}

#ifdef DEBUG
	#define discard gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0); return;
#endif
