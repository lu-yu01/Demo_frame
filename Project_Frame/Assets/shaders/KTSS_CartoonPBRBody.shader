Shader "KTGame/Character/CartoolBody"
{
	Properties
	{
		_Color("Color", Color) = (0.5,0.5,0.5,1)
		_MainTex("Albedo", 2D) = "white" {}
		[Space(20)]
		//_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
		//[Toggle(TINT_COLOR)] _TintColor("Tint Color", Float) = 0
		//_TintTex("Tint", 2D) = "white" {}
		//_TintColorA("Tint Color A", Color) = (1,0,0,1)
		//_TintColorB("Tint Color B", Color) = (0,1,0,1)     
		_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
		
		[Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
		_MetallicGlossMap("Metallic Map", 2D) = "white" {}
		[Toggle(_METALLICGLOSSMAP)] _MatallicGlossMap("Using Metallic Map", Float) = 0

		//[ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

		[Space(20)]

		_BumpScale("Scale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}


		[Space(20)]
		_CartoonBodyMaskZYE("Mask R:Mask G:Shadow Mask B:Emission Mask", 2D) = "white" {}
	   _CartoonBodyShadowOver("Cartoon Body Shader Over", Range(1,40)) = 40
	   _DiffuseThreshold("Threshold for Diffuse Colors", Range(0,1)) = 0
		_CartoonShadowColor("Cartoon Shadow Color", Color) = (0.5,0.5,0.5,1)
		_CartoonShadowTexture("Cartoon Shadow Texture", 2D) = "white" {}


		[Space(20)]

		[hdr]_EmissionColor("Emission",color) = (1,0,0,1)

		_MinEmissionScale("MinEmissionScale",range(0,1)) = 0.5


		//_DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
		//_DetailNormalMapScale("Scale", Float) = 0.0
		//_DetailNormalMap("Normal Map", 2D) = "bump" {}


		//_CustomLightmap("Custom Light Map", 2D) = "white" {}
		//_CustomShadowMask("Custom Shadow Mask", 2D) = "white" {} 
		

		//! GraphicsEnums.cs   
		//	public enum CullMode      
		//	{
		//		Off = 0, 
		//		Front = 1,
		//		Back = 2
		//	}
		//[Toggle(WETLAND)] _Wetland("Enable Wetland", Float) = 0.0
		//_RainAreaShapeTex("Rain Area Shape Tex", 2D) = "white" {}

		[Space(20)]
		[hdr]_HurtColor("Color受击颜色",color) = (0,0,0,0)
		[hdr]_OverlayColor("遮罩颜色",color) = (0,0,0,0)
		_Fresnelhurt("内边缘",float ) = 1
		_GlossHurt("Gloss受击范围 x 亮度 y Pow z 覆盖浓度",vector) = (0,1,0,0)
		[Space(20)]
		[Enum(UV0,0,UV1,1)] _UVSec("UV Set for secondary textures", Float) = 0
		[Enum(Off,2,On,0)] _Cull("__cull", Float) = 2.0

		[Space(20)]
		_DissolveMap("DissolveMap", 2D) = "white"{}
		_DissolveThreshold("DissolveThreshold", Range(0,1)) = 0
		[hdr]_DissolveColor("Dissolve Color", Color) = (0,0,0,0)
		_DissolveEdge("DissolveEdge", Range(0,0.1)) = 0.05

		// Blending state
		[HideInInspector] _Mode("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend("__src", Float) = 1.0
		[HideInInspector] _DstBlend("__dst", Float) = 0.0
		[HideInInspector] _ZWrite("__zw", Float) = 1.0



		//[Toggle(LIGHT_FLOW)] _LightFlow("Light Flow", Float) = 0.0 
		//_LightFlowTex("Light Flow Tex", 2D) = "white" {} 
		//_LightFlowSpeed("Light Flow Speed", Range(0.0, 2.0)) = 0.0
		//_LightFlowThickness("Light Flow Width", Range(0.0, 10)) = 0.0
		//_LightFlowIntensity("Light Flow Intensity", Range(0.0, 1.0)) = 0.0
		//[Enum(X,0,Y,1)]_LightFlowDir("Light Flow Direction", Float) = 0.0

	}


	CGINCLUDE
	#define UNITY_SETUP_BRDF_INPUT MetallicSetup
	#define POINT_LIGHTING 1
	//#define SCENE_LIGHTING 1
	#define BODY_HURT 1
	#define CARDTOOL_CHARACTER_BODY 1
	//#define _METALLICGLOSSMAP 1 
	#define PLAYER_LIGHTING 1
	#define USING_CHARACTER_UV2 1
    #define DISSOLVE 1
	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque""Queue" = "Geometry+60" "PerformanceChecks"="False" }
		
		LOD 400

		// ------------------------------------------------------------------ 
		//  Base forward pass (directional light, emission, lightmaps, ...)              
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }  

			//Blend [_SrcBlend] [_DstBlend]
			ZWrite on

			CGPROGRAM
			#pragma target 3.0
			 
			//#pragma shader_feature _DETAIL_MULX2 
			//#pragma shader_feature _EMISSION
			#pragma multi_compile __ _METALLICGLOSSMAP
			 
			// 
			//#pragma shader_feature _ _GLOSSYREFLECTIONS_OFF
			 
			//#pragma shader_feature SKINMASK 
			//#pragma shader_feature TINT_COLOR  
			//#pragma shader_feature WETLAND 
			//#pragma shader_feature CUSTOM_LIGHTMAP
			//#pragma shader_feature LIGHT_FLOW  
			 
			#pragma multi_compile_fwdbase

			//#pragma multi_compile_fog 
			#pragma multi_compile_instancing

			#pragma vertex vertBase
			#pragma fragment fragBase
			#include "KTSSCoreForward.cginc"
			ENDCG
		}
		
		//// ------------------------------------------------------------------
		////  Additive forward pass (one light per pass)
		//Pass
		//{
		//	Name "FORWARD_DELTA"
		//	Tags { "LightMode" = "ForwardAdd" }
		//	Blend [_SrcBlend] One
		//	Fog { Color (0,0,0,0) } // in additive pass fog should be black
		//	ZWrite Off
		//	Cull [_Cull]
		//	ZTest LEqual

		//	CGPROGRAM
		//	#pragma target 3.0
		//	#define POINT 1
		//	#pragma vertex vertAdd
		//	#pragma fragment frag_surf
		//	#include "KTSSCoreForward.cginc"

		//	half4 frag_surf(VertexOutputForwardAdd i) : SV_Target{
		//		return fragForwardAddInternal(i,  _LightColor0, unity_WorldToLight[0].rgb, _WorldSpaceLightPos0);
		//	}
		//	ENDCG
		//}

		// ------------------------------------------------------------------ 
		//  Shadow rendering pass
		//Pass {
		//	Name "ShadowCaster"
		//	Tags { "LightMode" = "ShadowCaster" }

		//	ZWrite On ZTest LEqual
		//	Cull [_Cull]

		//	CGPROGRAM
		//	#pragma target 3.0
		//	//#pragma shader_feature _METALLICGLOSSMAP

		//	#pragma multi_compile_shadowcaster
		//	#pragma multi_compile_instancing

		//	#pragma vertex vertShadowCaster
		//	#pragma fragment fragShadowCaster

		//	#include "UnityStandardShadow.cginc"

		//	ENDCG
		//}
		UsePass "KTGame/KT_PlanarShadow/PlanarShadow"
		
		// ------------------------------------------------------------------
		// Extracts information for lightmapping, GI (emission, albedo, ...) 
		// This pass it not used during regular rendering. 
		Pass
		{
			Name "META" 
			Tags { "LightMode"="Meta" }

			Cull Off

			CGPROGRAM
			#pragma vertex vert_meta
			#pragma fragment frag_meta

			#pragma shader_feature _EMISSION
			 
			#pragma shader_feature EDITOR_VISUALIZATION

			#include "UnityStandardMeta.cginc"
			ENDCG
		}
	}


	//FallBack "VertexLit"
	//CustomEditor "KTSSShaderGUI"
	FallBack off
}
