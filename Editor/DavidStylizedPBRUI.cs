using System;
using UnityEngine;
using System.Linq;
using System.Collections.Generic;

namespace UnityEditor
{
    internal class DavidStylizedPBRUI : ShaderGUI
    {
    	public enum BlendMode
    	{
    		Opaque,
    		Cutout,
    		Fade,		// Old school alpha-blending mode, fresnel does not affect amount of transparency
    		Transparent // Physically plausible transparency mode, implemented as alpha pre-multiply
    	}

    	private static class Styles
    	{
            // Tooltips
    		public static string emptyTootip = "";
            public static GUIContent rampText = new GUIContent("Ramp", "Ramp texture for smoother shading");
    		public static GUIContent albedoText = new GUIContent("Albedo", "Albedo (RGB) and Transparency (A)");
    		public static GUIContent alphaCutoffText = new GUIContent("Alpha Cutoff", "Threshold for alpha cutoff");
    		public static GUIContent specularMapText = new GUIContent("Specular", "Specular (RGB) and Smoothness (A)");
    		public static GUIContent metallicMapText = new GUIContent("Metallic", "Metallic (R) and Smoothness (A)");
    		public static GUIContent smoothnessText = new GUIContent("Smoothness", "");
    		public static GUIContent rimPowerText = new GUIContent("rimlight Multiplier", "");
    		public static GUIContent normalMapText = new GUIContent("Normal Map", "Normal Map");
    		public static GUIContent heightMapText = new GUIContent("Height Map", "Height Map (G)");
    		public static GUIContent occlusionText = new GUIContent("Occlusion", "Occlusion (G), Skin Mask(A)");
    		public static GUIContent emissionText = new GUIContent("Emission", "Emission (RGB)");
    		public static GUIContent detailMaskText = new GUIContent("Detail Mask", "Mask for Secondary Maps (A)");
    		public static GUIContent detailAlbedoText = new GUIContent("Detail Albedo x2", "Albedo (RGB) multiplied by 2");
    		public static GUIContent detailNormalMapText = new GUIContent("Normal Map", "Normal Map");

            // Instructions
            public static string blendModeInstruction = "Currently supports Opaque only.";
            public static string shadingmodeInstruction = "multi_compile is not working yet, only supports Stylized.";
            public static string rampMapInstruction = "Ramp texture will be used for customized shading, it looks up on occlusion texture's alpha channel. \nAlso Lighting model will be HalfLambert.";
            public static string occlusionInstruction = "Uses green channel for occlusion, alpha channel for masking skin. Ramp shading will only be applied on the mask.";

            // Titles
    		public static string whiteSpaceString = " ";
            public static string rampMapText = "Ramp Map";
    		public static string primaryMapsText = "Main Maps";
    		public static string secondaryMapsText = "Secondary Maps";
    		public static string renderingModeText = "Rendering Mode";
            public static string shadingModeText = "Shading Mode";
            public static string cullingMode = "Culling Mode";
            public static string uvTilingText = "UV Tiling and Offset";

            // Warnings
    		public static GUIContent emissiveWarning = new GUIContent ("Emissive value is animated but the material has not been configured to support emissive. Please make sure the material itself has some amount of emissive.");
    		public static GUIContent emissiveColorWarning = new GUIContent ("Ensure emissive color is non-black for emission to have effect.");

            // Menus
    		public static readonly string[] cullingNames = Enum.GetNames (typeof (UnityEngine.Rendering.CullMode));
    		public static readonly string[] blendNames = Enum.GetNames (typeof (BlendMode));
    	}

    	MaterialProperty _BlendMode = null;
        MaterialProperty _CullMode = null;
        MaterialProperty _RampTex = null;
    	MaterialProperty _MainTex = null;
    	MaterialProperty _Color = null;
    	MaterialProperty _CutOff = null;
    	MaterialProperty _MaterialMaskTex = null;
    	MaterialProperty _Metallic = null;
    	MaterialProperty _Smoothness = null;
        MaterialProperty _SmoothnessScale = null;
    	MaterialProperty _NormalTex = null;
        MaterialProperty _NormalScale = null;
    	MaterialProperty _EmissionMap = null;

    	MaterialEditor m_MaterialEditor;
        string[] keywords;
    	bool m_FirstTimeApply = true;

