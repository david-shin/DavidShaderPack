//TODO: Clean this up
//TODO: Make skin masking
#include "UnityCG.cginc"
#include "UnityStandardCore.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityStandardInput.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityStandardBRDF.cginc"
#include "AutoLight.cginc"

// Additional variables
sampler2D   _Ramp;
float       _RampScale;
float       _RimPower;

// ------------------------------------------------------------------
// Grabbing GI part
#include "UnityGlobalIllumination.cginc"
inline half3 DAVID_BRDF_INDIRECT (half3 baseColor, half3 specColor, half oneMinusReflectivity, half oneMinusRoughness, half3 normal, half3 viewDir, half occlusion, UnityGI gi)
{
	half3 c = 0;
	#if defined(DIRLIGHTMAP_SEPARATE)
		gi.indirect.diffuse = 0;
		gi.indirect.specular = 0;

		#ifdef LIGHTMAP_ON
			c += UNITY_BRDF_PBS_LIGHTMAP_INDIRECT (baseColor, specColor, oneMinusReflectivity, oneMinusRoughness, normal, viewDir, gi.light2, gi.indirect).rgb * occlusion;
		#endif
		#ifdef DYNAMICLIGHTMAP_ON
			c += UNITY_BRDF_PBS_LIGHTMAP_INDIRECT (baseColor, specColor, oneMinusReflectivity, oneMinusRoughness, normal, viewDir, gi.light3, gi.indirect).rgb * occlusion;
		#endif
	#endif
	return c;
}

// ------------------------------------------------------------------
// BRDF3 Model for Mobile devices
// Uses half lambert and gives you bit better control on fresnel power

half3 DAVID_BRDF3_Direct(half3 diffColor, half3 specColor, half rlPow4, half oneMinusRoughness)
{
	half LUT_RANGE = 16.0; // must match range in NHxRoughness() function in GeneratedTextures.cpp
	// Lookup texture to save instructions
	half specular = tex2D(unity_NHxRoughness, half2(rlPow4, 1-oneMinusRoughness)).UNITY_ATTEN_CHANNEL * LUT_RANGE;
	return diffColor + specular * specColor;
}


half3 DAVID_BRDF3_INDIRECT(half3 diffColor, half3 specColor, UnityIndirect indirect, half grazingTerm, half fresnelTerm)
{
	half3 c = indirect.diffuse * diffColor;
	c += indirect.specular * lerp (specColor, grazingTerm, fresnelTerm);
	return c;
}

half4 DAVID_BRDF3_STYLIZED (half3 diffColor, half3 specColor, half oneMinusReflectivity, half oneMinusRoughness, half3 normal, half3 viewDir, UnityLight light, UnityIndirect gi)
{
    half3 reflDir = reflect (viewDir, normal);

    half nl = dot(normal, light.dir);
    half nv = DotClamped (normal, viewDir);

    // Vectorize Pow4 to save instructions
    // use R.L instead of N.H to save couple of instructions
    half2 rlPow4AndFresnelTerm = Pow4 (half2(dot(reflDir, light.dir), 1-nv));
    // power exponent must match kHorizontalWarpExp in NHxRoughness() function in GeneratedTextures.cpp
    half rlPow4 = rlPow4AndFresnelTerm.x;
    half fresnelTerm = pow(rlPow4AndFresnelTerm.y, 1);
    half grazingTerm = saturate(oneMinusRoughness + (1-oneMinusReflectivity));
    // Forcing to add more rimlights.

    // The mighty ramp shading with half lambert.
    grazingTerm += _RimPower;
    half hl = nl * 0.5 + 0.5;
    half3 ramp = tex2D(_Ramp, half2(hl, nv * _RampScale)).rgb;

    // BRDF3_Direct and BRDF3_Indirect are for reflections,
    // do not affect anything we need.
    half3 color = DAVID_BRDF3_Direct(diffColor, specColor, rlPow4, oneMinusRoughness);
    color *= light.color * ramp;
    color += DAVID_BRDF3_INDIRECT(diffColor, specColor, gi, grazingTerm, fresnelTerm);

    return half4(color, 1);
}

half4 fragForwardComposition (VertexOutputForwardBase i)
{
	FRAGMENT_SETUP(s)
#if UNITY_OPTIMIZE_TEXCUBELOD
	s.reflUVW		= i.reflUVW;
#endif

	UnityLight mainLight = MainLight (s.normalWorld);
	half atten = SHADOW_ATTENUATION(i);

	half occlusion = Occlusion(i.tex.xy);
	UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);

	half4 c = DAVID_BRDF3_STYLIZED (s.diffColor, s.specColor, s.oneMinusReflectivity, s.oneMinusRoughness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
	c.rgb += DAVID_BRDF_INDIRECT (s.diffColor, s.specColor, s.oneMinusReflectivity, s.oneMinusRoughness, s.normalWorld, -s.eyeVec, occlusion, gi);
	c.rgb += Emission(i.tex.xy);

	UNITY_APPLY_FOG(i.fogCoord, c.rgb);
	return OutputForward (c, s.alpha);
}

// Let unity handle the vertex part as long as we don't need to touch anything.
VertexOutputForwardBase vertBase (VertexInput v) { return vertForwardBase(v); }
half4 fragBase (VertexOutputForwardBase i) : SV_Target { return fragForwardComposition(i); }
