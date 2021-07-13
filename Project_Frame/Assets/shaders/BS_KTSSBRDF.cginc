// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
#pragma exclude_renderers d3d11 gles
// PBR 函数定义文件
#ifndef _KTSS_BRDF_CGINC_
	#define _KTSS_BRDF_CGINC_


	#include "BS_KTSSCore.cginc"
	// 包含自定义的全局光定义文件
	#include "BS_KTSSGlobalIllumination.cginc"
	#include "BS_LWRP.cginc"


	sampler2D unity_NHxRoughness;

	//-------------------------------------------------------------------------------------

	half3 SSSLighting(half NoL,half skinValue)
	{
		half2 sssUV = half2(NoL*0.5 + 0.5, skinValue);
		half3 sssDiffuse = tex2D(_SkinTex, sssUV);
		return sssDiffuse;
	}

	half3 SSSTrans(half3 lightDir,half3 viewDir,half3 normal,half mask)
	{
		half3 transH = normalize(lightDir + normal);
		float dv = dot(viewDir, transH) ;
		half I_Front = saturate(pow(dv * 0.5 + 0.5, _TransLight.x)*_TransLight.y);
		half I_Back = saturate(pow((1 - dv) * 0.5 + 0.5, _TransLight.z)*_TransLight.w);

		half3 transDiff =saturate( _TransColor*(I_Back + I_Front)*mask);
		return transDiff;
	}
	half3 SSSTrans(half3 lightDir,half3 viewDir,half3 normal,half4 sssColor,half4 sssLight,half mask)
	{
		half3 transH = normalize(lightDir + normal);
		float dv = dot(viewDir, transH) ;
		half I_Front = saturate(pow(dv * 0.5 + 0.5, sssLight.x)*sssLight.y);
		half I_Back = saturate(pow((1 - dv) * 0.5 + 0.5, sssLight.z)*sssLight.w);

		half3 transDiff =saturate(sssColor*(I_Back + I_Front)*mask);
		return transDiff;
	}

	half3 ShiftTangent(half3 T, half3 N, float shift)
	{
		half3 shiftedT = T + shift*N;
		return normalize(shiftedT);
	}

	float StrandSpecular(half3 H, half3 T, float exponent)
	{
		float dotTH = dot(T, H);
		float sinTH = sqrt(1 - dotTH*dotTH);
		float dirAtten = smoothstep(-1, 0, dotTH);
		return  dirAtten*pow(sinTH, exponent);
	}
	// Ref: http://jcgt.org/published/0003/02/03/paper.pdf
	inline half SmithJointGGXVisibilityTerm(half NdotL, half NdotV, half roughness)
	{
		#if 0
			// Original formulation:
			//  lambda_v    = (-1 + sqrt(a2 * (1 - NdotL2) / NdotL2 + 1)) * 0.5f;
			//  lambda_l    = (-1 + sqrt(a2 * (1 - NdotV2) / NdotV2 + 1)) * 0.5f;
			//  G           = 1 / (1 + lambda_v + lambda_l);

			// Reorder code to be more optimal
			half a = roughness;
			half a2 = a * a;

			half lambdaV = NdotL * sqrt((-NdotV * a2 + NdotV) * NdotV + a2);
			half lambdaL = NdotV * sqrt((-NdotL * a2 + NdotL) * NdotL + a2);

			// Simplify visibility term: (2.0f * NdotL * NdotV) /  ((4.0f * NdotL * NdotV) * (lambda_v + lambda_l + 1e-5f));
			return 0.5f / (lambdaV + lambdaL + 1e-5f);  // This function is not intended to be running on Mobile,
			// therefore epsilon is smaller than can be represented by half
		#else
			// Approximation of the above formulation (simplify the sqrt, not mathematically correct but close enough)
			half a = roughness;
			half lambdaV = NdotL * (NdotV * (1 - a) + a);
			half lambdaL = NdotV * (NdotL * (1 - a) + a);

			return 0.5f / (lambdaV + lambdaL + 1e-5f);
		#endif
	}

	half4 BRDF1_Unity_FacePBS(half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi,half skinCurvature)
	{
		half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
		half3 halfDir = Unity_SafeNormalize(light.dir + viewDir);
		half nv = abs(dot(normal, viewDir));
		half NoL = dot(normal, light.dir);
		half nl = saturate(NoL);
		half nh = max(0, dot(normal, halfDir));
		half lv = max(0, dot(light.dir, viewDir));
		half lh = max(0, dot(light.dir, halfDir));
		
		//漫反射项
		//half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;
		half3 diffuseTerm = SSSLighting(NoL, _CurveFactor*skinCurvature);


		half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
		half V = SmithJointGGXVisibilityTerm(nl, nv, roughness);
		half D = GGXTerm(nh, roughness);
		half specularTerm = V*D * UNITY_PI;

		#   ifdef UNITY_COLORSPACE_GAMMA
		specularTerm = sqrt(max(1e-4h, specularTerm));
		#   endif

		specularTerm = max(0, specularTerm * nl);

		half surfaceReduction;
		#   ifdef UNITY_COLORSPACE_GAMMA
		surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
		#   else
		surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
		#   endif

		half atten= any(specColor) ? 1.0 : 0.0;
		specularTerm *= atten;
		half grazingTerm = (1 - oneMinusReflectivity);
		gi.diffuse = gi.diffuse * 0.7 + gi.diffuse * max(normal.y, 0) * 0.4;

		//half3 color = diffColor * (gi.diffuse + light.color * diffuseTerm)
		//	+ specularTerm * light.color * FresnelTerm(specColor, lh)
		//	+ grazingTerm * gi.specular * FresnelLerp(specColor, surfaceReduction, nv * smoothness);
		//
		half3 color = diffColor * (gi.diffuse + light.color * diffuseTerm) * (nv*0.6 + 0.4)
		//高光部分乘以nv突出焦点,*0.8简单粗暴防止高光过爆
		+ specularTerm * light.color * FresnelTerm(specColor, lh)*nv*0.8
		+ grazingTerm * gi.specular * FresnelLerp(specColor, surfaceReduction, nv * smoothness)*nv* smoothness;


		color += SSSTrans(light.dir, viewDir, normal, skinCurvature);
		return half4(color, 1);
	}

	half4 BRDF1_Unity_PBS(half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi, half skinMask)
	{
		//return half4(light.color, 1);
		half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
		half3 halfDir = Unity_SafeNormalize(light.dir + viewDir);

		// NdotV should not be negative for visible pixels, but it can happen due to perspective projection and normal mapping
		// In this case normal should be modified to become valid (i.e facing camera) and not cause weird artifacts.
		// but this operation adds few ALU and users may not want it. Alternative is to simply take the abs of NdotV (less correct but works too).
		// Following define allow to control this. Set it to 0 if ALU is critical on your platform.
		// This correction is interesting for GGX with SmithJoint visibility function because artifacts are more visible in this case due to highlight edge of rough surface
		// Edit: Disable this code by default for now as it is not compatible with two sided lighting used in SpeedTree.
		#define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0

		#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
			// The amount we shift the normal toward the view vector is defined by the dot product.
			half shiftAmount = dot(normal, viewDir);
			normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
			// A re-normalization should be applied here but as the shift is small we don't do it to save ALU.
			//normal = normalize(normal);

			half nv = max(0,dot(normal, viewDir)); // TODO: this saturate should no be necessary here
		#else
			half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
		#endif

		half NoL = dot(normal, light.dir);

		half nl = max(0, NoL);
		nl = ScaleDiffuse(nl, skinMask);

		half nh = max(0, dot(normal, halfDir));

		half lv = max(0, dot(light.dir, viewDir));
		half lh = max(0, dot(light.dir, halfDir));


		half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;

		// Specular term
		// HACK: theoretically we should divide diffuseTerm by Pi and not multiply specularTerm!
		// BUT 1) that will make shader look significantly darker than Legacy ones
		// and 2) on engine side "Non-important" lights have to be divided by Pi too in cases when they are injected into ambient SH
		half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
		#if UNITY_BRDF_GGX
			half V = SmithJointGGXVisibilityTerm(nl, nv, roughness);
			half D = GGXTerm(nh, roughness);
		#else
			// Legacy
			half V = SmithBeckmannVisibilityTerm(nl, nv, roughness);
			half D = NDFBlinnPhongNormalizedTerm(nh, PerceptualRoughnessToSpecPower(perceptualRoughness));
		#endif

		//half specularTerm = pow(V*D,2) * UNITY_PI ; // Torrance-Sparrow model, Fresnel is applied later
		half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later

		#   ifdef UNITY_COLORSPACE_GAMMA
		specularTerm = sqrt(max(1e-4h, specularTerm));
		#   endif

		// specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
		specularTerm = max(0, specularTerm * nl);
		//#if defined(_SPECULARHIGHLIGHTS_OFF)
		//    specularTerm = 0.0;
		//#endif

		// surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
		half surfaceReduction;
		#   ifdef UNITY_COLORSPACE_GAMMA
		surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
		#   else
		surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
		#   endif

		// To provide true Lambert lighting, we need to be able to kill specular completely.
		specularTerm *= any(specColor) ? 1.0 : 0.0;

		half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
		//half grazingTerm = (1 - oneMinusReflectivity);
		half surfaceNL = min(NoL + 1, 1);
		half3 color = diffColor * (gi.diffuse + light.color * diffuseTerm)
		+ specularTerm * light.color * FresnelTerm(specColor, lh)
		//nh:背光金属暗一些 nv:突出焦点
		+ surfaceReduction * gi.specular * FresnelLerp(specColor, grazingTerm, nv)*surfaceNL;
		return half4(color, 1);
	}

	half4 BRDF1_Unity_PBS_LightMap(half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi, half skinMask,half3 lightmapColor)
	{
		//return half4(light.color, 1);
		half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
		half3 halfDir = Unity_SafeNormalize(light.dir + viewDir);

		// NdotV should not be negative for visible pixels, but it can happen due to perspective projection and normal mapping
		// In this case normal should be modified to become valid (i.e facing camera) and not cause weird artifacts.
		// but this operation adds few ALU and users may not want it. Alternative is to simply take the abs of NdotV (less correct but works too).
		// Following define allow to control this. Set it to 0 if ALU is critical on your platform.
		// This correction is interesting for GGX with SmithJoint visibility function because artifacts are more visible in this case due to highlight edge of rough surface
		// Edit: Disable this code by default for now as it is not compatible with two sided lighting used in SpeedTree.
		#define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0

		#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
			// The amount we shift the normal toward the view vector is defined by the dot product.
			half shiftAmount = dot(normal, viewDir);
			normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
			// A re-normalization should be applied here but as the shift is small we don't do it to save ALU.
			//normal = normalize(normal);

			half nv = saturate(dot(normal, viewDir)); // TODO: this saturate should no be necessary here
		#else
			half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
		#endif

		half nl = max(0, dot(normal, light.dir));
		nl = ScaleDiffuse(nl, skinMask);

		half nh = max(0, dot(normal, halfDir));

		half lv = max(0, dot(light.dir, viewDir));
		half lh = max(0, dot(light.dir, halfDir));

		// Diffuse term
		half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;

		// Specular term
		// HACK: theoretically we should divide diffuseTerm by Pi and not multiply specularTerm!
		// BUT 1) that will make shader look significantly darker than Legacy ones
		// and 2) on engine side "Non-important" lights have to be divided by Pi too in cases when they are injected into ambient SH
		half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
		#if UNITY_BRDF_GGX
			half V = SmithJointGGXVisibilityTerm(nl, nv, roughness);
			half D = GGXTerm(nh, roughness);
		#else
			// Legacy
			half V = SmithBeckmannVisibilityTerm(nl, nv, roughness);
			half D = NDFBlinnPhongNormalizedTerm(nh, PerceptualRoughnessToSpecPower(perceptualRoughness));
		#endif

		//half specularTerm = pow(V*D,2) * UNITY_PI ; // Torrance-Sparrow model, Fresnel is applied later
		half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later

		#   ifdef UNITY_COLORSPACE_GAMMA
		specularTerm = sqrt(max(1e-4h, specularTerm));
		#   endif

		// specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
		specularTerm = max(0, specularTerm * nl);
		//#if defined(_SPECULARHIGHLIGHTS_OFF)
		//    specularTerm = 0.0;
		//#endif

		// surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
		half surfaceReduction;
		#   ifdef UNITY_COLORSPACE_GAMMA
		surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
		#   else
		surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
		#   endif

		// To provide true Lambert lighting, we need to be able to kill specular completely.
		specularTerm *= any(specColor) ? 1.0 : 0.0;

		//half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
		half grazingTerm = (1 - oneMinusReflectivity);


		half3 color = diffColor * (lightmapColor*_LightmapScale + light.color * diffuseTerm*(1- _LightmapScale))

		+ specularTerm * light.color * FresnelTerm(specColor, lh)
		+ grazingTerm * gi.specular * FresnelLerp(specColor, surfaceReduction, nv * smoothness) ;
		//return fixed4(gi.diffuse,1);
		return half4(color, 1);
	}

	half4 BRDF1_Unity_PBS_SSS (half3 baseColor,half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi)
	{
		//return half4(light.color, 1);
		half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
		half3 halfDir = Unity_SafeNormalize (light.dir + viewDir);

		// NdotV should not be negative for visible pixels, but it can happen due to perspective projection and normal mapping
		// In this case normal should be modified to become valid (i.e facing camera) and not cause weird artifacts.
		// but this operation adds few ALU and users may not want it. Alternative is to simply take the abs of NdotV (less correct but works too).
		// Following define allow to control this. Set it to 0 if ALU is critical on your platform.
		// This correction is interesting for GGX with SmithJoint visibility function because artifacts are more visible in this case due to highlight edge of rough surface
		// Edit: Disable this code by default for now as it is not compatible with two sided lighting used in SpeedTree.
		#define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0

		#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
			// The amount we shift the normal toward the view vector is defined by the dot product.
			half shiftAmount = dot(normal, viewDir);
			normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
			// A re-normalization should be applied here but as the shift is small we don't do it to save ALU.
			//normal = normalize(normal);

			half nv = max(0, dot(normal, viewDir)); // TODO: this saturate should no be necessary here
		#else
			half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
		#endif

		half nl = max(0, dot(normal, light.dir));

		half nh = max(0, dot(normal, halfDir));

		half lv = max(0, dot(light.dir, viewDir));
		half lh = max(0, dot(light.dir, halfDir));

		// Diffuse term
		half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;

		// Specular term
		// HACK: theoretically we should divide diffuseTerm by Pi and not multiply specularTerm!
		// BUT 1) that will make shader look significantly darker than Legacy ones
		// and 2) on engine side "Non-important" lights have to be divided by Pi too in cases when they are injected into ambient SH
		half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
		#if UNITY_BRDF_GGX
			half V = SmithJointGGXVisibilityTerm (nl, nv, roughness);
			half D = GGXTerm (nh, roughness);
		#else
			// Legacy
			half V = SmithBeckmannVisibilityTerm (nl, nv, roughness);
			half D = NDFBlinnPhongNormalizedTerm (nh, PerceptualRoughnessToSpecPower(perceptualRoughness));
		#endif

		//half specularTerm = pow(V*D,2) * UNITY_PI ; // Torrance-Sparrow model, Fresnel is applied later
		half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later

		#   ifdef UNITY_COLORSPACE_GAMMA
		specularTerm = sqrt(max(1e-4h, specularTerm));
		#   endif

		// specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
		specularTerm = max(0, specularTerm * nl);
		//#if defined(_SPECULARHIGHLIGHTS_OFF)
		//    specularTerm = 0.0;
		//#endif

		// surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
		half surfaceReduction;
		#   ifdef UNITY_COLORSPACE_GAMMA
		surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
		#   else
		surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
		#   endif

		// To provide true Lambert lighting, we need to be able to kill specular completely.
		specularTerm *= any(specColor) ? 1.0 : 0.0;

		//half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
		half grazingTerm = (1 - oneMinusReflectivity);
		gi.diffuse = gi.diffuse * 0.7 + gi.diffuse * max(normal.y, 0) * 0.4;
		half3 color = diffColor * (gi.diffuse + light.color * diffuseTerm) * (nv*0.6 + 0.4)
		//高光部分乘以nv突出焦点,*0.8简单粗暴防止高光过爆
		+ specularTerm * light.color * FresnelTerm(specColor, lh)*nv*0.8
		+ grazingTerm * gi.specular * FresnelLerp(specColor, surfaceReduction, nv * smoothness)*nv* smoothness;

		//half3 color = diffColor * (gi.diffuse + light.color * diffuseTerm)
		//	+ specularTerm * light.color * FresnelTerm(specColor, lh)
		//	+ surfaceReduction * gi.specular * FresnelLerp(specColor, grazingTerm, nv);
		//+ grazingTerm * gi.specular * FresnelLerp(specColor, surfaceReduction, nv * smoothness);

		half mask = pow((1 - length(baseColor)), _sssMainTexPower);
		color.rgb += SSSTrans(light.dir, viewDir, normal, mask);
		return half4(color, 1);
	}

	half4 BRDF1_Unity_PBS_Aniso(half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi,half3 tangent, half3 anisoTex)
	{

		half3 halfDir = normalize(light.dir + viewDir);


		#define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0

		#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
			// The amount we shift the normal toward the view vector is defined by the dot product.
			half shiftAmount = dot(normal, viewDir);
			normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
			// A re-normalization should be applied here but as the shift is small we don't do it to save ALU.
			//normal = normalize(normal);

			half nv = max(0, dot(normal, viewDir)); // TODO: this saturate should no be necessary here
		#else
			half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
		#endif

		half nl = max(0, dot(normal, light.dir));
		half nh = max(0, dot(normal, halfDir));

		half lv = max(0, dot(light.dir, viewDir));
		half lh = max(0, dot(light.dir, halfDir));

		half a = any(specColor) ? 1.0 : 0.0;

		half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);


		// Diffuse term
		half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;


		half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
		#if UNITY_BRDF_GGX
			half V = SmithJointGGXVisibilityTerm(nl, nv, roughness);
			half D = GGXTerm(nh, roughness);
		#else
			// Legacy
			half V = SmithBeckmannVisibilityTerm(nl, nv, roughness);
			half D = NDFBlinnPhongNormalizedTerm(nh, PerceptualRoughnessToSpecPower(perceptualRoughness));
		#endif

		//half specularTerm = pow(V*D,2) * UNITY_PI ; // Torrance-Sparrow model, Fresnel is applied later
		half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later

		#   ifdef UNITY_COLORSPACE_GAMMA
		specularTerm = sqrt(max(1e-4h, specularTerm));
		#   endif

		// specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
		specularTerm = max(0, specularTerm * nl);
		//#if defined(_SPECULARHIGHLIGHTS_OFF)
		//    specularTerm = 0.0;
		//#endif

		// surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
		half surfaceReduction;
		#   ifdef UNITY_COLORSPACE_GAMMA
		surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
		#   else
		surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
		#   endif
		//half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
		half grazingTerm = (1 - oneMinusReflectivity);

		specularTerm *= a;

		gi.diffuse = gi.diffuse * 0.7 + gi.diffuse * max(normal.y, 0) * 0.4;
		half3 color = diffColor * (gi.diffuse + light.color * diffuseTerm) * (nv*0.6 + 0.4)
		//高光部分乘以nv突出焦点,*0.8简单粗暴防止高光过爆
		+ specularTerm * light.color * FresnelTerm(specColor, lh)*nv*0.8
		+ grazingTerm * gi.specular * FresnelLerp(specColor, surfaceReduction, nv * smoothness)*nv* smoothness;


		//half3 color = diffColor * (gi.diffuse + light.color * diffuseTerm) * (nv*0.6 + 0.4)
		//+ specularTerm * light.color * FresnelTerm(specColor, lh)
		//+ grazingTerm * gi.specular * FresnelLerp(specColor, surfaceReduction, nv * smoothness);

		half shiftTex = anisoTex.g - 0.5;
		half3 T = -normalize(cross(normal, tangent));

		half3 t1 = ShiftTangent(T, normal, _ShiftPower.x + shiftTex);
		half3 t2 = ShiftTangent(T, normal, _ShiftPower.z + shiftTex);

		half3 spec = _SpecularColor0 * StrandSpecular(halfDir,t1, _ShiftPower.y)*_Color ;

		spec = spec + _SpecularColor1 * anisoTex.b * StrandSpecular(halfDir,t2, _ShiftPower.w);


		spec = spec*a * 2 * light.color*nl*anisoTex.r;

		return fixed4(color+spec, 1);
	}

	half4 BRDF2_Unity_PBS (half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi, half skinMask)
	{
		half3 halfDir = Unity_SafeNormalize (light.dir + viewDir);

		half nl = saturate(dot(normal, light.dir));
		nl = ScaleDiffuse(nl, skinMask);
		half nh = saturate(dot(normal, halfDir));
		half nv = saturate(dot(normal, viewDir));
		half lh = saturate(dot(light.dir, halfDir));

		// Specular term
		half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
		half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

		#if UNITY_BRDF_GGX

			// GGX Distribution multiplied by combined approximation of Visibility and Fresnel
			// See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
			// https://community.arm.com/events/1155
			half a = roughness;
			half a2 = a*a;

			half d = nh * nh * (a2 - 1.h) + 1.00001h;
			#ifdef UNITY_COLORSPACE_GAMMA
				// Tighter approximation for Gamma only rendering mode!
				// DVF = sqrt(DVF);
				// DVF = (a * sqrt(.25)) / (max(sqrt(0.1), lh)*sqrt(roughness + .5) * d);
				half specularTerm = a / (max(0.32h, lh) * (1.5h + roughness) * d);
			#else
				half specularTerm = a2 / (max(0.1h, lh*lh) * (roughness + 0.5h) * (d * d) * 4);
			#endif

			// on mobiles (where half actually means something) denominator have risk of overflow
			// clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
			// sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
			#if defined (SHADER_API_MOBILE)
				specularTerm = specularTerm - 1e-4h;
			#endif

		#else

			// Legacy
			half specularPower = PerceptualRoughnessToSpecPower(perceptualRoughness);
			// Modified with approximate Visibility function that takes roughness into account
			// Original ((n+1)*N.H^n) / (8*Pi * L.H^3) didn't take into account roughness
			// and produced extremely bright specular at grazing angles

			half invV = lh * lh * smoothness + perceptualRoughness * perceptualRoughness; // approx ModifiedKelemenVisibilityTerm(lh, perceptualRoughness);
			half invF = lh;

			half specularTerm = ((specularPower + 1) * pow (nh, specularPower)) / (8 * invV * invF + 1e-4h);

			#ifdef UNITY_COLORSPACE_GAMMA
				specularTerm = sqrt(max(1e-4h, specularTerm));
			#endif

		#endif

		#if defined (SHADER_API_MOBILE)
			specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
		#endif
		//#if defined(_SPECULARHIGHLIGHTS_OFF)
		//    specularTerm = 0.0;
		//#endif

		// surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(realRoughness^2+1)

		// 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
		// 1-x^3*(0.6-0.08*x)   approximation for 1/(x^4+1)
		#ifdef UNITY_COLORSPACE_GAMMA
			half surfaceReduction = 0.28;
		#else
			half surfaceReduction = (0.6-0.08*perceptualRoughness);
		#endif

		surfaceReduction = 1.0 - roughness*perceptualRoughness*surfaceReduction;

		half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
		half3 color =   (diffColor + specularTerm * specColor) * light.color * nl
		+ gi.diffuse * diffColor
		+ surfaceReduction * gi.specular * FresnelLerpFast (specColor, grazingTerm, nv);

		return half4(color, 1);
	}

	half3 BRDF3_Direct(half3 diffColor, half3 specColor, half rlPow4, half smoothness)
	{
		half LUT_RANGE = 16.0; // must match range in NHxRoughness() function in GeneratedTextures.cpp
		// Lookup texture to save instructions
		half specular = tex2D(unity_NHxRoughness, half2(rlPow4, SmoothnessToPerceptualRoughness(smoothness))).UNITY_ATTEN_CHANNEL * LUT_RANGE;
		//#if defined(_SPECULARHIGHLIGHTS_OFF)
		//    specular = 0.0;
		//#endif

		return diffColor + specular * specColor;
	}

	half3 BRDF3_Indirect(half3 diffColor, half3 specColor, UnityIndirect indirect, half grazingTerm, half fresnelTerm)
	{
		half3 c = indirect.diffuse * diffColor;
		c += indirect.specular * lerp (specColor, grazingTerm, fresnelTerm);
		return c;
	}

	// Old school, not microfacet based Modified Normalized Blinn-Phong BRDF
	// Implementation uses Lookup texture for performance
	//
	// * Normalized BlinnPhong in RDF form
	// * Implicit Visibility term
	// * No Fresnel term
	//
	// TODO: specular is too weak in Linear rendering mode
	half4 BRDF3_Unity_PBS (half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi, half skinMask)
	{
		half3 reflDir = reflect (viewDir, normal);

		half nl = saturate(dot(normal, light.dir));
		nl = ScaleDiffuse(nl, skinMask);
		half nv = saturate(dot(normal, viewDir));

		// Vectorize Pow4 to save instructions
		half2 rlPow4AndFresnelTerm = Pow4 (half2(dot(reflDir, light.dir), 1-nv));  // use R.L instead of N.H to save couple of instructions
		half rlPow4 = rlPow4AndFresnelTerm.x; // power exponent must match kHorizontalWarpExp in NHxRoughness() function in GeneratedTextures.cpp
		half fresnelTerm = rlPow4AndFresnelTerm.y;

		half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));

		half3 color = BRDF3_Direct(diffColor, specColor, rlPow4, smoothness);
		color *= light.color * nl;
		color += BRDF3_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);

		return half4(color, 1);
	}

	VertexOutputForwardBase vertForwardBase(VertexInput v)
	{
		UNITY_SETUP_INSTANCE_ID(v);
		VertexOutputForwardBase o;
		UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBase, o);
		UNITY_TRANSFER_INSTANCE_ID(v, o);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

		//#if WAVE_FLAG
		//	float4 objPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
		//	float4 node_2346 = _Time;
		//	float4 vColor = v.vertexColor;
		//	v.vertex.xyz += (_WaveFlagWindDir.rgb * vColor.r * sin(((vColor.r + node_2346.g + ((mul(unity_ObjectToWorld, v.vertex).r - objPos.r) * _WaveFlagDistinceScale)) * _WaveFlagSpeed)) * _WaveFlagWindStrength);
		//
		//#endif
		//
		//vertSnow(v.vertex.xyz, v.normal);

		float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
		
		float3 normalWorld = UnityObjectToWorldNormal(v.normal);


		//o.pos = UnityObjectToClipPos(v.vertex);
		o.pos = mul(UNITY_MATRIX_VP, posWorld);

		o.tex = TexCoords(v);
		
		o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
		#if CARDTOOL_CHARACTER_BODY
			o.CarToolVertexNormal = normalize(
			mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);

		#endif

		#if UNITY_REQUIRE_FRAG_WORLDPOS

			#if UNITY_PACK_WORLDPOS_WITH_TANGENT
				o.tangentToWorldAndPackedData[0].w = posWorld.x;
				o.tangentToWorldAndPackedData[1].w = posWorld.y;
				o.tangentToWorldAndPackedData[2].w = posWorld.z;
			#else
				o.posWorld = posWorld.xyz;
			#endif
			#if SCENE_FLUOROSCOPY
				o.screenPos = ComputeScreenPos(o.pos);
			#endif

			#ifdef _NORMALMAP_OFF
				o.tangentToWorldAndPackedData[0].xyz = 0;
				o.tangentToWorldAndPackedData[1].xyz = 0;
				o.tangentToWorldAndPackedData[2].xyz = normalWorld;
			#else
				float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

				float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
				o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
				o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
				o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];

			#endif

		#endif


		//We need this for shadow receving
		UNITY_TRANSFER_LIGHTING(o, v.uv1);

		o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);

		//UNITY_TRANSFER_FOG(o, o.pos);
		return o;
	}

	float3 CalculateSinglePointLightBRDF(float3 last_color, float3 texColor, float3 pointLightPos, float3 worldPos, half4 color, float3 viewdir, float3 normal, float3 range)
	{
	}
	inline float pbrLiteComputePointLightAttenuation(float3 lightDir, float range2)
	{
		float dist0 = length(lightDir);
		float attenuation = saturate(1.0 - dist0 * dist0 / range2);
		float a2 = attenuation * attenuation;
		float a3 = a2 * attenuation;

		return (attenuation + a2 + a3)*0.5;
	}
	LWRP_Light AdditionalLightInfo[4];
	void GetAdditionalLight(float3 positionWS)
	{

		float4 toLightX = unity_4LightPosX0 - positionWS.x;
		float4 toLightY = unity_4LightPosY0 - positionWS.y;
		float4 toLightZ = unity_4LightPosZ0 - positionWS.z;
		// squared lengths
		float4 lengthSq = 0;
		lengthSq += toLightX * toLightX;
		lengthSq += toLightY * toLightY;
		lengthSq += toLightZ * toLightZ;
		lengthSq = max(lengthSq, 0.000001);
		float4 atten = (1.0 / (1.0 + lengthSq * unity_4LightAtten0)) ;


		half3 pos = half3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
		half3 dir = pos - positionWS;
		AdditionalLightInfo[0].lightPos.xyz = pos;
		AdditionalLightInfo[0].direction = normalize(dir);
		//AdditionalLightInfo[0].distanceAttenuation = pbrLiteComputePointLightAttenuation(dir, ranges.x);
		AdditionalLightInfo[0].distanceAttenuation = unity_4LightAtten0.x  > 0.00001 ? atten.x : 0;
		AdditionalLightInfo[0].shadowAttenuation = 1;
		AdditionalLightInfo[0].color = unity_LightColor[0].xyz;



		pos = half3(unity_4LightPosX0.y, unity_4LightPosY0.y, unity_4LightPosZ0.y);
		dir = pos - positionWS;
		AdditionalLightInfo[1].lightPos.xyz = pos;
		AdditionalLightInfo[1].direction = normalize(dir);
		//AdditionalLightInfo[1].distanceAttenuation = pbrLiteComputePointLightAttenuation(dir, ranges.y);
		AdditionalLightInfo[1].distanceAttenuation = unity_4LightAtten0.y > 0.00001 ? atten.y : 0;
		AdditionalLightInfo[1].shadowAttenuation = 1;
		AdditionalLightInfo[1].color = unity_LightColor[1].xyz;



		pos = half3(unity_4LightPosX0.z, unity_4LightPosY0.z, unity_4LightPosZ0.z);
		dir = pos - positionWS;
		AdditionalLightInfo[2].lightPos.xyz = pos;
		AdditionalLightInfo[2].direction = normalize(dir);
		//AdditionalLightInfo[2].distanceAttenuation = pbrLiteComputePointLightAttenuation(dir, ranges.z);
		AdditionalLightInfo[2].distanceAttenuation = unity_4LightAtten0.z > 0.00001 ? atten.z : 0;
		AdditionalLightInfo[2].shadowAttenuation = 1;
		AdditionalLightInfo[2].color = unity_LightColor[2].xyz;



		pos = half3(unity_4LightPosX0.w, unity_4LightPosY0.w, unity_4LightPosZ0.w);
		dir = pos - positionWS;
		AdditionalLightInfo[3].lightPos.xyz = pos;
		AdditionalLightInfo[3].direction = normalize(dir);
		//AdditionalLightInfo[3].distanceAttenuation = pbrLiteComputePointLightAttenuation(dir, ranges.w);
		AdditionalLightInfo[3].distanceAttenuation = unity_4LightAtten0.w > 0.00001 ? atten.w : 0;
		AdditionalLightInfo[3].shadowAttenuation = 1;
		AdditionalLightInfo[3].color = unity_LightColor[3].xyz;



	}


	float3 ComputerRealTimePointLightBRDF(float3 last_color, float3 texColor, float3 worldPos, float3 viewdir, float3 normal)
	{
		GetAdditionalLight(worldPos);





		//last_color += Shade4PointLights(
		//	unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		//	unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		//	unity_4LightAtten0, worldPos, normal);
		return last_color;
		//pointCol = pow(HighPointLightCol4 * PointLightRangeIntansity[4].y, 2.2)*powSceneBrightness ;
		//dir = PointLightPos[4].xyz - worldPos;
		//hitw = pow(max(0.0f, 1 - (length(dir) / PointLightRangeIntansity[4].x)), 1.5);
		//finalCol = test * pointCol*hitw;
		//last_color += finalCol.rgb;

		//pointCol = pow(HighPointLightCol5 * PointLightRangeIntansity[5].y, 2.2)*powSceneBrightness ;
		//dir = PointLightPos[5].xyz - worldPos;
		//hitw = pow(max(0.0f, 1 - (length(dir) / PointLightRangeIntansity[5].x)), 1.5);
		//finalCol = test * pointCol*hitw;
		//last_color += finalCol.rgb;

		//pointCol = pow(HighPointLightCol6 * PointLightRangeIntansity[6].y, 2.2)*powSceneBrightness ;
		//dir = PointLightPos[6].xyz - worldPos;
		//hitw = pow(max(0.0f, 1 - (length(dir) / PointLightRangeIntansity[6].x)), 1.5);
		//finalCol = test * pointCol*hitw;
		//last_color += finalCol.rgb;

		//pointCol = pow(HighPointLightCol7 * PointLightRangeIntansity[7].y, 2.2)*powSceneBrightness ;
		//dir = PointLightPos[7].xyz - worldPos;
		//hitw = pow(max(0.0f, 1 - (length(dir) / PointLightRangeIntansity[7].x)), 1.5);
		//finalCol = test * pointCol*hitw;
		//last_color += finalCol.rgb;

		return last_color;


		//// 计算第一个光源
		//ret += CalculateSinglePointLightBRDF(last_color, texColor, PointLightPos[0].xyz, worldPos, HighPointLightCol0, viewdir, normal, PointLightRangeIntansity[0].xyz);
		//// 计算第二个光源
		//ret += CalculateSinglePointLightBRDF(last_color, texColor, PointLightPos[1].xyz, worldPos, HighPointLightCol1, viewdir, normal, PointLightRangeIntansity[1].xyz);
		//// 计算第三个光源
		//ret += CalculateSinglePointLightBRDF(last_color, texColor, PointLightPos[2].xyz, worldPos, HighPointLightCol2, viewdir, normal, PointLightRangeIntansity[2].xyz);
		//// 计算第四个光源
		//ret += CalculateSinglePointLightBRDF(last_color, texColor, PointLightPos[3].xyz, worldPos, HighPointLightCol3, viewdir, normal, PointLightRangeIntansity[3].xyz);
		//return last_color + ret;
	}





























	#if BODY_WATER
		// 身体水shader计算，返回子表面反射颜色
		half3 BodyWater(VertexOutputForwardBase i, inout FragmentCommonData s, LWRP_Light lwrp_light)
		{
			half3 sss = half3(0, 0, 0);

			float4 waterPannerMask = tex2D(_WaterPannerMask, i.tex.xy);
			float4 waterPowerMask = tex2D(_WaterPowerMask, i.tex.xy);


			float4 currTime = _Time + _TimeEditor;

			float2 waterOrgUV = TRANSFORM_TEX(i.tex.zw, _WaterBumpMap);
			float2 waterUV = waterOrgUV;
			waterUV.x -= (currTime.y * waterPannerMask.r + sin(currTime.y + waterOrgUV.y) * 0.1 * waterPowerMask.r) * _WaterSpeed;
			float2 waterUV2 = waterOrgUV;
			waterUV2.x -= (currTime.y * waterPannerMask.r + sin(currTime.y + waterOrgUV.y) * 0.2 * waterPowerMask.r) * _WaterSpeed * 0.8;
			half4 waterBumpMap1 = tex2D(_WaterBumpMap, waterUV);
			half4 waterBumpMap2 = tex2D(_WaterBumpMap, waterUV2);
			half4 waterBumpMap = lerp(waterBumpMap1, waterBumpMap2, cos(_Time.y + waterBumpMap2.y) * 0.5);
			half3 waterNormail = PerPixelWorldNormal(waterBumpMap, i.tangentToWorldAndPackedData);
			// 重新计算法线
			s.normalWorld = lerp(s.normalWorld, waterNormail, waterPowerMask.r * 0.6);
			// 重新计算水的金属粗糙度
			s.metallic = lerp(s.metallic, _WaterMetallic, waterPowerMask.r);
			s.smoothness = lerp(s.smoothness, _WaterGlossiness, waterPowerMask.r);

			// 散射控制图
			half4 transMask = tex2D(_TransMask, i.tex.xy);

			half NdotL = 1 - dot(s.normalWorld, lwrp_light.direction);
			sss = SSSTrans(lwrp_light.direction, -s.eyeVec, s.normalWorld, transMask) * min(0.2, NdotL);

			return sss;
		}
	#endif




	sampler2D _FireTex;
	float4 _FireTex_ST;
	half _FresnelInt;
	float4 _Firecolor01,_Firecolor02;
	half _BlackMask,_FireSpeed,_Fresnelhurt;

	half4 fragForwardBaseInternal(VertexOutputForwardBase i)
	{
		FRAGMENT_SETUP(s)
		UNITY_SETUP_INSTANCE_ID(i);
		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

		#if _MONSTER_USING_ALPHA_TEST
			half4 tex = tex2D(_MainTex, i.tex.xy);
			clip(tex.a - _Cutoff);
		#endif
		half atten = 0;
		half3 lm = half3(0.0, 0.0, 0.0);
		LWRP_Light lwrp_light = LWRP_GetMainLight();
		LWRP_Light lwrp_player_light = LWRP_GetPlayerMainLight();
		#ifdef LIGHTMAP_ON
			#	ifdef LIGHTMAP_SHADOW_MIXING
			half4 shadowMask = UNITY_SAMPLE_TEX2D(unity_ShadowMask, i.tex.zw);
			shadowMask = lerp(shadowMask.r, 1, _LightShadowData.r);
			atten = min(LIGHT_ATTENUATION(i), shadowMask.r + shadowMask.g);

			float zDist = dot(_WorldSpaceCameraPos - s.posWorld, UNITY_MATRIX_V[2].xyz);
			float fadeDist = UnityComputeShadowFadeDistance(s.posWorld, zDist);
			half realtimeToBakedShadowFade = UnityComputeShadowFade(fadeDist);
			atten = min(atten, shadowMask);
			#	else
			UNITY_LIGHT_ATTENUATION(tatten, i, s.posWorld);
			atten = tatten;

			#	endif
			lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.tex.zw));
			//lwrp_light.color *= lm;
			//return lm.rgbb;
		#else
			UNITY_LIGHT_ATTENUATION(tatten, i, s.posWorld);
			atten = tatten;
		#endif
		half occlusion = 1.0f;
		#if _METALLICGLOSSMAP
			occlusion = Occlusion(i.tex.xy);
		#endif
		//return DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.tex.zw)).rgbb;
		// 获取LWRP的灯光信息
		// 设置影子信息
		//lwrp_light.shadowAttenuation = atten;

		//判断和主角的距离
		half playerDis = PlayerLength(s.posWorld);
		//把距离转换为0-1
		half dis01 = min(1, playerDis / Globle_FogHeightFar.w);
		// 
		#if _DECAL_MAP
			#if _GLOSS_FROM_ALBEDO_A
			#else
				s.metallic = lerp(s.metallic, _DetailMetallic, s.DecalMapWeight * 0.7 * _DetailCover);
				s.smoothness = lerp(s.smoothness, _DetailGlossiness, s.DecalMapWeight * 0.7 * _DetailCover);

				s.metallic = lerp(s.metallic, _DetailMetallic, (1 - s.DecalMapWeight) * 0.7 * _InvDetailCover);
				s.smoothness = lerp(s.smoothness, _DetailGlossiness, (1 - s.DecalMapWeight) * 0.7 * _InvDetailCover);
			#endif
		#endif
		// 使用潮湿度权重设置
		#if USING_HUMID_WEIGHT
			s.metallic = lerp(s.metallic, _WaterMetallic, _HumidWeight);
			s.smoothness = lerp(s.smoothness, _WaterGlossiness, _HumidWeight);
		#endif

		// 计算冰冻效果的金属粗糙
		#if BODY_ICE
			half ice_weight = GetBodyIceMapWeight(i.tex);
			//return ice_weight;
			s.metallic = lerp(s.metallic, _IceMetallic, ice_weight * 0.7);
			s.smoothness = lerp(s.smoothness, _IceGlossiness, ice_weight * 0.7);
		#endif
		//高光强度衰减1-0
		//s.specColor *= max(0, (1 - dis01 * 1.5));
		// 初始化LWRP的影子信息
		// 计算身体水效果
		#if BODY_WATER
			half3 body_sss = BodyWater(i, s, lwrp_light);
			//return i.tex.zwzw;
			//return s.normalWorld.rgbb;
		#endif
		LWRP_BRDFData brdfData;
		LWRP_InitializeBRDFData(s.albedo, s.metallic, s.specColor, s.smoothness, s.alpha, brdfData);

		#ifdef LIGHTMAP_ON
			fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, i.tex.zw);
			//return bakedDirTex;
			half bake_weight = 1 - (s.metallic * 0.7);
			brdfData.diffuse += DecodeDirectionalLightmap(lm, bakedDirTex, s.normalWorld) * s.albedo * bake_weight;

		#endif
		s.bakedGI = LWRP_SampleSHPixel(i.ambientOrLightmapUV.rgb, s.normalWorld) + lm;
		half3 shadowColor = lerp(_PBRShadowColor.rgb, _PBRFringeShadowColor.rgb, atten) * (1.0h - atten) + atten;




		#if SHADER_SHOW_DEBUG
			if (_DebugView < 7)
			return half4(ShowDebugColor(s, atten, occlusion), 1);
		#endif

		//s.bakedGI *= s.albedo.rgb ;
		//return s.bakedGI.rgbb;
		//s.bakedGI.rgb = ComputerRealTimePointLightBRDF(s.bakedGI.rgb, s.albedo, s.posWorld, -s.eyeVec, s.normalWorld);
		//return occlusion;
		//occlusion = 1;
		#ifdef LIGHTMAP_ON
			float lm_lit =min(1, max(lm.r, max(lm.r, lm.b)));
			occlusion = lerp(lm_lit * occlusion, occlusion, 0.5);
		#endif
	
		// 计算环境颜色
		half3 color = LWRP_GlobalIllumination(brdfData, s.bakedGI, occlusion, s.normalWorld, -s.eyeVec);
	
		//return occlusion;
		// 叠加水的散射颜色
		#if BODY_WATER
			color += body_sss;
		#endif
		//return brdfData.diffuse.rgbb;
		
		//color += max(lm.r, max(lm.g, lm.b)) * s.albedo ;
		half3 spec_color = 0;
		half3 diff_color = 0;
		half3 totall_spec_color = 0;
		half3 totall_diff_color = 0;
		LWRP_LightingPhysicallyBased(brdfData, lwrp_light, s.normalWorld, -s.eyeVec, spec_color, diff_color);
		totall_spec_color += spec_color;
		totall_diff_color += diff_color;
		#ifdef SCENE_LIGHTING
			LWRP_LightingPhysicallyBased(brdfData, lwrp_player_light, s.normalWorld, -s.eyeVec, spec_color, diff_color);

			totall_spec_color += spec_color * 0.5f;
		#endif

		#if !LIGHTMAP_ON
			GetAdditionalLight(s.posWorld.xyz);
			half3 spec_color1 = 0;
			half3 diff_color1 = 0;
			LWRP_LightingPhysicallyBased(brdfData, AdditionalLightInfo[0], s.normalWorld, -s.eyeVec, spec_color1, diff_color1);

			totall_spec_color += spec_color1;
			totall_diff_color += diff_color1;
			LWRP_LightingPhysicallyBased(brdfData, AdditionalLightInfo[1], s.normalWorld, -s.eyeVec, spec_color, diff_color);

			totall_spec_color += spec_color;
			totall_diff_color += diff_color;
			LWRP_LightingPhysicallyBased(brdfData, AdditionalLightInfo[2], s.normalWorld, -s.eyeVec, spec_color, diff_color);

			totall_spec_color += spec_color;
			totall_diff_color += diff_color;
		#endif
		// 漫反射和环境光不能超过1，被Bloom变成灯泡
		//color = min(1,color + max(totall_diff_color,0));硬是把写好的Bloom取消了,内部写的HDR全不能用了
		color = color + max(totall_diff_color,0);


		#if USING_GRAY
			half gray = dot(color.rgb, 1) / 3 * _GrayLit;
			color = lerp(color.rgb, gray.rrr, _GrayWeight);
		#endif


		totall_spec_color *= atten * occlusion;

		#if CHARACTER_EYE

			fixed3 reflectDir = normalize(reflect(-lwrp_light.direction, s.normalWorld));
			fixed3 specular = lwrp_light.color.rgb * pow(saturate(dot(reflectDir, -s.eyeVec)), _EyeIrisSpecularPow) * _EyeIrisSpecularLit * (atten * 0.7 + 0.3);
			fixed4 eyemask = GetEyeIrisSpecularMask(i.tex.xy);
			specular += totall_spec_color;
			// 不能超过1，不然会被Bloom处理成电灯泡
			float sp_lit = max(specular.r, max(specular.g, specular.b)) * eyemask.r;
			color += sp_lit;
			// 不能超过1，不然会被Bloom处理成电灯泡
			color = min(1, color);
			//return sp_lit;
		#else
			color += totall_spec_color;
		#endif
	
		//return (lm * s.albedo).rgbb;

		// 最后一盏灯光是黑光，所以不用处理，Unity不加一个黑光传参有问题
		//color += LWRP_LightingPhysicallyBased(brdfData, AdditionalLightInfo[3], s.normalWorld, -s.eyeVec);

		//return shadowColor.rgbb;

		//return color.rgbb;
		color *= shadowColor;
		// 冰的散射不受影子控制
		#if BODY_ICE
			half iceNdotL = 1 - dot(s.normalWorld, lwrp_light.direction);
			iceNdotL = pow(iceNdotL * 0.5 + 0.5, 2);
			half3 iceSSS = SSSTrans(lwrp_light.direction, -s.eyeVec, s.normalWorld, _IceTransColor, _IceTransLight, 1) * min(0.2, iceNdotL) * ice_weight;
			
			color.rgb += iceSSS;
		#endif

		#if CARDTOOL_CHARACTER_BODY

			#	if CARDTOOL_CHARACTER_BODY_RELEASE
			half4 mask_info = GetCBMask(i.tex.xy);
			half cartoonMask = mask_info.g;
			half cartoonShadowMask = mask_info.b;
			half emissionMask = mask_info.r;
			#	else
			half4 mask_info = GetCombinedMask(i.tex.xy);
			half cartoonMask = mask_info.r;
			half cartoonShadowMask = mask_info.g;
			half emissionMask = mask_info.b;
			#	endif
			half4 shadowTexColor = GetCartoonShadowTex(i.tex.xy);
			half3 cattoomColor = GetCartoon(s,lwrp_light, s.posWorld.xyz, i.CarToolVertexNormal, _CartoonShadowColor * shadowTexColor, atten, cartoonShadowMask);
			// 冰冻部分没有卡通效果
			#	if BODY_ICE
			cartoonMask = lerp(cartoonMask.r,1, ice_weight);
			emissionMask = lerp(emissionMask,0, ice_weight);
			#	endif
			color = lerp(cattoomColor, color, cartoonMask.r);
			color += lerp(s.albedo,_EmissionColor * s.albedo,0.2) * max(_MinEmissionScale, dot(s.normalWorld, -s.eyeVec))*emissionMask;
		#endif


        #if DISSOLVE
			//采样Dissolve Map
			float4 dissolveValue = tex2D(_DissolveMap, i.tex.xy);
			float offsetValue = dissolveValue.r - _DissolveThreshold;
			clip(offsetValue);
			offsetValue += (1 - sign(_DissolveThreshold)) * _DissolveEdge;
			float edgeFactor = 1 - saturate(offsetValue / _DissolveEdge);
			color = lerp(color, _DissolveColor, edgeFactor);
        #endif

		// 受记效果
		#if BODY_HURT
			// half max_light = max(totall_diff_color.r, max(totall_diff_color.g, totall_diff_color.b));
			// half Rim = saturate(dot(s.normalWorld, -s.eyeVec));
			// half emission = saturate(pow(1 - Rim, _GlossHurt.y) * max_light * _GlossHurt.x);
			// color.rgb = lerp(color.rgb, color.rgb + _HurtColor * totall_diff_color, emission);


			float3 worldViewDir = normalize(UnityWorldSpaceViewDir(s.posWorld.xyz));
			float fresnelhurt = pow(1 - saturate( dot(worldViewDir,s.normalWorld)),_Fresnelhurt);
			float3 hurtcolor = fresnelhurt * _OverlayColor.rgb;
			//color.rgb = saturate( lerp(color.rgb, saturate(hurtcolor + color.rgb), _GlossHurt.z));//没bloom了
			color.rgb = lerp(color.rgb, saturate(hurtcolor + color.rgb), _GlossHurt.z);
		#endif