    	public void FindProperties (MaterialProperty[] props)
    	{
            _BlendMode = FindProperty ("_Mode", props);
            _CullMode = FindProperty ("_Cull", props, false);
            _RampTex = FindProperty ("_RampTex", props);
    		_MainTex = FindProperty ("_MainTex", props);
    		_Color = FindProperty ("_Color", props);
    		_CutOff = FindProperty ("_Cutoff", props);
    		_MaterialMaskTex = FindProperty ("_MaterialMaskTex", props, false);
    		_Metallic = FindProperty ("_Metallic", props, false);
    		_Smoothness = FindProperty ("_Smoothness", props);
            _SmoothnessScale = FindProperty("_SmoothnessScale", props);
    		_NormalScale = FindProperty ("_NormalScale", props);
    		_NormalTex = FindProperty ("_NormalTex", props);
    		_EmissionMap = FindProperty ("_EmissionMap", props);
    	}

    	public override void OnGUI (MaterialEditor materialEditor, MaterialProperty[] props)
    	{
    		// MaterialProperties can be animated so we do not cache them but fetch them every eventto ensure animated values are updated correctly
            FindProperties (props);

    		m_MaterialEditor = materialEditor;
    		Material material = materialEditor.target as Material;
            keywords = material.shaderKeywords;

    		ShaderPropertiesGUI (material);

    		// Make sure that needed keywords are set up if we're switching some existing
    		// material to a standard shader.
    		if (m_FirstTimeApply)
    		{
                Initialize();
    			m_FirstTimeApply = false;
    		}
    	}

        private void Initialize() {

        }

    	public void ShaderPropertiesGUI (Material material)
    	{
    		// Use default labelWidth
    		EditorGUIUtility.labelWidth = 0f;
            EditorGUI.BeginChangeCheck();

    		// Detect any changes to the material
            CullModePopup();
            EditorGUILayout.Space();

			BlendModePopup();
            EditorGUILayout.Space();

			// Ramp
            DoRampArea(material);

            // Primary textures
            GUILayout.Label (Styles.primaryMapsText, EditorStyles.boldLabel);
            DoAlbedoArea(material);
            DoSpecularMetallicArea(material);

            m_MaterialEditor.TexturePropertySingleLine(Styles.normalMapText, _NormalTex,
            _NormalTex.textureValue != null ? _NormalScale : null);

            DoEmissionArea(material);
            EditorGUILayout.Space();

            GUILayout.Label (Styles.uvTilingText, EditorStyles.boldLabel);

			m_MaterialEditor.TextureScaleOffsetProperty(_NormalTex);
            EditorGUI.EndChangeCheck();
    	}

    	void BlendModePopup ()
    	{
    		EditorGUI.showMixedValue = _BlendMode.hasMixedValue;
    		var mode = (BlendMode)_BlendMode.floatValue;

    		EditorGUI.BeginChangeCheck();
    		mode = (BlendMode)EditorGUILayout.Popup(Styles.renderingModeText, (int)mode, Styles.blendNames);
    		if (EditorGUI.EndChangeCheck())
    		{
    			m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
    			_BlendMode.floatValue = (float)mode;
    		}

    		EditorGUI.showMixedValue = false;
    	}

        void CullModePopup()
    	{
    		EditorGUI.showMixedValue = _CullMode.hasMixedValue;
    		var mode = (UnityEngine.Rendering.CullMode)Mathf.RoundToInt(_CullMode.floatValue);

    		EditorGUI.BeginChangeCheck();
    		mode = (UnityEngine.Rendering.CullMode)EditorGUILayout.Popup(Styles.cullingMode, (int)mode, Styles.cullingNames);
    		if (EditorGUI.EndChangeCheck())
    		{
    			m_MaterialEditor.RegisterPropertyChangeUndo("Culling Mode");
    			_CullMode.floatValue = (float)mode;
    		}

    		EditorGUI.showMixedValue = false;
    	}

        void DoRampArea(Material material)
        {
            m_MaterialEditor.TexturePropertySingleLine(Styles.rampText, _RampTex);
            EditorGUILayout.Space();

            if (_RampTex.textureValue == null)
                material.DisableKeyword("BRDF_LOOKUP");
            else
                material.EnableKeyword("BRDF_LOOKUP");
        }

    	void DoAlbedoArea(Material material)
    	{
    		m_MaterialEditor.TexturePropertySingleLine(Styles.albedoText, _MainTex, _Color);
    		if (((BlendMode)material.GetFloat("_Mode") == BlendMode.Cutout))
    		{
    			m_MaterialEditor.ShaderProperty(_CutOff, Styles.alphaCutoffText.text, MaterialEditor.kMiniTextureFieldLabelIndentLevel+1);
    		}
    	}

    	void DoEmissionArea(Material material)
    	{
    		m_MaterialEditor.TexturePropertySingleLine(Styles.emissionText, _EmissionMap);
    	}

