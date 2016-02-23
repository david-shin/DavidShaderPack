Shader "David/StylizedPBR"
{
	Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Ramp ("Ramp (RGB)", 2D) = "white" {}
        _RampScale ("ShadePower", Range(0,1)) = 0.5
        _RimPower ("RimPower", Range(0,2)) = 0.5

    	_Glossiness ("Smoothness", Range(0,1)) = 0.5
    	[Gamma] _Metallic ("Metallic", Range(0,1)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        // paramas below this will be removed
        // Standard shader gui bitches at me for lacking of those
        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DetailMask("Detail Mask", 2D) = "white" {}

        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        _DetailNormalMap("Normal Map", 2D) = "bump" {}
        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0

        // Blending state
        _ShadingMode ("__shadingmode", Float) = 0.0
        _Mode ("__mode", Float) = 0.0
        _Cull ("__cull", Float) = 0.0
        _SrcBlend ("__src", Float) = 1.0
        _DstBlend ("__dst", Float) = 0.0
        _ZWrite ("__zw", Float) = 1.0
    }

    CGINCLUDE
    	#define UNITY_SETUP_BRDF_INPUT MetallicSetup
    ENDCG

    SubShader
	{
		Tags { "RenderType"="Opaque" "PerformanceChecks"="True" }
		LOD 150

		// ------------------------------------------------------------------
		//  Base forward pass (directional light, emission, lightmaps, ...)
		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]
            Cull [_Cull]

			CGPROGRAM
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Includes/DavidStylizedCore.cginc"

        	#pragma target 3.0
            #pragma exclude_renderers gles

            #pragma shader_feature _RAMPMAP
            #pragma shader_feature _NORMALMAP
			#pragma shader_feature _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature _EMISSION
			#pragma shader_feature _METALLICGLOSSMAP
			#pragma shader_feature ___ _DETAIL_MULX2
			#pragma shader_feature _PARALLAXMAP

			#pragma skip_variants SHADOWS_SOFT DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

			#pragma vertex vertBase
			#pragma fragment fragBase


	       ENDCG
		}
		// ------------------------------------------------------------------
		//  Shadow rendering pass
		Pass {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual

			CGPROGRAM
            #pragma target 3.0
			#pragma exclude_renderers gles

			#pragma shader_feature _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma skip_variants SHADOWS_SOFT
			#pragma multi_compile_shadowcaster

			#pragma vertex vertShadowCaster
			#pragma fragment fragShadowCaster

			#include "UnityStandardShadow.cginc"

			ENDCG
		}
    }
    FallBack "VertexLit"
    CustomEditor "DavidStylizedPBRUI"
}
