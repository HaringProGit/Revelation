
//================================================================================================//

float moonlightFactor = fma(abs(moonPhase - 4.0), 0.25, 0.2) * (NIGHT_BRIGHTNESS + nightVision * 0.02);

const float planetRadius = 6371e3; // The average radius of the Earth: 6,371 kilometers

const float mie_phase_g = 0.78;

// #define PLANET_GROUND

#define ATMOSPHERE_BOTTOM_ALTITUDE  1000.0 // [0.0 500.0 1000.0 2000.0 3000.0 4000.0 5000.0 6000.0 7000.0 8000.0 9000.0 10000.0 11000.0 12000.0 13000.0 14000.0 15000.0 16000.0]
#define ATMOSPHERE_TOP_ALTITUDE     110000.0 // [0.0 5000.0 10000.0 20000.0 30000.0 40000.0 50000.0 60000.0 70000.0 80000.0 90000.0 100000.0 110000.0 120000.0 130000.0 140000.0 150000.0 160000.0]

//================================================================================================//

#define TRANSMITTANCE_TEXTURE_WIDTH     256.0
#define TRANSMITTANCE_TEXTURE_HEIGHT    64.0

#define SCATTERING_TEXTURE_R_SIZE       32.0
#define SCATTERING_TEXTURE_MU_SIZE      128.0
#define SCATTERING_TEXTURE_MU_S_SIZE    32.0
#define SCATTERING_TEXTURE_NU_SIZE      8.0

#define IRRADIANCE_TEXTURE_WIDTH        64.0
#define IRRADIANCE_TEXTURE_HEIGHT       16.0

#define COMBINED_TEXTURE_WIDTH          256.0
#define COMBINED_TEXTURE_HEIGHT         128.0
#define COMBINED_TEXTURE_DEPTH          33.0

struct AtmosphereParameters {
    // The solar irradiance at the top of the atmosphere.
    vec3 solar_irradiance;
    // The sun's angular radius. Warning: the implementation uses approximations
    // that are valid only if this angle is smaller than 0.1 radians.
   float sun_angular_radius;
    // The distance between the planet center and the bottom of the atmosphere.
   float bottom_radius;
    // The distance between the planet center and the top of the atmosphere.
   float top_radius;
    // The density profile of air molecules, i.e. a function from altitude to
    // dimensionless values between 0 (null density) and 1 (maximum density).
//    DensityProfile rayleigh_density;
    // The scattering coefficient of air molecules at the altitude where their
    // density is maximum (usually the bottom of the atmosphere), as a function of
    // wavelength. The scattering coefficient at altitude h is equal to
    // 'rayleigh_scattering' times 'rayleigh_density' at this altitude.
    vec3 rayleigh_scattering;
    // The density profile of aerosols, i.e. a function from altitude to
    // dimensionless values between 0 (null density) and 1 (maximum density).
//    DensityProfile mie_density;
    // The scattering coefficient of aerosols at the altitude where their density
    // is maximum (usually the bottom of the atmosphere), as a function of
    // wavelength. The scattering coefficient at altitude h is equal to
    // 'mie_scattering' times 'mie_density' at this altitude.
    vec3 mie_scattering;
    // The extinction coefficient of aerosols at the altitude where their density
    // is maximum (usually the bottom of the atmosphere), as a function of
    // wavelength. The extinction coefficient at altitude h is equal to
    // 'mie_extinction' times 'mie_density' at this altitude.
//    vec3 mie_extinction;
    // The asymetry parameter for the Cornette-Shanks phase function for the
    // aerosols.
//    float mie_phase_function_g;
    // The density profile of air molecules that absorb light (e.g. ozone), i.e.
    // a function from altitude to dimensionless values between 0 (null density)
    // and 1 (maximum density).
//    DensityProfile absorption_density;
    // The extinction coefficient of molecules that absorb light (e.g. ozone) at
    // the altitude where their density is maximum, as a function of wavelength.
    // The extinction coefficient at altitude h is equal to
    // 'absorption_extinction' times 'absorption_density' at this altitude.
//    vec3 absorption_extinction;
    // The average albedo of the ground.
    vec3 ground_albedo;
    // The cosine of the maximum Sun zenith angle for which atmospheric scattering
    // must be precomputed (for maximum precision, use the smallest Sun zenith
    // angle yielding negligible sky light radiance values. For instance, for the
    // Earth case, 102 degrees is a good choice - yielding mu_s_min = -0.2).
   float mu_s_min;
};

