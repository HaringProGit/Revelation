#version 450 compatibility

/*
--------------------------------------------------------------------------------

	Revelation Shaders

	Copyright (C) 2024 HaringPro
	Apache License 2.0

	Pass: Deferred lighting and sky rendering
		  Compute specular reflections

--------------------------------------------------------------------------------
*/

#define CLOUD_LIGHTING
#define SPECULAR_LIGHTING
#define RANDOM_NOISE

//======// Utility //=============================================================================//

#include "/lib/Utility.glsl"

//======// Output //==============================================================================//

/* RENDERTARGETS: 0 */
layout (location = 0) out vec3 sceneOut;

#if defined SPECULAR_MAPPING && defined MC_SPECULAR_MAP
/* RENDERTARGETS: 0,2 */
layout (location = 1) out vec4 reflectionOut;
#endif

//======// Input //===============================================================================//

in vec2 screenCoord;

flat in vec3 directIlluminance;
flat in vec3 skyIlluminance;

flat in mat4x3 skySH;

flat in vec3 blocklightColor;

//======// Uniform //=============================================================================//

uniform sampler2D noisetex;

uniform sampler2D colortex2; // Current indirect light

uniform sampler3D colortex3; // Combined Atmospheric LUT

#if defined SPECULAR_MAPPING && defined MC_SPECULAR_MAP
	uniform sampler2D colortex4; // Reprojected scene history
#endif

uniform sampler2D colortex5; // Sky-View LUT

uniform sampler2D colortex6; // Albedo
uniform sampler2D colortex7; // Gbuffer data 0
uniform sampler2D colortex8; // Gbuffer data 1

uniform sampler2D colortex10; // Transmittance-View LUT

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int heldItemId;
uniform int heldBlockLightValue;
uniform int heldItemId2;
uniform int heldBlockLightValue2;
uniform int moonPhase;

uniform float frameTimeCounter;
uniform float nightVision;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float wetness;
uniform float wetnessCustom;
uniform float eyeAltitude;
uniform float biomeSnowySmooth;
uniform float eyeSkylightFix;
uniform float worldTimeCounter;

uniform vec2 viewPixelSize;
uniform vec2 viewSize;
uniform vec2 taaOffset;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 worldSunVector;
uniform vec3 worldLightVector;
uniform vec3 lightningShading;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferModelView;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;

//======// Struct //==============================================================================//

#include "/lib/utility/Material.glsl"

//======// Function //============================================================================//

#include "/lib/utility/Transform.glsl"
#include "/lib/utility/Fetch.glsl"
#include "/lib/utility/Noise.glsl"

#include "/lib/atmospherics/Global.glsl"
#include "/lib/atmospherics/PrecomputedAtmosphericScattering.glsl"

#include "/lib/atmospherics/Celestial.glsl"
#include "/lib/atmospherics/Clouds.glsl"

#include "/lib/lighting/Shadows.glsl"
#include "/lib/lighting/DiffuseLighting.glsl"

#if AO_ENABLED > 0
	#include "/lib/lighting/AmbientOcclusion.glsl"
#endif

#include "/lib/utility/Offset.glsl"

