Shader "David/StylizedPBS Sample"
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
        _Smoothness ("Smoothness Scale", Range(0, 2)) = 1
        _SmoothnessScale ("Smoothness Scale", Range(0, 2)) = 1

		_EmissionMap("Emission", 2D) = "white" {}

        //-------------------------------------------------------------------------------------
		[HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0
        [HideInInspector] _ZTest ("__zt", Float) = 4.0
        [HideInInspector] _Cull ("__cull", Float) = 0.0
    }

    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 150

        Blend [_SrcBlend] [_DstBlend]
        ZWrite [_ZWrite]
        ZTest [_ZTest]
        Cull [_Cull]

        CGPROGRAM
        #include "Includes/DavidStylizedCore.cginc"
        #pragma surface surf StylizedPBS fullforwardshadows
        #pragma target 3.0

        #pragma shader_feature _BRDF_LOOKUP
        #pragma shader_feature _MASKMAP
        #pragma shader_feature _NORMALMAP
        #pragma shader_feature _EMISSION

        // Variables
        half4 _Color;
        sampler2D _MainTex;
        sampler2D _NormalTex;
        sampler2D _MaterialMaskTex;
        half _Cutoff;
        half _NormalScale;
        half _Metallic;
        half _Smoothness;

        struct Input
        {
            float2 uv_MainTex;
			INTERNAL_DATA
        };

        void surf(Input IN, inout SurfaceOutputStylizedPBS o)
        {
            fixed4 color = tex2D(_MainTex, IN.uv_MainTex);
            o.Albedo = color.rgb * _Color.rgb;

            o.Normal = UnpackScaleNormal(tex2D(_NormalTex, IN.uv_MainTex), _NormalScale);

            #if _MASKMAP
                fixed4 mask = tex2D(_MaterialMaskTex, IN.uv_MainTex);
                o.Metallic = mask.r;
                o.Smoothness = mask.g;
                o.SkinMask = mask.b;
            #else
                o.Metallic = _Metallic;
                o.Smoothness = _Smoothness;
            #endif
        }

        ENDCG
    }
    FallBack "Diffuse"
    CustomEditor "DavidStylizedPBRUI"
}
