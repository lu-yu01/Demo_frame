// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// PBR 函数定义文件
#ifndef _KTSS_LWRP_CGINC_
#define _KTSS_LWRP_CGINC_









//-----------------------------------------------------------------------------
// Define constants
//-----------------------------------------------------------------------------

#define DEFAULT_SPECULAR_VALUE 0.04

half4 _GlossyEnvironmentColor;
struct LWRP_BRDFData
{
	half3 diffuse;
	half3 specular;
	half perceptualRoughness;
	half roughness;
	half roughness2;
	half grazingTerm;

	// We save some light invariant BRDF terms so we don't have to recompute
	// them in the light loop. Take a look at DirectBRDF function for detailed explaination.
	half normalizationTerm;     // roughness * 4.0 + 2.0
	half roughness2MinusOne;    // roughness² - 1.0
};
half LWRP_ReflectivitySpecular(half3 specular)
{
#if defined(SHADER_API_GLES)
	return specular.r; // Red channel - because most metals are either monocrhome or with redish/yellowish tint
#else
	return max(max(specular.r, specular.g), specular.b);
#endif
}

// Ref: "Efficient Evaluation of Irradiance Environment Maps" from ShaderX 2
half3 LWRP_SHEvalLinearL0L1(half3 N, half4 shAr, half4 shAg, half4 shAb)
{
	half4 vA = half4(N, 1.0);

	half3 x1;
	// Linear (L1) + constant (L0) polynomial terms
	x1.r = dot(shAr, vA);
	x1.g = dot(shAg, vA);
	x1.b = dot(shAb, vA);

	return x1;
}

half3 LWRP_SHEvalLinearL2(half3 N, half3 shBr, half3 shBg, half3 shBb, half3 shC)
{
	half3 x2;
	// 4 of the quadratic (L2) polynomials
	half4 vB = N.xyzz * N.yzzx;
	x2.r = dot(shBr, vB);
	x2.g = dot(shBg, vB);
	x2.b = dot(shBb, vB);

	// Final (5th) quadratic (L2) polynomial
	half vC = N.x * N.x - N.y * N.y;
	half3 x3 = shC.rgb * vC;

	return x2 + x3;
}

half3 LWRP_SampleSH9(half4 SHCoefficients[7], half3 N)
{
	half4 shAr = SHCoefficients[0];
	half4 shAg = SHCoefficients[1];
	half4 shAb = SHCoefficients[2];
	half4 shBr = SHCoefficients[3];
	half4 shBg = SHCoefficients[4];
	half4 shBb = SHCoefficients[5];
	half4 shCr = SHCoefficients[6];

	// Linear + constant polynomial terms
	half3 res = LWRP_SHEvalLinearL0L1(N, shAr, shAg, shAb);

	// Quadratic polynomials
	res += LWRP_SHEvalLinearL2(N, shBr, shBg, shBb, shCr);

	return res;
}
// Samples SH L0, L1 and L2 terms
half3 LWRP_SampleSH(half3 normalWS)
{
	// LPPV is not supported in Ligthweight Pipeline
	half4 SHCoefficients[7];
	SHCoefficients[0] = unity_SHAr;
	SHCoefficients[1] = unity_SHAg;
	SHCoefficients[2] = unity_SHAb;
	SHCoefficients[3] = unity_SHBr;
	SHCoefficients[4] = unity_SHBg;
	SHCoefficients[5] = unity_SHBb;
	SHCoefficients[6] = unity_SHC;

	return max(half3(0, 0, 0), LWRP_SampleSH9(SHCoefficients, normalWS));
}

// SH Pixel Evaluation. Depending on target SH sampling might be done
// mixed or fully in pixel. See SampleSHVertex
half3 LWRP_SampleSHPixel(half3 L2Term, half3 normalWS)
{
#if UNITY_SAMPLE_FULL_SH_PER_PIXEL
	half3 L0L1Term = LWRP_SHEvalLinearL0L1(normalWS, unity_SHAr, unity_SHAg, unity_SHAb);
	return max(half3(0, 0, 0), L2Term + L0L1Term);
#elif defined(EVALUATE_SH_MIXED)
	return L2Term;
#endif

	// Default: Evaluate SH fully per-pixel
	return LWRP_SampleSH(normalWS);
}