    	void DoSpecularMetallicArea(Material material)
    	{
			if (_MaterialMaskTex.textureValue == null)
            {
                material.DisableKeyword("_MASKMAP");
                m_MaterialEditor.TexturePropertyTwoLines(Styles.metallicMapText, _MaterialMaskTex, _Metallic, Styles.smoothnessText, _Smoothness);
            }
			else
            {
                material.EnableKeyword("_MASKMAP");
				m_MaterialEditor.TexturePropertySingleLine(Styles.metallicMapText, _MaterialMaskTex);
            }
            m_MaterialEditor.RangeProperty(_SmoothnessScale, "Smoothness Scale");
    	}

    	public static void SetupMaterialWithBlendMode(Material material, BlendMode blendMode)
    	{
    		switch (blendMode)
    		{
    			case BlendMode.Opaque:
    				material.SetOverrideTag("RenderType", "");
    				material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
    				material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
    				material.SetInt("_ZWrite", 1);
    				material.DisableKeyword("_ALPHATEST_ON");
    				material.DisableKeyword("_ALPHABLEND_ON");
    				material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
    				material.renderQueue = -1;
    				break;
    			case BlendMode.Cutout:
    				material.SetOverrideTag("RenderType", "TransparentCutout");
    				material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
    				material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
    				material.SetInt("_ZWrite", 1);
    				material.EnableKeyword("_ALPHATEST_ON");
    				material.DisableKeyword("_ALPHABLEND_ON");
    				material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
    				material.renderQueue = 2450;
    				break;
    			case BlendMode.Fade:
    				material.SetOverrideTag("RenderType", "Transparent");
    				material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
    				material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
    				material.SetInt("_ZWrite", 0);
    				material.DisableKeyword("_ALPHATEST_ON");
    				material.EnableKeyword("_ALPHABLEND_ON");
    				material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
    				material.renderQueue = 3000;
    				break;
    			case BlendMode.Transparent:
    				material.SetOverrideTag("RenderType", "Transparent");
    				material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
    				material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
    				material.SetInt("_ZWrite", 0);
    				material.DisableKeyword("_ALPHATEST_ON");
    				material.DisableKeyword("_ALPHABLEND_ON");
    				material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
    				material.renderQueue = 3000;
    				break;
    		}
    	}

    	static void SetMaterialKeywords(Material material)
    	{
    		// Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
    		// (MaterialProperty value might come from renderer material property block)
            /*
    		SetKeyword (material, "RAMPMAP", material.GetTexture ("_Ramp"));
    		SetKeyword (material, "_NORMALMAP", material.GetTexture ("_BumpMap") || material.GetTexture ("_DetailNormalMap"));
    		if (workflowMode == WorkflowMode.Specular)
    			SetKeyword (material, "_SPECGLOSSMAP", material.GetTexture ("_SpecGlossMap"));
    		else if (workflowMode == WorkflowMode.Metallic)
    			SetKeyword (material, "_METALLICGLOSSMAP", material.GetTexture ("_MetallicGlossMap"));
    		SetKeyword (material, "_PARALLAXMAP", material.GetTexture ("_ParallaxMap"));
    		SetKeyword (material, "_DETAIL_MULX2", material.GetTexture ("_DetailAlbedoMap") || material.GetTexture ("_DetailNormalMap"));

    		bool shouldEmissionBeEnabled = ShouldEmissionBeEnabled (material.GetColor("_EmissionColor"));
    		SetKeyword (material, "_EMISSION", shouldEmissionBeEnabled);

    		// Setup lightmap emissive flags
    		MaterialGlobalIlluminationFlags flags = material.globalIlluminationFlags;
    		if ((flags & (MaterialGlobalIlluminationFlags.BakedEmissive | MaterialGlobalIlluminationFlags.RealtimeEmissive)) != 0)
    		{
    			flags &= ~MaterialGlobalIlluminationFlags.EmissiveIsBlack;
    			if (!shouldEmissionBeEnabled)
    				flags |= MaterialGlobalIlluminationFlags.EmissiveIsBlack;

    			material.globalIlluminationFlags = flags;
    		}
            */
    	}

    	static void MaterialChanged(Material material)
    	{
    		SetupMaterialWithBlendMode(material, (BlendMode)material.GetFloat("_Mode"));
    	}

    	static void SetKeyword(Material m, string keyword, bool state)
    	{
    		if (state)
    			m.EnableKeyword (keyword);
    		else
    			m.DisableKeyword (keyword);
    	}
    }

} // namespace UnityEditor
