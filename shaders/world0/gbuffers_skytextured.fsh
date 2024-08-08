#version 450 core

/*
--------------------------------------------------------------------------------

	Revelation Shaders

	Copyright (C) 2024 HaringPro
	Apache License 2.0

--------------------------------------------------------------------------------
*/

//======// Output //==============================================================================//

/* RENDERTARGETS: 6 */
out vec3 albedoOut;

//======// Input //===============================================================================//

in vec3 tint;
in vec2 texCoord;

//======// Uniform //=============================================================================//

uniform sampler2D tex;

//======// Main //================================================================================//
void main() {
	vec4 albedo = texture(tex, texCoord);

	if (albedo.a < 0.1) { discard; return; }

	albedoOut = albedo.rgb * tint;
}