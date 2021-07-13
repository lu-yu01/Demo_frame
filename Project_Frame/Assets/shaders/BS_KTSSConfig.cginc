// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// 宏开关定义文件

#ifndef _KTSS_CONFIG_CGINC_
#define _KTSS_CONFIG_CGINC_

// Define Specular cubemap constants
#ifndef UNITY_SPECCUBE_LOD_EXPONENT
#define UNITY_SPECCUBE_LOD_EXPONENT (1.5)
#endif
#ifndef UNITY_SPECCUBE_LOD_STEPS
#define UNITY_SPECCUBE_LOD_STEPS (6)
#endif

// "platform caps" defines: they are controlled from TierSettings (Editor will determine values and pass them to compiler)
// UNITY_SPECCUBE_BOX_PROJECTION:                   TierSettings.reflectionProbeBoxProjection
// UNITY_SPECCUBE_BLENDING:                         TierSettings.reflectionProbeBlending
// UNITY_ENABLE_DETAIL_NORMALMAP:                   TierSettings.detailNormalMap
// UNITY_USE_DITHER_MASK_FOR_ALPHABLENDED_SHADOWS:  TierSettings.semitransparentShadows

// disregarding what is set in TierSettings, some features have hardware restrictions
// so we still add safety net, otherwise we might end up with shaders failing to compile

#if SHADER_TARGET < 30
    #undef UNITY_SPECCUBE_BOX_PROJECTION
    #undef UNITY_SPECCUBE_BLENDING
    #undef UNITY_ENABLE_DETAIL_NORMALMAP
#endif
#if (SHADER_TARGET < 30) || defined(SHADER_API_GLES) || defined(SHADER_API_D3D11_9X) || defined (SHADER_API_PSP2)
    #undef UNITY_USE_DITHER_MASK_FOR_ALPHABLENDED_SHADOWS
#endif

#ifndef UNITY_SAMPLE_FULL_SH_PER_PIXEL
//If this is enabled then we should consider Light Probe Proxy Volumes(SHEvalLinearL0L1_SampleProbeVolume) in ShadeSH9
#define UNITY_SAMPLE_FULL_SH_PER_PIXEL 0
#endif

#ifndef UNITY_BRDF_GGX
#define UNITY_BRDF_GGX 1
#endif

// Orthnormalize Tangent Space basis per-pixel
// Necessary to support high-quality normal-maps. Compatible with Maya and Marmoset.
// However xNormal expects oldschool non-orthnormalized basis - essentially preventing good looking normal-maps :(
// Due to the fact that xNormal is probably _the most used tool to bake out normal-maps today_ we have to stick to old ways for now.
//
// Disabled by default, until xNormal has an option to bake proper normal-maps.
#ifndef UNITY_TANGENT_ORTHONORMALIZE
#define UNITY_TANGENT_ORTHONORMALIZE 0
#endif


// Some extra optimizations

// Simplified Standard Shader is off by default and should not be used for Legacy Shaders
#ifndef UNITY_STANDARD_SIMPLE
    #define UNITY_STANDARD_SIMPLE 0
#endif

// Setup a new define with meaningful name to know if we require world pos in fragment shader
//#if UNITY_STANDARD_SIMPLE
//    #define UNITY_REQUIRE_FRAG_WORLDPOS 0
//#else
    #define UNITY_REQUIRE_FRAG_WORLDPOS 1
//#endif

// Should we pack worldPos along tangent (saving an interpolator)
#if UNITY_REQUIRE_FRAG_WORLDPOS
    #define UNITY_PACK_WORLDPOS_WITH_TANGENT 1
#else
    #define UNITY_PACK_WORLDPOS_WITH_TANGENT 0
#endif

//-------------------------------------------------------------------------------------
// Default BRDF to use:
#if !defined (UNITY_BRDF_PBS) // allow to explicitly override BRDF in custom shader
    // still add safe net for low shader models, otherwise we might end up with shaders failing to compile
    //#if SHADER_TARGET < 30
    //    #define UNITY_BRDF_PBS BRDF3_Unity_PBS
    //#elif defined(UNITY_PBS_USE_BRDF3)
    //    #define UNITY_BRDF_PBS BRDF3_Unity_PBS
    //#elif defined(UNITY_PBS_USE_BRDF2)

    //    #define UNITY_BRDF_PBS BRDF2_Unity_PBS
    //#elif defined(UNITY_PBS_USE_BRDF1)
    //    #define UNITY_BRDF_PBS BRDF1_Unity_PBS
    //#elif defined(SHADER_TARGET_SURFACE_ANALYSIS)
        // we do preprocess pass during shader analysis and we dont actually care about brdf as we need only inputs/outputs
        #define UNITY_BRDF_PBS BRDF1_Unity_PBS
    //#else
    //    #error something broke in auto-choosing BRDF
    //#endif
#endif

//#ifndef unityShadowCoord2
//#define unityShadowCoord2 float2
//#endif
//#ifndef unityShadowCoord3
//#define unityShadowCoord3 float3
//#endif
//#ifndef unityShadowCoord4
//#define unityShadowCoord4 float4
//#endif
//#ifndef unityShadowCoord4x4
//#define unityShadowCoord4x4 float4x4
//#endif

#endif // _KTSS_CONFIG_CGINC_
