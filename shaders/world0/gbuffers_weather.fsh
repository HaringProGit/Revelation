#version 450 compatibility

/*
--------------------------------------------------------------------------------

	Revelation Shaders

	Copyright (C) 2024 HaringPro
	Apache License 2.0

--------------------------------------------------------------------------------
*/

//======// Output //==============================================================================//

/* RENDERTARGETS: 2 */
out float rainAlpha;

//======// Input //===============================================================================//

in float tint;
in vec2 texCoord;

//======// Uniform //=============================================================================//

uniform sampler2D tex;

//======// Main //================================================================================//
void main() {
    float albedoAlpha = texture(tex, texCoord * vec2(4.0, 2.0)).a;

    if (albedoAlpha < 0.1) discard;

	rainAlpha = albedoAlpha * tint;
}