const AtmosphereParameters atmosphereModel = AtmosphereParameters(
    // The solar irradiance at the top of the atmosphere.
    vec3(0.9420, 1.0269, 1.0242),
    // The sun's angular radius. Warning: the implementation uses approximations
    // that are valid only if this angle is smaller than 0.1 radians.
	0.004675,
    // The distance between the planet center and the bottom of the atmosphere.
    planetRadius - ATMOSPHERE_BOTTOM_ALTITUDE,
    // The distance between the planet center and the top of the atmosphere.
    planetRadius + ATMOSPHERE_TOP_ALTITUDE,
    // The density profile of air molecules, i.e. a function from altitude to
    // dimensionless values between 0 (null density) and 1 (maximum density).
//    DensityProfile(DensityProfileLayer[2](DensityProfileLayer(0.000000,0.000000,0.000000,0.000000,0.000000),DensityProfileLayer(0.000000,1.000000,-0.125000,0.000000,0.000000))),
    // The scattering coefficient of air molecules at the altitude where their
    // density is maximum (usually the bottom of the atmosphere), as a function of
    // wavelength. The scattering coefficient at altitude h is equal to
    // 'rayleigh_scattering' times 'rayleigh_density' at this altitude.
    vec3(0.005802, 0.013558, 0.033100),
    // The density profile of aerosols, i.e. a function from altitude to
    // dimensionless values between 0 (null density) and 1 (maximum density).
//    DensityProfile(DensityProfileLayer[2](DensityProfileLayer(0.000000,0.000000,0.000000,0.000000,0.000000),DensityProfileLayer(0.000000,1.000000,-0.833333,0.000000,0.000000))),
    // The scattering coefficient of aerosols at the altitude where their density
    // is maximum (usually the bottom of the atmosphere), as a function of
    // wavelength. The scattering coefficient at altitude h is equal to
    // 'mie_scattering' times 'mie_density' at this altitude.
    vec3(0.003996, 0.003996, 0.003996),
    // The extinction coefficient of aerosols at the altitude where their density
    // is maximum (usually the bottom of the atmosphere), as a function of
    // wavelength. The extinction coefficient at altitude h is equal to
    // 'mie_extinction' times 'mie_density' at this altitude.
//    vec3(0.004440, 0.004440, 0.004440),
    // The asymetry parameter for the Cornette-Shanks phase function for the
    // aerosols.
//    0.800000,
    // The density profile of air molecules that absorb light (e.g. ozone), i.e.
    // a function from altitude to dimensionless values between 0 (null density)
    // and 1 (maximum density).
//    DensityProfile(DensityProfileLayer[2](DensityProfileLayer(25.000000,0.000000,0.000000,0.066667,-0.666667),DensityProfileLayer(0.000000,0.000000,0.000000,-0.066667,2.666667))),
    // The extinction coefficient of molecules that absorb light (e.g. ozone) at
    // the altitude where their density is maximum, as a function of wavelength.
    // The extinction coefficient at altitude h is equal to
    // 'absorption_extinction' times 'absorption_density' at this altitude.
//    vec3(0.000650, 0.001881, 0.000085),
    // The average albedo of the ground.
    vec3(0.1),
    // The cosine of the maximum Sun zenith angle for which atmospheric scattering
    // must be precomputed (for maximum precision, use the smallest Sun zenith
    // angle yielding negligible sky light radiance values. For instance, for the
    // Earth case, 102 degrees is a good choice - yielding mu_s_min = -0.2).
   -0.2
);

