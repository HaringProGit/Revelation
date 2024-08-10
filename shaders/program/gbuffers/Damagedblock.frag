
//======// Output //==============================================================================//

/* RENDERTARGETS: 6 */
out vec3 albedoOut;

//======// Input //===============================================================================//

in vec2 texCoord;

//======// Uniform //=============================================================================//

uniform sampler2D tex;

//======// Main //================================================================================//
void main() {	
	vec4 albedo = texture(tex, texCoord);

    if (albedo.a < 0.1) discard;

	albedoOut = albedo.rgb;
}