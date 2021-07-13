// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// 全局光函数定义文件
#ifndef _KTSS_GLOBAL_ILLUMINATION_CGINC_
#define _KTSS_GLOBAL_ILLUMINATION_CGINC_

// Functions sampling light environment data (lightmaps, light probes, reflection probes), which is then returned as the UnityGI struct.

#include "BS_KTSSCore.cginc"

inline half3 DecodeDirectionalSpecularLightmap (half3 color, half4 dirTex, half3 normalWorld, bool isRealtimeLightmap, fixed4 realtimeNormalTex, out UnityLight o_light)
{
    o_light.color = color;
    o_light.dir = dirTex.xyz * 2 - 1;
    o_light.ndotl = 0; // Not use;

    // The length of the direction vector is the light's "directionality", i.e. 1 for all light coming from this direction,
    // lower values for more spread out, ambient light.
    half directionality = max(0.001, length(o_light.dir));
    o_light.dir /= directionality;

    // Split light into the directional and ambient parts, according to the directionality factor.
    half3 ambient = o_light.color * (1 - directionality);
    o_light.color = o_light.color * directionality;

    // Technically this is incorrect, but helps hide jagged light edge at the object silhouettes and
    // makes normalmaps show up.
    ambient *= saturate(dot(normalWorld, o_light.dir));
    return ambient;
}

inline void ResetUnityLight(out UnityLight outLight)
{
    outLight.color = half3(0, 0, 0);
    outLight.dir = half3(0, 1, 0); // Irrelevant direction, just not null
    outLight.ndotl = 0; // Not used
}

inline half3 SubtractMainLightWithRealtimeAttenuationFromLightmap (half3 lightmap, half attenuation, half4 bakedColorTex, half3 normalWorld)
{
    // Let's try to make realtime shadows work on a surface, which already contains
    // baked lighting and shadowing from the main sun light.
    half3 shadowColor = lerp(_PBRShadowColor.rgb, _PBRFringeShadowColor.rgb, attenuation);
    half shadowStrength = _LightShadowData.x;

    // Summary:
    // 1) Calculate possible value in the shadow by subtracting estimated light contribution from the places occluded by realtime shadow:
    //      a) preserves other baked lights and light bounces
    //      b) eliminates shadows on the geometry facing away from the light
    // 2) Clamp against user defined ShadowColor.
    // 3) Pick original lightmap value, if it is the darkest one.


    // 1) Gives good estimate of illumination as if light would've been shadowed during the bake.
    //    Preserves bounce and other baked lights
    //    No shadows on the geometry facing away from the light
    half ndotl = LambertTerm (normalWorld, _WorldSpaceLightPos0.xyz);
    half3 estimatedLightContributionMaskedByInverseOfShadow = ndotl * (1- attenuation) * _LightColor0.rgb;
    half3 subtractedLightmap = lightmap - estimatedLightContributionMaskedByInverseOfShadow;

    // 2) Allows user to define overall ambient of the scene and control situation when realtime shadow becomes too dark.
    half3 realtimeShadow = max(subtractedLightmap, shadowColor);
    realtimeShadow = lerp(realtimeShadow, lightmap, shadowStrength);

    // 3) Pick darkest color
    return min(lightmap, realtimeShadow);
}

inline void ResetUnityGI(out UnityGI outGI)
{
    ResetUnityLight(outGI.light);
    outGI.indirect.diffuse = 0;
    outGI.indirect.specular = 0;
}

//-------------------------------------------------------------------------------------
half3 ShadeSHPerVertex(half3 normal, half3 ambient)
{
#if UNITY_SAMPLE_FULL_SH_PER_PIXEL
	// Completely per-pixel
	// nothing to do here
#elif (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
	// Completely per-vertex
	ambient += max(half3(0, 0, 0), ShadeSH9(half4(normal, 1.0)));
#else
	// L2 per-vertex, L0..L1 & gamma-correction per-pixel

	// NOTE: SH data is always in Linear AND calculation is split between vertex & pixel
	// Convert ambient to Linear and do final gamma-correction at the end (per-pixel)

	//这里注释掉了关于EnvironmentCol的计算，改在了顶点了计算
#ifdef UNITY_COLORSPACE_GAMMA
	ambient = GammaToLinearSpace(ambient);
#endif
	ambient += SHEvalLinearL2(half4(normal, 1.0));     // no max since this is only L2 contribution
#endif
	return ambient;
}