#if defined SPECULAR_MAPPING && defined MC_SPECULAR_MAP
	#include "/lib/surface/ScreenSpaceRaytracer.glsl"

	vec4 CalculateSpecularReflections(Material material, in vec3 viewNormal, in vec3 screenPos, in vec3 viewPos, in float skylight, in float dither) {
		skylight = smoothstep(0.3, 0.8, skylight);
		vec3 viewDir = normalize(viewPos);

		vec3 rayDir;
		float LdotH;
		#ifdef ROUGH_REFLECTIONS
			if (material.isRough) {
				mat3 tbnMatrix;
				tbnMatrix[0] = normalize(cross(gbufferModelView[1].xyz, viewNormal));
				tbnMatrix[1] = cross(viewNormal, tbnMatrix[0]);
				tbnMatrix[2] = viewNormal;

				vec3 tangentViewDir = -viewDir * tbnMatrix;
				vec3 facetNormal = tbnMatrix * sampleGGXVNDF(tangentViewDir, material.roughness, RandNext2F());
				LdotH = dot(facetNormal, -viewDir);
				rayDir = viewDir + facetNormal * LdotH * 2.0;
			} else
		#endif
		{
			LdotH = dot(viewNormal, -viewDir);
			rayDir = viewDir + viewNormal * LdotH * 2.0;
		}

		float NdotL = dot(viewNormal, rayDir);
		if (NdotL < 1e-6) return vec4(0.0);

		bool hit = ScreenSpaceRaytrace(viewPos, rayDir, dither, uint(RAYTRACE_SAMPLES * oneMinus(material.roughness)), screenPos);

		vec3 reflection;
		if (hit) {
			// reflection = textureLod(colortex4, screenPos.xy * viewPixelSize * 0.5, 8.0 * fastSqrt(material.roughness)).rgb;
			reflection = texelFetch(colortex4, ivec2(screenPos.xy * 0.5), 0).rgb;
		} else if (skylight > 1e-3) {
			vec3 rayDirWorld = mat3(gbufferModelViewInverse) * rayDir;
			vec3 skyRadiance = textureBicubic(colortex5, FromSkyViewLutParams(rayDirWorld) + vec2(0.0, 0.5)).rgb;

			reflection = skyRadiance * skylight;
		}

		// if (any(isnan(reflection))) reflection = vec3(0.0);

		float targetDepth = 0.0;
		vec3 brdf = vec3(1.0);

		float NdotV = maxEps(dot(viewNormal, -viewDir));
		if (material.isRough) {
			float alpha2 = material.roughness * material.roughness;
			float G2 = G2SmithGGX(NdotV, NdotL, alpha2);
			float G1Inverse = G1SmithGGXInverse(NdotV, alpha2);

			brdf *= G2 * G1Inverse;
			vec3 reflectViewPos = ScreenToViewSpace(vec3(screenPos.xy * viewPixelSize, sampleDepth(ivec2(screenPos.xy))));
			targetDepth = saturate(distance(reflectViewPos, viewPos) * rcp(far));
		}

		// #if defined SPECULAR_MAPPING && defined MC_SPECULAR_MAP
			if (material.isHardcodedMetal) {
				brdf = FresnelConductor(LdotH, material.hardcodedMetalCoeff[0], material.hardcodedMetalCoeff[1]);
			} else if (material.metalness > 0.5) {
				brdf *= FresnelSchlick(LdotH, material.f0);
			} else
		// #endif
		{ brdf *= FresnelDielectric(LdotH, material.f0); }

		return vec4(clamp16f(reflection) * brdf, targetDepth);
	}
#endif

