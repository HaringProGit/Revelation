
//======// Output //==============================================================================//

/* RENDERTARGETS: 0 */
out vec4 albedoOut;

//======// Input //===============================================================================//

in vec4 tint;
in vec2 texCoord;

//======// Uniform //=============================================================================//

uniform sampler2D tex;

//======// Main //================================================================================//
void main() {
	albedoOut = texture(tex, texCoord) * tint;
}
