// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_META_INCLUDED
#define UNITY_STANDARD_META_INCLUDED

// Functionality for Standard shader "meta" pass
// (extracts albedo/emission for lightmapper etc.)

#include "BS_KTSSCore.cginc"
// 包含自定义的全局光定义文件
#include "BS_KTSSGlobalIllumination.cginc"
#include "BS_LWRP.cginc"
#include "UnityMetaPass.cginc"

struct v2f_meta
{
    float4 pos      : SV_POSITION;
    float4 uv       : TEXCOORD0;
#ifdef EDITOR_VISUALIZATION
    float2 vizUV        : TEXCOORD1;
    float4 lightCoord   : TEXCOORD2;
#endif
};

v2f_meta vert_meta (VertexInput v)
{
    v2f_meta o;
    o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
    o.uv = TexCoords(v);
#ifdef EDITOR_VISUALIZATION
    o.vizUV = 0;
    o.lightCoord = 0;
    if (unity_VisualizationMode == EDITORVIZ_TEXTURE)
        o.vizUV = UnityMetaVizUV(unity_EditorViz_UVIndex, v.uv0.xy, v.uv1.xy, v.uv2.xy, unity_EditorViz_Texture_ST);
    else if (unity_VisualizationMode == EDITORVIZ_SHOWLIGHTMASK)
    {
        o.vizUV = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
        o.lightCoord = mul(unity_EditorViz_WorldToLight, mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)));
    }
#endif
    return o;
}

// Albedo for lightmapping should basically be diffuse color.
// But rough metals (black diffuse) still scatter quite a lot of light around, so
// we want to take some of that into account too.
half3 UnityLightmappingAlbedo (half3 diffuse, half3 specular, half smoothness)
{
    half roughness = SmoothnessToRoughness(smoothness);
    half3 res = diffuse;
    res += specular * roughness * 0.5;
    return res;
}

float4 frag_meta (v2f_meta i) : SV_Target
{
    // we're interested in diffuse & specular colors,
    // and surface roughness to produce final albedo.
	FragmentCommonData data = (FragmentCommonData)0;
	MetallicSetup(data,i.uv);

    UnityMetaInput o;
    UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

#ifdef EDITOR_VISUALIZATION
    o.Albedo = data.diffColor;
    o.VizUV = i.vizUV;
    o.LightCoord = i.lightCoord;
#else
    o.Albedo = UnityLightmappingAlbedo (data.diffColor, data.specColor, data.smoothness);
#endif
    o.SpecularColor = data.specColor;
    o.Emission = Emission(i.uv.xy);

    return UnityMetaFragment(o);
}

inline void InputFragDataMeta(v2f_meta i, inout FragmentCommonData s, out half3 vertexNormal)
{
	//顶点着色器里的环境光因为顶点着色器的vertexWorldNormal是错误的，所以挪进像素着色器里算
	vertexNormal = vertexWorldNormal;
	half Smoothness = 0;
	half Metallic = 0;
	half4 Albedo = half4(0, 0, 0, 0);
	half4 Normal = 0;

	//计算贴图和法线
	float2 splatUV = (i.uv.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
	float4 splat_control = tex2D(_Control, splatUV);
	SamplerTexByXYZ(i.uv, splat_control, Albedo, Normal, Smoothness, Metallic, 0);



	s.metallic = Metallic;
	s.albedo = Albedo.rgb;
	s.alpha = Albedo.a;
	s.smoothness = Smoothness;
	half oneMinusReflectivity;
	half3 specColor;
	half3 diffColor = DiffuseAndSpecularFromMetallic(s.albedo, Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity, 1);
	s.diffColor = diffColor;
	s.specColor = specColor;
	s.oneMinusReflectivity = oneMinusReflectivity;

}
float4 frag_meta_terrain (v2f_meta i) : SV_Target
{
    // we're interested in diffuse & specular colors,
    // and surface roughness to produce final albedo.
	FragmentCommonData data = (FragmentCommonData)0;
	InputFragData(data,i.uv);

    UnityMetaInput o;
    UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

#ifdef EDITOR_VISUALIZATION
    o.Albedo = data.diffColor;
    o.VizUV = i.vizUV;
    o.LightCoord = i.lightCoord;
#else
    o.Albedo = UnityLightmappingAlbedo (data.diffColor, data.specColor, data.smoothness);
#endif
    o.SpecularColor = data.specColor;
    o.Emission = Emission(i.uv.xy);

    return UnityMetaFragment(o);
}

#endif // UNITY_STANDARD_META_INCLUDED
