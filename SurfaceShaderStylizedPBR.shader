Shader "David/StylizedPBR"
{
	Properties
    {
        _RampTex ("BRDF Lookup (RGB)", 2D) = "white" {}

        _Color ("Color", Color) = (1, 1, 1, 1)
        _MainTex ("Albedo, Metallic", 2D) = "white" {}

		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _NormalTex ("Normal", 2D) = "bump"{}
		_NormalScale("Scale", Range(0, 2)) = 1

        _MaterialMaskTex("Metallic", 2D) = "white" {}

		[Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _Smoothness ("Smoothness Scale", Range(0, 2)) = 0
        _SmoothnessScale ("Smoothness Scale", Range(0, 2)) = 0

		_EmissionMap("Emission", 2D) = "white" {}

        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0
        [HideInInspector] _Cull ("__cull", Float) = 2.0
    }

    SubShader
	{
		Tags { "RenderType"="Opaque" "PerformanceChecks"="True" }
		LOD 150

        Blend [_SrcBlend] [_DstBlend]
        ZWrite [_ZWrite]
        Cull [_Cull]

        CGPROGRAM
        #include "UnityCG.cginc"
        #include "AutoLight.cginc"
        #pragma surface surf StylizedPBS

        #pragma target 3.0
        #pragma exclude_renderers gles

        #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
        #pragma shader_feature _MASKMAP
        #pragma shader_feature _NORMALMAP
        #pragma shader_feature _EMISSIONMAP

        //#pragma skip_variants SHADOWS_SOFT DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE

        // Variables
        half4 _Color;
        sampler2D _MainTex;
        sampler2D _NormalTex;
        sampler2D _MaterialMaskTex;
        sampler2D _EmissionMap;
        sampler2D _RampTex;
        half _SmoothnessScale;
        half _Cutoff;
        half _NormalScale;
        half _Metallic;
        half _Smoothness;

        struct Input
        {
            float2 uv_MainTex;
        };

        #include "UnityPBSLighting.cginc"
        #include "UnityLightingCommon.cginc"
        #include "UnityGlobalIllumination.cginc"
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
        half4 PBS_Stylized (half3 diffColor, half3 specColor, half oneMinusReflectivity, half oneMinusRoughness, half3 normal, half3 viewDir, UnityLight light, UnityIndirect gi, half skinMask)
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
            half3 ramp = tex2D(_RampTex, half2(hl, 1)).rgb;

            half3 color = BRDF3_Direct(diffColor, specColor, rlPow4, oneMinusRoughness);
            color *= ramp * light.color;
            color += BRDF3_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);

            return half4(color,1);
        }

        half3 PBS_Stylized_Indirect (half3 baseColor, half3 specColor, half oneMinusReflectivity, half oneMinusRoughness, half3 normal, half3 viewDir, half occlusion, UnityGI gi)
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
        half4 LightingStylizedPBS (SurfaceOutputStylizedPBS s, half3 viewDir, UnityGI gi)
        {
            s.Normal = normalize(s.Normal);

            half oneMinusReflectivity;
            half3 specColor;
            s.Albedo = DiffuseAndSpecularFromMetallic (s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

            // shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
            // this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
            half outputAlpha;
            s.Albedo = PreMultiplyAlpha (s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

            half4 c = PBS_Stylized (s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect, s.SkinMask);
            c.rgb += PBS_Stylized_Indirect (s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, s.Occlusion, gi);
            c.a = outputAlpha;
            return c;
        }

        void LightingStylizedPBS_GI (
            SurfaceOutputStylizedPBS s,
            UnityGIInput data,
            inout UnityGI gi)
        {
            gi = UnityGlobalIllumination (data, s.Occlusion, s.Smoothness, s.Normal, true); // reflections = true
            //UNITY_GI(gi, s, data);
        }
        //-------------------------------------------------------------------------------------

        void surf(Input IN, inout SurfaceOutputStylizedPBS o)
        {
            fixed4 color = tex2D(_MainTex, IN.uv_MainTex);

            #if _NORMALMAP
                fixed4 normal = tex2D(_NormalTex, IN.uv_MainTex);
                o.Normal = UnpackScaleNormal(normal, _NormalScale);
            #endif

            #if _MASKMAP
                fixed4 mask = tex2D(_MaterialMaskTex, IN.uv_MainTex);
                o.Metallic = mask.r;
                o.Smoothness = mask.g;
                o.SkinMask = mask.b;
                o.Albedo = lerp(color.rgb, color.rgb * _Color.rgb, o.SkinMask);
            #else
                o.Albedo = color.rgb * _Color.rgb;
                o.Metallic = _Metallic;
                o.Smoothness = _Smoothness;
                o.SkinMask = 0;
            #endif

            #if _EMISSIONMAP
                o.Emission = tex2D(_EmissionMap, IN.uv_MainTex).rgb;
            #endif

            o.Alpha = color.a * _Color.a;
        }
        ENDCG
    }
    FallBack "Standard"
    CustomEditor "DavidStylizedPBRUI"
}