//-----------------------------------------------------------------------------
// Helper functions for roughness
//-----------------------------------------------------------------------------

half LWRP_PerceptualRoughnessToRoughness(half perceptualRoughness)
{
	return perceptualRoughness * perceptualRoughness;
}

half LWRP_RoughnessToPerceptualRoughness(half roughness)
{
	return sqrt(roughness);
}

half LWRP_RoughnessToPerceptualSmoothness(half roughness)
{
	return 1.0 - sqrt(roughness);
}

half LWRP_PerceptualSmoothnessToRoughness(half perceptualSmoothness)
{
	return (1.0 - perceptualSmoothness) * (1.0 - perceptualSmoothness);
}

half LWRP_PerceptualSmoothnessToPerceptualRoughness(half perceptualSmoothness)
{
	return (1.0 - perceptualSmoothness);
}
half LWRP_OneMinusReflectivityMetallic(half metallic)
{
	// We'll need oneMinusReflectivity, so
	//   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
	// store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
	//   1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) =
	//                  = alpha - metallic * alpha
	half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
	return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}
inline void LWRP_InitializeBRDFData(half3 albedo, half metallic, half3 specular, half smoothness, half alpha, out LWRP_BRDFData outBRDFData)
{
#ifdef _SPECULAR_SETUP
	half reflectivity = LWRP_ReflectivitySpecular(specular);
	half oneMinusReflectivity = 1.0 - reflectivity;

	outBRDFData.diffuse = albedo * (half3(1.0h, 1.0h, 1.0h) - specular);
	outBRDFData.specular = specular;
#else

	half oneMinusReflectivity = LWRP_OneMinusReflectivityMetallic(metallic);
	half reflectivity = 1.0 - oneMinusReflectivity;

	outBRDFData.diffuse = albedo * oneMinusReflectivity;
	outBRDFData.specular = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);

#endif

	outBRDFData.grazingTerm = saturate(smoothness + reflectivity);
	outBRDFData.perceptualRoughness = LWRP_PerceptualSmoothnessToPerceptualRoughness(smoothness);
	outBRDFData.roughness = LWRP_PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness);
	outBRDFData.roughness2 = outBRDFData.roughness * outBRDFData.roughness;

	outBRDFData.normalizationTerm = outBRDFData.roughness * 2.0h + 1.0h;
	outBRDFData.roughness2MinusOne = outBRDFData.roughness2 - 1.0h;

#ifdef _ALPHAPREMULTIPLY_ON
	outBRDFData.diffuse *= alpha;
	alpha = alpha * oneMinusReflectivity + reflectivity;
#endif

}
half2 PositivePow(half2 base, half2 power)
{
	return pow(abs(base), power);
}

// The *approximated* version of the non-linear remapping. It works by
// approximating the cone of the specular lobe, and then computing the MIP map level
// which (approximately) covers the footprint of the lobe with a single texel.
// Improves the perceptual roughness distribution.
half LWRP_PerceptualRoughnessToMipmapLevel(half perceptualRoughness, half mipMapCount)
{
	perceptualRoughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);

	return perceptualRoughness * mipMapCount;
}

half LWRP_PerceptualRoughnessToMipmapLevel(half perceptualRoughness)
{
	return LWRP_PerceptualRoughnessToMipmapLevel(perceptualRoughness, UNITY_SPECCUBE_LOD_STEPS);
}

// Mapping for convolved Texture2D, this is an empirical remapping to match GGX version of cubemap convolution
half LWRP_PlanarPerceptualRoughnessToMipmapLevel(half perceptualRoughness, half mipMapcount)
{
	return PositivePow(perceptualRoughness, 0.8) * uint(max(mipMapcount - 1.0, 0.0));
}

half3 LWRP_GlossyEnvironmentReflection(half3 reflectVector, half perceptualRoughness, half occlusion)
{
#if !defined(_GLOSSYREFLECTIONS_OFF)
	half mip = LWRP_PerceptualRoughnessToMipmapLevel(perceptualRoughness);



	//half4 encodedIrradiance = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVector, mip);
#ifdef _NO_REFLECT
	half4 encodedIrradiance = 0;
#else
	#ifdef PLAYER_LIGHTING
		half4 encodedIrradiance = UNITY_SAMPLE_TEXCUBE_LOD(PlayerCubeMap, reflectVector, mip);
	#else
		half4 encodedIrradiance = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVector, mip);
	#endif