//======// Main //================================================================================//
void main() {
	ivec2 screenTexel = ivec2(gl_FragCoord.xy);

	float depth = sampleDepth(screenTexel);

	vec3 screenPos = vec3(screenCoord, depth);
	vec3 viewPos = ScreenToViewSpace(screenPos);

	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos;
	vec3 worldDir = normalize(worldPos);
	vec4 gbufferData0 = sampleGbufferData0(screenTexel);

	uint materialID = uint(gbufferData0.y * 255.0);

	vec3 albedoRaw = sampleAlbedo(screenTexel);
	vec3 albedo = sRGBtoLinear(albedoRaw);

	if (depth > 0.999999 + materialID) {
		vec2 skyViewCoord = FromSkyViewLutParams(worldDir);
		vec3 skyRadiance = textureBicubic(colortex5, skyViewCoord).rgb;

		vec3 moonDisc = mix(albedo, GetLuminance(albedo) * vec3(0.7, 1.1, 1.5), 0.5) * 0.1;
		vec3 celestial = mix(RenderStars(worldDir), moonDisc, bvec3(albedo.g > 0.06)) // Use bvec3 to avoid errors with some drivers
		 + RenderSun(worldDir, worldSunVector);

		vec3 transmittance = texture(colortex10, skyViewCoord).rgb;
		sceneOut = skyRadiance + transmittance * celestial;

		#ifdef CLOUDS_ENABLED
			float dither = Bayer64Temporal(gl_FragCoord.xy);
			vec4 cloudData = RenderClouds(worldDir, skyRadiance, dither);

			sceneOut = sceneOut * cloudData.a + cloudData.rgb;
		#endif
	} else {
		sceneOut = vec3(0.0);
		worldPos += gbufferModelViewInverse[3].xyz;

		vec2 lightmap = unpackUnorm2x8(gbufferData0.x);
		lightmap.y = isEyeInWater == 1 ? 1.0 : cube(lightmap.y);
		vec3 flatNormal = FetchFlatNormal(gbufferData0);
		#ifdef NORMAL_MAPPING
			vec3 worldNormal = FetchWorldNormal(gbufferData0);
		#else
			vec3 worldNormal = flatNormal;
		#endif
		vec3 viewNormal = mat3(gbufferModelView) * worldNormal;

		#ifdef SPECULAR_MAPPING
			vec4 gbufferData1 = sampleGbufferData1(screenTexel);
			vec4 specularTex = vec4(unpackUnorm2x8(gbufferData1.x), unpackUnorm2x8(gbufferData1.y));
			Material material = GetMaterialData(specularTex);
		#else
			Material material = Material(materialID == 46u || materialID == 51u ? 0.005 : 1.0, 0.0, 0.04, 0.0, false, false);
		#endif

		float LdotV = dot(worldLightVector, -worldDir);
		float NdotL = dot(worldNormal, worldLightVector);

		float sssAmount = 0.0;
		bool sssPlant = false;
		#if SUBSERFACE_SCATTERING_MODE < 2
			// Hard-coded sss amount for certain materials
			switch (materialID) {
				case 9u: case 10u: case 11u: case 13u: case 28u: // Plants
					sssPlant = true;
					break;
				case 12u: // Leaves
					sssAmount = 0.85;
					break;
				case 27u: case 37u: // Weak SSS
					sssAmount = 0.5;
					break;
				case 38u: case 51u: // Strong SSS
					sssAmount = 0.8;
					break;
				case 40u: // Particles
					sssAmount = 0.35;
					break;
			}
		#endif
		#if TEXTURE_FORMAT == 0 && SUBSERFACE_SCATTERING_MODE > 0 && defined SPECULAR_MAPPING
			sssAmount = max(sssAmount, specularTex.b * step(64.5 / 255.0, specularTex.b));
		#endif

		// Remap sss amount to [0, 1] range
		sssAmount = remap(64.0 * r255, 1.0, sssAmount) * eyeSkylightFix * SUBSERFACE_SCATTERING_STRENTGH;

		float dither = BlueNoiseTemporal(screenTexel);

		// Ambient occlusion
		float ao = 1.0;
		if (depth > 0.56) {
			#if AO_ENABLED > 0
				#if AO_ENABLED == 1
					ao = CalculateSSAO(screenCoord, viewPos, viewNormal, dither);
				#else
					ao = CalculateGTAO(screenCoord, viewPos, viewNormal, dither);
				#endif
			#endif
		} else depth += 0.38;

		// Cloud shadows
		#ifdef CLOUD_SHADOWS
			float cloudShadow = CalculateCloudShadows(worldPos + cameraPosition);
		#else
			float cloudShadow = 1.0 - wetness * 0.96;
		#endif

		// Sunlight
		vec3 sunlightMult = 30.0 * cloudShadow * directIlluminance;

		vec3 sunlightDiffuse = vec3(0.0);
		vec3 specularHighlight = vec3(0.0);

		float distanceFade = sqr(pow16(rcp(shadowDistance * shadowDistance) * dotSelf(worldPos)));

        if (distanceFade < 1e-6 && max(NdotL, sssAmount) > 1e-3) {
			float distortFactor;
			vec3 normalOffset = flatNormal * (dotSelf(worldPos) * 1e-4 + 3e-2) * (2.0 - saturate(NdotL));
			vec3 shadowScreenPos = WorldToShadowScreenSpace(worldPos + normalOffset, distortFactor);	

			vec2 blockerSearch = BlockerSearch(shadowScreenPos, dither);

			// Subsurface scattering
			if (sssAmount > 1e-3) {
				vec3 subsurfaceScattering = CalculateSubsurfaceScattering(albedo, sssAmount, blockerSearch.y, LdotV);
				// subsurfaceScattering *= eyeSkylightFix;
				sceneOut += subsurfaceScattering * sunlightMult * ao;
			}

			// Shadows
			if (NdotL > 1e-3) {
				float penumbraScale = max(blockerSearch.x / distortFactor, 2.0 / realShadowMapRes);
				vec3 shadow = PercentageCloserFilter(shadowScreenPos, dither, penumbraScale) * saturate(lightmap.y * 1e8);

				if (maxOf(shadow) > 1e-6) {
					shadow *= sunlightMult;
					#ifdef SCREEN_SPACE_SHADOWS
						shadow *= ScreenSpaceShadow(viewPos, screenPos, viewNormal, dither, sssAmount);
					#endif
					// shadow = shadow * oneMinus(distanceFade) + distanceFade;

					// Apply parallax shadows
					#if defined PARALLAX && defined PARALLAX_SHADOW && !defined PARALLAX_DEPTH_WRITE
						#if !defined SPECULAR_MAPPING
							vec4 gbufferData1 = sampleGbufferData1(screenTexel);
						#endif
						shadow *= oneMinus(gbufferData1.z);
					#endif

					float halfwayNorm = inversesqrt(2.0 * LdotV + 2.0);
					float NdotV = saturate(dot(worldNormal, -worldDir));
					float NdotH = maxEps((NdotL + NdotV) * halfwayNorm);
					float LdotH = LdotV * halfwayNorm + halfwayNorm;
					NdotV = max(NdotV, 1e-3);

					sunlightDiffuse = shadow * mix(DiffuseHammon(LdotV, NdotV, NdotL, NdotH, material.roughness, albedo), vec3(rPI), sssAmount * 0.75);
					specularHighlight = shadow * SpecularBRDF(LdotH, NdotV, NdotL, NdotH, sqr(material.roughness), material.f0);
					specularHighlight *= SPECULAR_HIGHLIGHT_BRIGHTNESS * oneMinus(material.metalness * oneMinus(albedo));
				}
			}
		} else if (NdotL > 1e-3) {
			vec3 shadow = sunlightMult;
			#ifdef SCREEN_SPACE_SHADOWS
				shadow *= ScreenSpaceShadow(viewPos, screenPos, viewNormal, dither, sssAmount);
			#endif

			// Apply parallax shadows
			#if defined PARALLAX && defined PARALLAX_SHADOW && !defined PARALLAX_DEPTH_WRITE
				#if !defined SPECULAR_MAPPING
					vec4 gbufferData1 = sampleGbufferData1(screenTexel);
				#endif
				shadow *= oneMinus(gbufferData1.z);
			#endif

			float halfwayNorm = inversesqrt(2.0 * LdotV + 2.0);
			float NdotV = saturate(dot(worldNormal, -worldDir));
			float NdotH = maxEps((NdotL + NdotV) * halfwayNorm);
			float LdotH = LdotV * halfwayNorm + halfwayNorm;
			NdotV = max(NdotV, 1e-3);

			sunlightDiffuse = shadow * mix(DiffuseHammon(LdotV, NdotV, NdotL, NdotH, material.roughness, albedo), vec3(rPI), sssAmount * 0.75);
			specularHighlight = shadow * SpecularBRDF(LdotH, NdotV, NdotL, NdotH, sqr(material.roughness), material.f0);
			specularHighlight *= SPECULAR_HIGHLIGHT_BRIGHTNESS * oneMinus(material.metalness * oneMinus(albedo));
		} else if (sssPlant) {
			float distortFactor;
			vec3 normalOffset = flatNormal * (dotSelf(worldPos) * 1e-4 + 3e-2) * (2.0 - saturate(worldLightVector.y));
			vec3 shadowScreenPos = WorldToShadowScreenSpace(worldPos + normalOffset, distortFactor);	

			vec2 blockerSearch = BlockerSearch(shadowScreenPos, dither);

			if (blockerSearch.y > -4.0) {
				// Screen-space subsurface scattering for plants
				float subsurfaceScattering = SUBSERFACE_SCATTERING_BRIGHTNESS * 0.1;
				subsurfaceScattering *= eyeSkylightFix * ScreenSpaceShadow(viewPos, screenPos, viewNormal, dither, 0.6);
				sceneOut += subsurfaceScattering * sunlightMult * ao;
			}
		}

		// Sunlight diffuse
		sceneOut += sunlightDiffuse;

		// Skylight and bounced light
		#ifndef SSPT_ENABLED
			if (lightmap.y > 1e-5) {
				// Skylight
				vec3 skylight = FromSphericalHarmonics(skySH, worldNormal);
				skylight = mix(skylight, directIlluminance * 0.1, wetness * 0.5) + lightningShading * 1e-3;
				skylight *= worldNormal.y * 2.0 + 3.0;

				sceneOut += skylight * lightmap.y * ao;

				// Bounced light
				float bounce = CalculateFittedBouncedLight(worldNormal);
				bounce *= sqr(lightmap.y);
				sceneOut += bounce * sunlightMult * ao;
			}
		#endif

		// Emissive & Blocklight
		#if EMISSIVE_MODE < 2
			// Hard-coded emissive
			vec4 emissive = HardCodeEmissive(materialID, albedo, albedoRaw, worldPos, blocklightColor);
			#ifdef SSPT_ENABLED
				float albedoLuma = saturate(dot(albedo, vec3(0.45)));

				vec3 emissionAlbedo = normalize(maxEps(albedo));
				emissionAlbedo *= mix(inversesqrt(emissionAlbedo), vec3(1.0), fastSqrt(albedoLuma));
				emissive.rgb *= emissionAlbedo * 1.5;
			#else
				if (emissive.a * lightmap.x > 1e-5) {
					lightmap.x = CalculateBlocklightFalloff(lightmap.x);
					sceneOut += lightmap.x * (ao * oneMinus(lightmap.x) + lightmap.x) * blocklightColor * emissive.a;
				}
			#endif

			sceneOut += emissive.rgb * EMISSIVE_BRIGHTNESS;
		#elif !defined SSPT_ENABLED
			if (lightmap.x > 1e-5) {
				lightmap.x = CalculateBlocklightFalloff(lightmap.x);
				sceneOut += lightmap.x * (ao * oneMinus(lightmap.x) + lightmap.x) * blocklightColor;
			}
		#endif

		#if EMISSIVE_MODE > 0 && defined SPECULAR_MAPPING
			sceneOut += material.emissiveness * dot(albedo, vec3(0.75));
		#endif

		// Handheld light
		#ifdef HANDHELD_LIGHTING
			if (heldBlockLightValue + heldBlockLightValue2 > 1e-4) {
				float falloff = rcp(max(dotSelf(worldPos), 1.0));
				sceneOut += falloff * (ao * oneMinus(falloff) + falloff) * max(heldBlockLightValue, heldBlockLightValue2) * HELD_LIGHT_BRIGHTNESS * blocklightColor;
			}
		#endif

		// Minimal ambient light
		sceneOut += vec3(0.77, 0.82, 1.0) * MINIMUM_AMBIENT_BRIGHTNESS * ao * (worldNormal.y * 0.4 + 0.6);

		// Apply albedo
		sceneOut *= albedo;

		#if defined SPECULAR_MAPPING && defined MC_SPECULAR_MAP
			// Metallic
			if (isEyeInWater == 0) material.metalness *= 0.2 * smoothstep(0.3, 0.8, lightmap.y) + 0.8;
			sceneOut *= oneMinus(material.metalness);

			// Specular reflections
			if (material.hasReflections && materialID != 46u && materialID != 51u) reflectionOut = CalculateSpecularReflections(material, viewNormal, screenPos, viewPos, lightmap.y, dither);
		#endif

		// Specular highlights
		sceneOut += specularHighlight;
	}
}