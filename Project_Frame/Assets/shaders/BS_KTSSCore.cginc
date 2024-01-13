// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef __KTSS_CORE_H__
#define __KTSS_CORE_H__
#include "BS_KTSSConfig.cginc"
#include "BS_KTSSUtils.cginc"

//世界法线获取
half3 PerPixelWorldNormal(half4 i_tex, float4 tangentToWorld[3],float3 worldPos, half3 decalNormal=0,float2 xuv=0,float2 yuv=0,float2 zuv=0,half3 absbumpy=0)
{
//#ifdef _NORMALMAP
#ifdef _NORMALMAP_OFF
	half3 normalWorld = normalize(tangentToWorld[2].xyz);
#else
	half3 tangent = tangentToWorld[0].xyz;
	half3 binormal = tangentToWorld[1].xyz;
	half3 normal = tangentToWorld[2].xyz;

#if UNITY_TANGENT_ORTHONORMALIZE
	normal = NormalizePerPixelNormal(normal);

	// ortho-normalize Tangent
	tangent = normalize(tangent - normal * dot(tangent, normal));

	// recalculate Binormal
	half3 newB = cross(normal, tangent);
	binormal = newB * sign(dot(newB, binormal));
#endif

#ifdef XZYUV
	half3 normalTangent = NormalInTangentSpace(float4(xuv,yuv), worldPos,zuv, absbumpy);
#else
	half3 normalTangent = NormalInTangentSpace(i_tex, worldPos);
#endif
	//贴花法线

#if _DECAL_MAP
#if _GLOSS_FROM_ALBEDO_A | _DECAL_MAP_COLOR_ONLY
#else
	half weight = GetDecalMapWeight(normal);
	half3 decalTangent = UnpackScaleNormal(tex2D(_DecalNormalTex, TRANSFORM_TEX(i_tex.xy, _DetailAlbedoMap)), _DetailNormalMapScale);
	// 法线不能全是使用贴画的，会导致模型太平丢失结构
	normalTangent = lerp(normalTangent, decalTangent, weight * 0.5 * _DetailCover);
	normalTangent = lerp(normalTangent, decalTangent, (1 - weight) * 0.5 * _InvDetailCover);
#endif
#endif
	// 计算冰冻的法线
#if BODY_ICE
	half ice_weight = GetBodyIceMapWeight(i_tex);
	half3 decalTangent = UnpackScaleNormal(tex2D(_IceNormalMap, TRANSFORM_TEX(i_tex.xy, _IceNormalMap)), _IceNormalMapScale);
	normalTangent = lerp(normalTangent, decalTangent, ice_weight * 0.5 );
#endif


#if USING_HUMID_WEIGHT
	//根据模型法线决定采用xyUV还是zyUV
	//half3 absBump = pow(abs(tangentToWorld[2]), 3);
	//float2 yUV = float2(worldPos.z, worldPos.x);
	//float2 xzUV = XZUV(worldPos, absBump);
	//float4 xzyUV = float4(xzUV, yUV);
	////根据法线决定雨流方向
	//RainNormal(normalTangent, xzyUV, absBump.y);
	normalTangent.xyz = lerp(normalTangent.xyz, half3(0, 0.25, 1), _HumidWeight * 0.5); 
	normalTangent.xyz = normalize(normalTangent.xyz);
#else
	normalTangent = normalize(normalTangent.xyz);
#endif
	half3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well
#endif
    return normalWorld;
}

#define IN_VIEWDIR4PARALLAX(i) half3(0,0,0)
#define IN_VIEWDIR4PARALLAX_FWDADD(i) half3(0,0,0)

#if UNITY_REQUIRE_FRAG_WORLDPOS
    #if UNITY_PACK_WORLDPOS_WITH_TANGENT
        #define IN_WORLDPOS(i) float3(i.tangentToWorldAndPackedData[0].w,i.tangentToWorldAndPackedData[1].w,i.tangentToWorldAndPackedData[2].w)
    #else
        #define IN_WORLDPOS(i) i.posWorld
    #endif
    #define IN_WORLDPOS_FWDADD(i) i.posWorld
#else
    #define IN_WORLDPOS(i) half3(0,0,0)
    #define IN_WORLDPOS_FWDADD(i) half3(0,0,0)
#endif

#define IN_LIGHTDIR_FWDADD(i) half3(i.tangentToWorldAndLightDir[0].w, i.tangentToWorldAndLightDir[1].w, i.tangentToWorldAndLightDir[2].w)

