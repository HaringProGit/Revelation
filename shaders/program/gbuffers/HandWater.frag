
//======// Utility //=============================================================================//

#include "/lib/Utility.glsl"

//======// Output //==============================================================================//

/* RENDERTARGETS: 7,8 */
layout (location = 0) out vec4 gbufferOut0;
layout (location = 1) out vec2 gbufferOut1;

//======// Input //===============================================================================//

flat in mat3 tbnMatrix;

in vec4 tint;
in vec2 texCoord;
in vec2 lightmap;

in vec4 viewPos;

//======// Uniform //=============================================================================//

uniform sampler2D tex;

//======// Function //============================================================================//

float bayer2 (vec2 a) { a = 0.5 * floor(a); return fract(1.5 * fract(a.y) + a.x); }
#define bayer4(a) (bayer2(0.5 * (a)) * 0.25 + bayer2(a))

//======// Main //================================================================================//
void main() {
	vec4 albedo = texture(tex, texCoord) * tint;

	if (albedo.a < 0.1) { discard; return; }

	#ifdef WHITE_WORLD
		albedo.rgb = vec3(1.0);
	#endif

	gbufferOut0.x = packUnorm2x8Dithered(lightmap, bayer4(gl_FragCoord.xy));
	gbufferOut0.y = 2.1 * r255;

	gbufferOut0.z = packUnorm2x8(encodeUnitVector(tbnMatrix[2]));
	// gbufferOut0.w = gbufferOut0.z;

    gbufferOut1.x = packUnorm2x8(albedo.rg);
    gbufferOut1.y = packUnorm2x8(albedo.ba);
}