half3 ShadeSHPerPixel(half3 normal, half3 ambient, float3 worldPos)
{
	half3 ambient_contrib = 0.0;

#if UNITY_SAMPLE_FULL_SH_PER_PIXEL
	// Completely per-pixel
	ambient_contrib = ShadeSH9(half4(normal, 1.0));
	ambient += max(half3(0, 0, 0), ambient_contrib);

	//默认用SHEvalLinearL0L1  SHAr SHAg SHAb代表什么颜色?
	//SHBr SHBg SHBb代表EnvironmentLighting三种颜色？

#elif (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
	// Completely per-vertex
	// nothing to do here
#else
	// L2 per-vertex, L0..L1 & gamma-correction per-pixel
	// Ambient in this case is expected to be always Linear, see ShadeSHPerVertex()
#if UNITY_LIGHT_PROBE_PROXY_VOLUME
	//if (unity_ProbeVolumeParams.x == 1.0)
	//	ambient_contrib = SHEvalLinearL0L1_SampleProbeVolume(half4(normal, 1.0), worldPos);
	//else
		ambient_contrib = SHEvalLinearL0L1(half4(normal, 1.0));
#else
	ambient_contrib = SHEvalLinearL0L1(half4(normal, 1.0));
#endif

	ambient = max(half3(0, 0, 0), ambient + ambient_contrib) ;     // include L2 contribution in vertex shader before clamp.

#ifdef UNITY_COLORSPACE_GAMMA
	ambient = LinearToGammaSpace(ambient);
#endif
#endif

	return ambient;
}
inline UnityGI UnityGI_Base(UnityGIInput data, half occlusion, half3 normalWorld,half3 specular)
{
    UnityGI o_gi;
    ResetUnityGI(o_gi);

    // Base pass with Lightmap support is responsible for handling ShadowMask / blending here for performance reason
    #if defined(HANDLE_SHADOWS_BLENDING_IN_GI)
        half bakedAtten = UnitySampleBakedOcclusion(data.lightmapUV.xy, data.worldPos);
        float zDist = dot(_WorldSpaceCameraPos - data.worldPos, UNITY_MATRIX_V[2].xyz);
        float fadeDist = UnityComputeShadowFadeDistance(data.worldPos, zDist);
        data.atten = UnityMixRealtimeAndBakedShadows(data.atten, bakedAtten, UnityComputeShadowFade(fadeDist));
    #endif

    o_gi.light = data.light;
    o_gi.light.color *= data.atten;

    #if UNITY_SHOULD_SAMPLE_SH
        o_gi.indirect.diffuse = ShadeSHPerPixel (normalWorld, data.ambient, data.worldPos);
    #endif
		//加上一个specular影响的灰度值，为了让在暗面看的时候更有"光泽"，会影响整体亮度相比以前更"亮"一些;
	half maxSpecular = max(specular.r, max(specular.g, specular.b));
	o_gi.indirect.diffuse = o_gi.indirect.diffuse;

	//暗部的环境光更暗一些，增加立体感和对比度
	o_gi.indirect.diffuse *= (data.atten*0.5+0.5);

    o_gi.indirect.diffuse *= occlusion;
    return o_gi;
}

//-------------------------------------------------------------------------------------
inline half3 BoxProjectedCubemapDirection(half3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax)
{
	// Do we have a valid reflection probe?
	UNITY_BRANCH
		if (cubemapCenter.w > 0.0)
		{
			half3 nrdir = normalize(worldRefl);

#if 1
			half3 rbmax = (boxMax.xyz - worldPos) / nrdir;
			half3 rbmin = (boxMin.xyz - worldPos) / nrdir;

			half3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;

#else // Optimized version
			half3 rbmax = (boxMax.xyz - worldPos);
			half3 rbmin = (boxMin.xyz - worldPos);

			half3 select = step(half3(0, 0, 0), nrdir);
			half3 rbminmax = lerp(rbmax, rbmin, select);
			rbminmax /= nrdir;
#endif

			half fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);

			worldPos -= cubemapCenter.xyz;
			worldRefl = worldPos + nrdir * fa;
		}
	return worldRefl;
}
// ----------------------------------------------------------------------------
half3 Unity_GlossyEnvironment(UNITY_ARGS_TEXCUBE(tex), half4 hdr, KTUnity_GlossyEnvironmentData glossIn)
{
	half perceptualRoughness = glossIn.roughness /* perceptualRoughness */;

	perceptualRoughness = perceptualRoughness*(1.7 - 0.7*perceptualRoughness);

	half mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);
	half3 R = glossIn.reflUVW;
	half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(tex, R, mip);

	return DecodeHDR(rgbm, hdr);
}

inline half3 UnityGI_IndirectSpecular(UnityGIInput data, half occlusion, KTUnity_GlossyEnvironmentData glossIn)
{
    half3 specular; 

    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
        // we will tweak reflUVW in glossIn directly (as we pass it to Unity_GlossyEnvironment twice for probe0 and probe1), so keep original to pass into BoxProjectedCubemapDirection
        half3 originalReflUVW = glossIn.reflUVW;
        glossIn.reflUVW = BoxProjectedCubemapDirection (originalReflUVW, data.worldPos, data.probePosition[0], data.boxMin[0], data.boxMax[0]);
    #endif

    //#ifdef _GLOSSYREFLECTIONS_OFF
    //    specular = unity_IndirectSpecColor.rgb;
    //#else
#ifdef PLAYER_LIGHTING
		half3 env0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(PlayerCubeMap), PlayerCubeMap_HDR, glossIn);
#else
        half3 env0 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube0), data.probeHDR[0], glossIn);
#endif
            specular = env0;
    //#endif

    return specular;
}