#define FRAGMENT_SETUP(x) FragmentCommonData x = \
    FragmentSetup(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX(i), i.tangentToWorldAndPackedData, IN_WORLDPOS(i));

#define FRAGMENT_SETUP_FWDADD(x) FragmentCommonData x = \
    FragmentSetup(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX_FWDADD(i), i.tangentToWorldAndLightDir, IN_WORLDPOS_FWDADD(i));




inline void MetallicSetup(inout FragmentCommonData o, half4 i_tex)
{
	half2 metallicGloss = MetallicGloss(i_tex.xy) ;
	half metallic = metallicGloss.x;
	half smoothness = metallicGloss.y; // this is 1 minus the square root of real roughness m.

	half oneMinusReflectivity;
	half3 specColor;
	o.albedo = Albedo(i_tex, o.DecalMapWeight);
	half3 diffColor = DiffuseAndSpecularFromMetallic(o.albedo, metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity, smoothness);
	o.diffColor = diffColor;
	o.specColor = specColor;
	o.alpha = Alpha(i_tex);
	o.oneMinusReflectivity = oneMinusReflectivity;
	o.smoothness = smoothness;
	o.metallic = metallic;
}

//手动传入金属度和光滑度
/*inline void MetallicSetup(inout FragmentCommonData o, half4 i_tex,half smoothness,half metallic)
{
	half oneMinusReflectivity;
	half3 specColor;

	o.albedo = Albedo(i_tex, o.DecalMapWeight);
	half3 diffColor = DiffuseAndSpecularFromMetallic(o.albedo, metallic, /*out#1# specColor, /*out#1# oneMinusReflectivity, smoothness);
	o.diffColor = diffColor;
	o.specColor = specColor;
	o.oneMinusReflectivity = oneMinusReflectivity;
	o.smoothness = smoothness;
	o.metallic = metallic;
}*/
//手动传入金属度和光滑度和颜色
/*inline void MetallicSetup(inout FragmentCommonData o, half smoothness,half metallic, half4 albedo)
{
	half oneMinusReflectivity;
	half3 specColor;

	o.albedo = albedo;
	half3 diffColor = DiffuseAndSpecularFromMetallic(o.albedo, metallic, /*out#1# specColor, /*out#1# oneMinusReflectivity, smoothness);
	o.diffColor = diffColor;
	o.specColor = specColor;
	o.oneMinusReflectivity = oneMinusReflectivity;
	o.smoothness = smoothness;
	o.metallic = metallic;
}*/
//Face
/*inline void MetallicSetup(inout FragmentCommonData o, half4 i_tex, half2 uv3,out half skinCurvature,inout half3 decalNormal)
{
	half2 metallicGloss = MetallicGloss(i_tex.xy);
	//skinCurvature = saturate(_CurveFactor*0.01*(length(fwidth(normal)) / length(fwidth(worldPos))));
	skinCurvature = metallicGloss.x;
	half smoothness = metallicGloss.y;
	half metallic = 0;
	half oneMinusReflectivity;
	half3 specColor;

	o.albedo = Albedo_Face(i_tex, uv3, decalNormal, metallic, smoothness);
	smoothness = saturate(smoothness);
	 
	half3 diffColor = DiffuseAndSpecularFromMetallic(o.albedo, metallic, /*out#1# specColor, /*out#1# oneMinusReflectivity, smoothness);
	o.diffColor = diffColor;
	o.specColor = specColor;
	o.oneMinusReflectivity = oneMinusReflectivity;
	o.smoothness = smoothness;
	o.metallic = metallic;
}*/
/*inline void MetallicSetup_TerrainMesh(inout FragmentCommonData o, half4 i_tex, float4 tangentToWorld[3])
{
	//skinCurvature = saturate(_CurveFactor*0.01*(length(fwidth(normal)) / length(fwidth(worldPos))));
	
	half oneMinusReflectivity;
	half3 specColor;
	half Smoothness = 0;
	half Metallic = 0;
	half4 Albedo = half4(0, 0, 0, 0);
	half4 Normal = 0;



	half3 tangent = tangentToWorld[0].xyz;
	half3 binormal = tangentToWorld[1].xyz;
	half3 normal = tangentToWorld[2].xyz;

	half3 vertexWorldNormal = normal;
	float2 splatUV = (i_tex.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
	float4 splat_control = tex2D(_Control, splatUV);
	SamplerTexByXYZ(i_tex, splat_control, Albedo, Normal, Smoothness, Metallic);
	

	o.normalMap = Normal;
	o.metallic = Metallic;
	o.albedo = Albedo.xyz;
	o.smoothness = Smoothness;
	o.normalWorld = normalize(tangent * Normal.x + binormal * Normal.y + normal * Normal.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well
	half3 diffColor = DiffuseAndSpecularFromMetallic(o.albedo, Metallic, /*out#1# specColor, /*out#1# oneMinusReflectivity, Smoothness);
	o.diffColor = diffColor;
	o.specColor = specColor;
	o.oneMinusReflectivity = oneMinusReflectivity;
	o.alpha = Albedo.a;
}*/

