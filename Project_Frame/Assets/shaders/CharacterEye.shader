// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

/*
*Hi, I'm Lin Dong,
*this shader is about realistic eye rendering in unity3d
*if you want to get more detail please enter my blog http://blog.csdn.net/wolf96
*/
Shader "KTGame/Character/Eye" {
//	Properties{
//	//Cornea角膜
//	//Iris虹膜
//	//Sclera巩膜
//	_Lum("Luminance", Range(0, 10)) = 4
//	_MainTex("Base (RGB)", 2D) = "white" {}
//	_IrisColor("cornea Color", Color) = (1, 1, 1, 1)
//		_SCCornea("Specular Color", Color) = (1, 1, 1, 1)
//		_SpecularTex("SpecularTex (RGB)", 2D) = "white" {}
//	_NormalIrisTex("NormalIrisTex (RGB)", 2D) = "white" {}
//	_MaskTex("MaskTex (RGB)", 2D) = "white" {}
//	_NormalIrisDetialTex("Iris Detial Tex (RGB)", 2D) = "white" {}
//	_GLCornea("gloss", Range(0, 2)) = 0.5
//		_GLIris("Iris Gloss", Range(0, 2)) = 0.5
//		_SPIris("Iris Specular Power", Range(1, 100)) = 20
//		_SPScleraDetial("Sclera Detial Specular Color and Instance", Color) = (1, 1, 1, 1)
//
//		_ReflAmount("ReflAmount", Range(0, 2)) = 1
//		_Cubemap("CubeMap", CUBE) = ""{}
//}

Properties
{
	_Color("Color", Color) = (1,1,1,1)
	_MainTex("Albedo", 2D) = "white" {}
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


	_BumpScale("Scale", Float) = 1.0
	_BumpMap("Normal Map", 2D) = "bump" {}
	// 眼镜巩膜镜面反射强度
	_EyeIrisSpecularPow("Eye Iris Specular Power", Range(1, 100)) = 1
	_EyeIrisSpecularLit("Eye Iris Specular Lit", Range(0.01, 1)) = 0.02
	_EyeIrisSpecularMask("Eye Iris Specular Mask", 2D) = "white" {}

	 [Enum(UV0,0,UV1,1)] _UVSec("UV Set for secondary textures", Float) = 0

	 [Enum(Off,2,On,0)] _Cull("__cull", Float) = 2.0

	 // Blending state
	 [HideInInspector] _Mode("__mode", Float) = 0.0
	 [HideInInspector] _SrcBlend("__src", Float) = 1.0
	 [HideInInspector] _DstBlend("__dst", Float) = 0.0
	 [HideInInspector] _ZWrite("__zw", Float) = 1.0

		[hdr]_HurtColor("Color受击颜色",color) = (0,0,0,0)
		[hdr]_OverlayColor("遮罩颜色",color) = (0,0,0,0)
		_GlossHurt("Gloss受击范围 x 亮度 y Pow z 覆盖浓度",vector) = (0,1,0,0)


}


CGINCLUDE
#define UNITY_SETUP_BRDF_INPUT MetallicSetup
//#define POINT_LIGHTING 1
//#define SCENE_LIGHTING 1
#define CHARACTER_EYE 1
//#define _METALLICGLOSSMAP 1 
//#define PLAYER_LIGHTING 1
#define BODY_HURT 1

ENDCG

SubShader
{
	Tags { "RenderType" = "Opaque""Queue" = "Geometry+40" "PerformanceChecks" = "False" }


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

	//#define PLAYER_LIGHTING 1
	#pragma multi_compile_fwdbase noshadowmask nodynlightmap nolightmap

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
Pass {
	Name "ShadowCaster"
	Tags { "LightMode" = "ShadowCaster" }

	ZWrite On ZTest LEqual
	Cull[_Cull]

	CGPROGRAM
	#pragma target 3.0
	//#pragma shader_feature _METALLICGLOSSMAP

	#pragma multi_compile_shadowcaster
	#pragma multi_compile_instancing

	#pragma vertex vertShadowCaster
	#pragma fragment fragShadowCaster

	#include "UnityStandardShadow.cginc"

	ENDCG
}

// ------------------------------------------------------------------
// Extracts information for lightmapping, GI (emission, albedo, ...) 
// This pass it not used during regular rendering. 
Pass
{
	Name "META"
	Tags { "LightMode" = "Meta" }

	Cull Off

	CGPROGRAM
	#pragma vertex vert_meta
	#pragma fragment frag_meta

	#pragma shader_feature _EMISSION
	#pragma shader_feature _METALLICGLOSSMAP

	#pragma shader_feature EDITOR_VISUALIZATION

	#include "UnityStandardMeta.cginc"
	ENDCG
}
}

//FallBack "VertexLit"
CustomEditor "KTSSShaderGUI"
}