const float atmosphere_bottom_radius_sq = atmosphereModel.bottom_radius * atmosphereModel.bottom_radius;
const float atmosphere_top_radius_sq    = atmosphereModel.top_radius * atmosphereModel.top_radius;

const float isotropicPhase = 0.25 * rPI;

//================================================================================================//

float RayleighPhase(in float mu) {
	const float c = 3.0 / 16.0 * rPI;
	return mu * mu * c + c;
}

// Henyey-Greenstein phase function (HG)
float HenyeyGreensteinPhase(in float mu, in float g) {
	float gg = g * g;
    return isotropicPhase * oneMinus(gg) / pow1d5(1.0 + gg - 2.0 * g * mu);
}

// Cornette-Shanks phase function (CS)
float CornetteShanksPhase(in float mu, in float g) {
	float gg = g * g;
  	float pa = oneMinus(gg) * (1.5 / (2.0 + gg));
  	float pb = (1.0 + sqr(mu)) / pow1d5((1.0 + gg - 2.0 * g * mu));

  	return isotropicPhase * pa * pb;
}

// Draine’s phase function
float DrainePhase(in float mu, in float g, in float a) {
	float gg = g * g;
	float pa = oneMinus(gg) / pow1d5(1.0 + gg - 2.0 * g * mu);
	float pb = (1.0 + a * sqr(mu)) / (1.0 + a * (1.0 + 2.0 * gg) / 3.0);
	return isotropicPhase * pa * pb;
}

// Mix between HG and Draine’s phase function (Paper: An Approximate Mie Scattering Function for Fog and Cloud Rendering)
float HG_DrainePhase(in float mu, in float d) {
	float gHG = fastExp(-0.0990567 / (d - 1.67154));
	float gD  = fastExp(-2.20679 / (d + 3.91029) - 0.428934);
	float a   = fastExp(3.62489 - 8.29288 / (d + 5.52825));
	float w   = fastExp(-0.599085 / (d - 0.641583) - 0.665888);

	return mix(HenyeyGreensteinPhase(mu, gHG), DrainePhase(mu, gD, a), w);
}

// Klein-Nishina phase function
float KleinNishinaPhase(in float mu, in float e) {
	return e / (TAU * (e * oneMinus(mu) + 1.0) * log(2.0 * e + 1.0));
}

// CS phase function for clouds
float MiePhaseClouds(in float mu, in vec3 g, in vec3 w) {
	vec3 gg = g * g;
  	vec3 pa = oneMinus(gg) * (1.5 / (2.0 + gg));
	vec3 pb = (1.0 + sqr(mu)) / pow1d5(1.0 + gg - 2.0 * g * mu);

	return isotropicPhase * dot(pa * pb, w);
}

//================================================================================================//

vec2 RaySphereIntersection(in vec3 pos, in vec3 dir, in float rad) {
	float PdotD = dot(pos, dir);
	float delta = sqr(PdotD) - dotSelf(pos) + sqr(rad);

	if (delta >= 0.0) {
		delta *= inversesqrt(delta);
		return vec2(-delta, delta) - PdotD;
	} else {
		return vec2(-1.0);
	}
}

vec2 RaySphereIntersection(in float r, in float mu, in float rad) {
	float delta = sqr(r) * (sqr(mu) - 1.0) + sqr(rad);

	if (delta >= 0.0) {
		delta *= inversesqrt(delta);
		return vec2(-delta, delta) - r * mu;
	} else {
		return vec2(-1.0);
	}
}

vec2 RaySphericalShellIntersection(in vec3 pos, in vec3 dir, in float bottomRad, in float topRad) {
    vec2 bottomIntersection = RaySphereIntersection(pos, dir, bottomRad);
    vec2 topIntersection = RaySphereIntersection(pos, dir, topRad);

    if (topIntersection.y >= 0.0) {
		vec2 intersection;
		if (bottomIntersection.y < 0.0) {
			intersection.x = max0(topIntersection.x);
			intersection.y = topIntersection.y;
		} else if (bottomIntersection.x < 0.0) {
			intersection.x = bottomIntersection.y;
			intersection.y = topIntersection.y;
		} else {
			intersection.x = max0(topIntersection.x);
			intersection.y = bottomIntersection.x;
		}

		return intersection;
	} else {
		return vec2(-1.0);
	}
}