//return float4(color,0);	
		#if SCENE_USING_ALPHA_MASK
			float alpha = max(0,tex2D(_AlphaMaskTex, i.tex.xy).r - _AlphaMaskInv);
			alpha = alpha / (1 - _AlphaMaskInv) * _Color.a;
			//return alpha;
			half4 rc = half4(color, alpha);
			SimulateFog(s.posWorld, rc, playerDis, dis01);
		#else
			half4 rc = half4(color, 0);
			SimulateFog(s.posWorld, rc, playerDis, dis01);
			rc.a = 1;
		#endif
//return rc;			
		// 处理场景透视
		#if SCENE_FLUOROSCOPY
			rc.a = ComputerFormScreenCenterDistance(i.screenPos,0.8,1.2);
		#endif
		
		#if _CILPDISS_ON
			half cilp_weight = tex2D(_IceMaskTex, i.tex.xy).r;
			clip( (1-_Cilpran) - cilp_weight );
			half fireRange = (1-smoothstep(0,_FireRange, (1-_Cilpran) - cilp_weight));
			half4 fireColor = fireRange * _FireColor;
			rc.rgb += fireColor.rgb;
		#endif

		#if _FIREDISS_ON
			float3 viewDir = normalize(UnityWorldSpaceViewDir(s.posWorld));
			half NoV = saturate(dot(s.normalWorld,viewDir));
			half fresnel = pow(1 - abs(NoV),_FresnelInt);
			float firemask = tex2D(_FireTex , i.tex.xy * _FireTex_ST.xy - float2(0,_Time.y * _FireSpeed)).r; 
			float4 fincol = lerp(_Firecolor02,_Firecolor01, firemask)*fresnel;
			float blackmask = (firemask+pow(abs(NoV),_BlackMask));
			rc.rgb = rc.rgb * blackmask + fincol;
		#endif

		return rc;
	}


	half4 fragForwardBase(VertexOutputForwardBase i) : SV_Target   // backward compatibility (this used to be the fragment entry function)
	{

		return fragForwardBaseInternal(i);
	}


	half4 fragForwardAddInternal(VertexOutputForwardAdd i, half4 lightColor, float3 axis, float4 worldSpaceLightPos)
	{

		#ifdef PLAYER_LIGHTING
			FRAGMENT_SETUP_FWDADD(s)

			UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)
			UnityLight light = AdditiveLight(IN_LIGHTDIR_FWDADD(i), atten);
			UnityIndirect noIndirect = ZeroIndirect();

			half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, light, noIndirect, SkinMask(i.tex.xy));

			UNITY_APPLY_FOG_COLOR(i.fogCoord, c.rgb, half4(0, 0, 0, 0)); // fog towards black in additive pass
			return OutputForward(c, s.alpha) * (1 - ImageEffLight);
		#else
			FRAGMENT_SETUP_FWDADD(s)

			UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)
			return atten;
		#endif
		return 0;
	}

	half4 alphaFragForwardAddInternal(VertexOutputForwardAdd i, half4 lightColor, float3 axis, float4 worldSpaceLightPos)
	{
		return 0;
	}

	half4 commonFragForwardAddInternal(VertexOutputForwardAdd i, half4 lightColor, float3 axis, float4 worldSpaceLightPos)
	{
		return 0;
	}

	half4 normalSpecialFragForwardAddInternal(VertexOutputForwardAdd i, half4 lightColor, float3 axis, float4 worldSpaceLightPos)
	{
		return 0;
	}

	half4 fragForwardAdd(VertexOutputForwardAdd i, half4 lightColor, float3 axis, float4 worldSpaceLightPos) : SV_Target     // backward compatibility (this used to be the fragment entry function)
	{
		return fragForwardAddInternal(i,lightColor, axis, worldSpaceLightPos);
	}

#endif // _KTSS_BRDF_CGINC_
