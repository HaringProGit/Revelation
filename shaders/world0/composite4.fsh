#version 450 compatibility

/*
--------------------------------------------------------------------------------

	Revelation Shaders

	Copyright (C) 2024 HaringPro
	Apache License 2.0

--------------------------------------------------------------------------------
*/

//======// Utility //=============================================================================//

#include "/lib/utility.inc"

//======// Output //==============================================================================//

/* RENDERTARGETS: 0 */
out vec3 sceneOut;

//======// Input //===============================================================================//

//======// Attribute //===========================================================================//

//======// Uniform //=============================================================================//

uniform sampler2D colortex0;
// uniform sampler2D colortex8;

//======// Struct //==============================================================================//

//======// Function //============================================================================//

//================================================================================================//

//======// Main //================================================================================//
void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);

    sceneOut = texelFetch(colortex0, texel, 0).rgb;

    // vec4 translucentAlbedo = texelFetch(colortex8, texel, 0);

    // sceneOut *= sqr(mix(vec3(1.0), translucentAlbedo.rgb, pow(translucentAlbedo.a, 0.2)));
}