#endif
#ifdef PLAYER_LIGHTING
	half4 hdr = PlayerCubeMap_HDR;
#else
	half4 hdr = unity_SpecCube0_HDR;
#endif
#if !defined(UNITY_USE_NATIVE_HDR)
	half3 irradiance = DecodeHDR(encodedIrradiance, hdr);
#else
	half3 irradiance = encodedIrradiance.rbg;
#endif

	return irradiance * occlusion;
#endif // GLOSSY_REFLECTIONS

	return _GlossyEnvironmentColor.rgb * occlusion;
}
half3 LWRP_EnvironmentBRDF(LWRP_BRDFData brdfData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
{
	half3 c = indirectDiffuse * brdfData.diffuse;
	//half surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
	// 修改pbr环境光太光滑的问题
	half surfaceReduction = 1 - brdfData.roughness2;
	c += surfaceReduction * indirectSpecular * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);
	return c;
}

half3 LWRP_GlobalIllumination(LWRP_BRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS)
{
	
	half3 reflectVector = reflect(-viewDirectionWS, normalWS);
	//reflectVector.y = -reflectVector.y;
	half fresnelTerm = pow(1.0 - saturate(dot(normalWS, viewDirectionWS)),2);

	half3 indirectDiffuse = bakedGI * occlusion;
	half3 indirectSpecular = LWRP_GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion);
#if defined(CLOSE_CUBE_REF)
	indirectSpecular = (0.5 * occlusion).xxx;
#endif

	return LWRP_EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}









// Based on Minimalist CookTorrance BRDF
// Implementation is slightly different from original derivation: http://www.thetenthplanet.de/archives/255
//
// * NDF [Modified] GGX
// * Modified Kelemen and Szirmay-​Kalos for Visibility term
// * Fresnel approximated with 1/LdotH
half3 LWRP_DirectBDRF(LWRP_BRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
{
	half3 halfDir = Unity_SafeNormalize(lightDirectionWS + viewDirectionWS);
	half ndv = saturate(dot(normalWS, viewDirectionWS));
	ndv = ndv * 0.8 + 0.2;
	half NoH = saturate(dot(normalWS, halfDir));
	half LoH = saturate(dot(lightDirectionWS, halfDir));

	// GGX Distribution multiplied by combined approximation of Visibility and Fresnel
	// BRDFspec = (D * V * F) / 4.0
	// D = roughness² / ( NoH² * (roughness² - 1) + 1 )²
	// V * F = 1.0 / ( LoH² * (roughness + 0.5) )
	// See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
	// https://community.arm.com/events/1155

	// Final BRDFspec = roughness² / ( NoH² * (roughness² - 1) + 1 )² * (LoH² * (roughness + 0.5) * 4.0)
	// We further optimize a few light invariant terms
	// brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
	half d =  NoH * NoH * brdfData.roughness2MinusOne + 1.00001h;

	half LoH2 = LoH * LoH;
	half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);

	// on mobiles (where half actually means something) denominator have risk of overflow
	// clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
	// sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
//#if defined (SHADER_API_MOBILE)
//	specularTerm = specularTerm - HALF_MIN;
//	specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
//#endif
	half3 color = saturate(specularTerm * brdfData.specular * ndv);
	//return brdfData.specular;
	return color;

}
void LWRP_LightingPhysicallyBased(LWRP_BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, out half3 sp_color, out half3 diff_color)
{
	sp_color = 0;
	diff_color = 0;
	half NdotL = saturate(dot(normalWS, lightDirectionWS));
	half LambNdotL = (dot(normalWS, lightDirectionWS) * 0.5 + 0.5);
	half3 radiance = lightColor * (lightAttenuation * NdotL);
	half3 diff_radiance = lightColor * (lightAttenuation * LambNdotL);
	sp_color += LWRP_DirectBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
	diff_color += brdfData.diffuse * diff_radiance;
}
void LWRP_LightingPhysicallyBased(LWRP_BRDFData brdfData, LWRP_Light light, half3 normalWS, half3 viewDirectionWS, out half3 sp_color,out half3 diff_color)
{
	LWRP_LightingPhysicallyBased(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, sp_color, diff_color);
}



#endif // _KTSS_LWRP_CGINC_
