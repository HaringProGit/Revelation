/*
--------------------------------------------------------------------------------

	Revelation Shaders

	Copyright (C) 2024 HaringPro
	Apache License 2.0

	Pass:

--------------------------------------------------------------------------------
*/

layout (local_size_x = 8, local_size_y = 8) in;
const vec2 workGroupsRender = vec2(1.0f, 1.0f);

//======// Utility //=============================================================================//

#include "/lib/utility.inc"

//======// Output //==============================================================================//

layout (rgba16f, location = 0) restrict uniform image2D colorimg0; //
layout (rgba16f, location = 1) restrict uniform image2D colorimg1; //
layout (rgba16f, location = 2) restrict uniform image2D colorimg2; //

//======// Uniform //=============================================================================//

uniform sampler2D sampler0;
uniform sampler2D sampler1;
uniform sampler2D sampler2;

//======// Struct //==============================================================================//

//======// Function //============================================================================//

//================================================================================================//

//======// Main //================================================================================//
void main() {
	ivec2 screenTexel = ivec2(gl_GlobalInvocationID.xy);
    vec2 screenCoord = vec2(gl_GlobalInvocationID.xy) * viewPixelSize;
	imageStore(colorimg0, screenTexel, vec4(texture(sampler0, texCoord).rgb, 1.0));
}