vec2 RaySphericalShellIntersection(in float r, in float mu, in float bottomRad, in float topRad) {
    vec2 bottomIntersection = RaySphereIntersection(r, mu, bottomRad);
    vec2 topIntersection = RaySphereIntersection(r, mu, topRad);

    if (topIntersection.y >= 0.0) {
		vec2 intersection;
		if (bottomIntersection.y < 0.0) {
			intersection.x = max0(topIntersection.x);
			intersection.y = topIntersection.y;
		} else if (bottomIntersection.x < 0.0) {
			intersection.x = bottomIntersection.y;
			intersection.y = topIntersection.y;
		} else {
			intersection.x = max0(topIntersection.x);
			intersection.y = bottomIntersection.x;
		}

		return intersection;
	} else {
		return vec2(-1.0);
	}
}

//================================================================================================//

mat4x3 ToSphericalHarmonics(in vec3 value, in vec3 dir) {
	const vec2 foo = vec2(0.28209479177387815, 0.4886025119029199);
    vec4 harmonics = vec4(foo.x, foo.y * dir.yzx);

	return mat4x3(value * harmonics.x, value * harmonics.y, value * harmonics.z, value * harmonics.w);
}

vec3 FromSphericalHarmonics(in mat4x3 coeff, in vec3 dir) {
	const vec2 foo = vec2(0.28209479177387815, 0.4886025119029199);
    vec4 harmonics = vec4(foo.x, foo.y * dir.yzx);

	return coeff * harmonics;
}

//================================================================================================//

#define VIEWER_BASE_ALTITUDE 64.0 // [0.0 32.0 64.0 128.0 256.0 512.0 1024.0 2048.0 4096.0 8192.0 16384.0 32768.0 65536.0 131072.0 262144.0 524288.0 1048576.0 2097152.0 4194304.0 8388608.0 16777216.0 33554432.0 67108864.0 134217728.0 268435456.0 536870912.0 1073741824.0]

float viewerHeight = planetRadius + max(1.0, eyeAltitude + VIEWER_BASE_ALTITUDE);
float horizonCos = rcp(viewerHeight * inversesqrt(viewerHeight * viewerHeight - atmosphere_bottom_radius_sq));
float horizonAngle = fastAcos(horizonCos);

const float scale = oneMinus(4.0 / skyViewRes.x);
const float offset = 2.0 / float(skyViewRes.x);

const vec2 cScale = vec2(skyViewRes.x / (skyViewRes.x + 1.0), 0.5);

// Reference: https://sebh.github.io/publications/egsr2020.pdf
vec3 ToSkyViewLutParams(in vec2 coord) {
	coord *= rcp(cScale);

	// From unit range
	coord.x = fract((coord.x - offset) * rcp(scale));

	// Non-linear mapping of the altitude angle
	coord.y = coord.y < 0.5 ? -sqr(1.0 - 2.0 * coord.y) : sqr(2.0 * coord.y - 1.0);

	float azimuthAngle = coord.x * TAU - PI;
	float altitudeAngle = (coord.y + 1.0) * hPI - horizonAngle;

	float altitudeCos = cos(altitudeAngle);

	return vec3(altitudeCos * sin(azimuthAngle), sin(altitudeAngle), -altitudeCos * cos(azimuthAngle));
}

vec2 FromSkyViewLutParams(in vec3 direction) {
	vec2 coord = normalize(direction.xz);

	float azimuthAngle = atan(coord.x, -coord.y);
	float altitudeAngle = horizonAngle - fastAcos(direction.y);

	coord.x = (azimuthAngle + PI) * rTAU;

	// Non-linear mapping of the altitude angle
	coord.y = 0.5 + 0.5 * fastSign(altitudeAngle) * sqrt(2.0 * rPI * abs(altitudeAngle));

	// To unit range
	coord.x = coord.x * scale + offset;

	return saturate(coord * cScale);
}
