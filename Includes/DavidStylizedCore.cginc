#include "UnityPBSLighting.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityGlobalIllumination.cginc"

//-------------------------------------------------------------------------------------
sampler2D _RampTex;
half _SmoothnessScale;
//-------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------
struct SurfaceOutputStylizedPBS
{
    fixed3 Albedo;      // base (diffuse or specular) color
    fixed3 Normal;      // tangent space normal, if written
    half3 Emission;
    half Metallic;      // 0=non-metal, 1=metal
    half Smoothness;    // 0=rough, 1=smooth
    half Occlusion;     // occlusion (default 1)
    fixed Alpha;        // alpha for transparencies
    half SkinMask;
};
//-------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------
inline half4 PBS_Stylized (half3 diffColor, half3 specColor, half oneMinusReflectivity, half oneMinusRoughness, half3 normal, half3 viewDir, UnityLight light, UnityIndirect gi)
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
    grazingTerm += _SmoothnessScale;

    half hl = nl * 0.5 + 0.5;
    half3 ramp = tex2D(_RampTex, half2(hl, nv)).rgb;

    // BRDF3_Direct and BRDF3_Indirect are for reflections,
    half3 color = BRDF3_Direct(diffColor, specColor, rlPow4, oneMinusRoughness);
    color *= light.color * hl;
    color += BRDF3_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);

    return half4(color, 1);
}

inline half3 PBS_Stylized_Indirect (half3 baseColor, half3 specColor, half oneMinusReflectivity, half oneMinusRoughness, half3 normal, half3 viewDir, half occlusion, UnityGI gi)
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
//-------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------
inline half4 LightingStylizedPBS (SurfaceOutputStylizedPBS s, half3 viewDir, UnityGI gi)
{
    s.Normal = normalize(s.Normal);

    half oneMinusReflectivity;
    half3 specColor;
    s.Albedo = DiffuseAndSpecularFromMetallic (s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

    // shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    // this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
    half outputAlpha;
    s.Albedo = PreMultiplyAlpha (s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

    half4 c = PBS_Stylized (s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
    c.rgb += PBS_Stylized_Indirect (s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, s.Occlusion, gi);
    c.a = outputAlpha;
    return c;
}

void LightingStylizedPBS_GI (
    SurfaceOutputStylizedPBS s,
    UnityGIInput data,
    inout UnityGI gi)
{
    UNITY_GI(gi, s, data);
}
//-------------------------------------------------------------------------------------