inline FragmentCommonData FragmentSetup (half4 i_tex, half3 i_eyeVec, half3 i_viewDirForParallax, float4 tangentToWorld[3], float3 i_posWorld)
{
    #if defined(_ALPHATEST_ON)
		half alpha = Alpha(i_tex.xy);
        clip (alpha - _Cutoff);
    #endif

    FragmentCommonData o = (FragmentCommonData)0;
	o.DecalMapWeight = GetDecalMapWeight(tangentToWorld[2].xyz);
	// 计算冰冻权重
#if BODY_ICE
	o.BodyIceWeight = GetBodyIceMapWeight(i_tex);
#endif
#ifdef XZYUV
	half3 absDirections = abs(pow(tangentToWorld[2].xyz, 3));
	absDirections /= dot(absDirections.xyz, 1);
	absDirections = saturate(absDirections);
	absDirections /= dot(absDirections, 1);
	float3 pos = (i_posWorld*_MainTex_ST.x);
	float2 yUV = float2(tangentToWorld[2].y > 0 ? -pos.z : pos.z, pos.x);
	float2 zUV = float2(tangentToWorld[2].z > 0 ? -pos.x : pos.x, pos.y);
	float2 xUV = float2(tangentToWorld[2].x < 0 ? -pos.z : pos.z, pos.y);

	MetallicSetup(o, xUV,yUV,zUV, absDirections);
	o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld, i_posWorld,0, xUV, yUV, zUV, absDirections);
#elif TERRAIN_MESH
	//MetallicSetup_TerrainMesh(o, i_tex, tangentToWorld);
	//o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld, i_posWorld);

#else
	MetallicSetup(o, i_tex);
	o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld, i_posWorld);
#endif
    o.eyeVec = NormalizePerPixelNormal(i_eyeVec);
    o.posWorld = i_posWorld;
    // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    return o;
}

//-------------------------------------------------------------------------------------

//VertexOutputForwardAdd vertForwardAdd (VertexInput v)
//{
//    UNITY_SETUP_INSTANCE_ID(v);
//    VertexOutputForwardAdd o;
//    UNITY_INITIALIZE_OUTPUT(VertexOutputForwardAdd, o);
//    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
//
//    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
//    o.pos = UnityObjectToClipPos(v.vertex);
//
//    o.tex = TexCoords(v);
//    o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
//    o.posWorld = posWorld.xyz;
//    float3 normalWorld = UnityObjectToWorldNormal(v.normal);
//    //#ifdef _TANGENT_TO_WORLD
//        float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
//
//        float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
//        o.tangentToWorldAndLightDir[0].xyz = tangentToWorld[0];
//        o.tangentToWorldAndLightDir[1].xyz = tangentToWorld[1];
//        o.tangentToWorldAndLightDir[2].xyz = tangentToWorld[2];
//    //#else
//    //    o.tangentToWorldAndLightDir[0].xyz = 0;
//    //    o.tangentToWorldAndLightDir[1].xyz = 0;
//    //    o.tangentToWorldAndLightDir[2].xyz = normalWorld;
//    //#endif
//    //We need this for shadow receiving
//    UNITY_TRANSFER_SHADOW(o, v.uv1);
//
//    float3 lightDir = _WorldSpaceLightPos0.xyz - posWorld.xyz * _WorldSpaceLightPos0.w;
//    #ifndef USING_DIRECTIONAL_LIGHT
//        lightDir = NormalizePerVertexNormal(lightDir);
//    #endif
//    o.tangentToWorldAndLightDir[0].w = lightDir.x;
//    o.tangentToWorldAndLightDir[1].w = lightDir.y;
//    o.tangentToWorldAndLightDir[2].w = lightDir.z;
//
//    UNITY_TRANSFER_FOG(o,o.pos);
//    return o;
//}



#endif // __KTSS_CORE_H__