// Deprecated old prototype but can't be move to Deprecated.cginc file due to order dependency
inline half3 UnityGI_IndirectSpecular(UnityGIInput data, half occlusion, half3 normalWorld, KTUnity_GlossyEnvironmentData glossIn)
{
    // normalWorld is not used
    return UnityGI_IndirectSpecular(data, occlusion, glossIn);
}

inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half3 normalWorld)
{
    return UnityGI_Base(data, occlusion, normalWorld,1);
}

inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half3 normalWorld, KTUnity_GlossyEnvironmentData glossIn)
{
	//更改说明:让GI的diffuse(Ambient)加上一个specular(CubeMap)的亮度影响
	half3 specular= UnityGI_IndirectSpecular(data, occlusion, glossIn);
	UnityGI o_gi = UnityGI_Base(data, occlusion, normalWorld, specular);
	specular *= occlusion;
    o_gi.indirect.specular = specular;
	//o_gi.indirect.specular = lerp(data.albedo, specular, data.smoothness*data.smoothness*data.smoothness);
    return o_gi;
}

//
// Old UnityGlobalIllumination signatures. Kept only for backward compatibility and will be removed soon
//

inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half smoothness, half3 normalWorld, bool reflections)
{
    if(reflections)
    {
		KTUnity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(smoothness, data.worldViewDir, normalWorld, float3(0, 0, 0));
        return UnityGlobalIllumination(data, occlusion, normalWorld, g);
    }
    else
    {
        return UnityGlobalIllumination(data, occlusion, normalWorld);
    }
}
inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half smoothness, half3 normalWorld)
{
    bool sampleReflections = true;
    return UnityGlobalIllumination (data, occlusion, smoothness, normalWorld, sampleReflections);
}
inline half4 VertexGIForward(VertexInput v, float3 posWorld, half3 normalWorld)
{
	half4 ambientOrLightmapUV = 0;

	#if UNITY_SHOULD_SAMPLE_SH
#ifdef VERTEXLIGHT_ON
	// Approximated illumination from non-important point lights
	ambientOrLightmapUV.rgb = Shade4PointLights(
		unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		unity_4LightAtten0, posWorld, normalWorld);
#endif

	ambientOrLightmapUV.rgb = ShadeSHPerVertex(normalWorld, ambientOrLightmapUV.rgb);
#endif



	return ambientOrLightmapUV;
}

inline half4 VertexGIForward( float3 posWorld, half3 normalWorld)
{
	half4 ambientOrLightmapUV = 0;

#if UNITY_SHOULD_SAMPLE_SH
#ifdef VERTEXLIGHT_ON
	// Approximated illumination from non-important point lights
	ambientOrLightmapUV.rgb = Shade4PointLights(
		unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		unity_4LightAtten0, posWorld, normalWorld);
#endif

	ambientOrLightmapUV.rgb = ShadeSHPerVertex(normalWorld, ambientOrLightmapUV.rgb);
#endif



	return ambientOrLightmapUV;
}


inline UnityGI FragmentGI(FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light, bool reflections)
{
	UnityGIInput d;
	d.light = light;
	d.worldPos = s.posWorld;
	d.worldViewDir = -s.eyeVec;
	d.atten = atten;

	d.ambient = i_ambientOrLightmapUV.rgb;
	d.lightmapUV = 0;

	d.probeHDR[0] = unity_SpecCube0_HDR;
	d.probeHDR[1] = unity_SpecCube0_HDR;
#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
	d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
#endif
#ifdef UNITY_SPECCUBE_BOX_PROJECTION
	d.boxMax[0] = unity_SpecCube0_BoxMax;
	d.probePosition[0] = unity_SpecCube0_ProbePosition;
	d.boxMax[1] = unity_SpecCube1_BoxMax;
	d.boxMin[1] = unity_SpecCube0_BoxMin;
	d.probePosition[1] = unity_SpecCube1_ProbePosition;
#endif

	if (reflections)
	{
		KTUnity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.smoothness, -s.eyeVec, s.normalWorld, s.specColor);
		// Replace the reflUVW if it has been compute in Vertex shader. Note: the compiler will optimize the calcul in UnityGlossyEnvironmentSetup itself
#if UNITY_STANDARD_SIMPLE
		g.reflUVW = s.reflUVW;
#endif

		UnityGI gi= UnityGlobalIllumination(d, occlusion, s.normalWorld, g);
		//越粗糙越接近底色(ps:这是为了对UE4，越粗糙越使用贴图本身颜色，越光滑越使用cubemap)
		gi.indirect.specular = lerp(s.albedo,gi.indirect.specular, s.smoothness * s.smoothness * s.smoothness);
		//gi.indirect.specular *= pow(max(light.color.r, max(light.color.g, light.color.b)), 0.4545)*(atten*0.5 + 0.5);
		//暗部金属过亮的话可以考虑加上这句 或者*0.5+0.5
		//gi.indirect.specular *= (atten*0.3 + 0.7);
		return gi;
	}
	else
	{
		return UnityGlobalIllumination(d, occlusion, s.normalWorld);
	}
}

inline UnityGI FragmentGI(FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light)
{
	return FragmentGI(s, occlusion, i_ambientOrLightmapUV, atten, light, true);
}

#endif
