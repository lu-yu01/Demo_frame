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


// 获取风设置
WindSettings PopulateWindSettings(in float strength, float speed, float4 direction, float swinging, float mask, float randObject, float randVertex, float randObjectStrength, float gustStrength, float gustFrequency)
{
	WindSettings s = (WindSettings)0;

	//Apply WindZone strength
	if (_GlobalWindParams.w > 0)
	{
		strength *= _GlobalWindParams.x;
		gustStrength *= _GlobalWindParams.x;
		//direction.xz += _WindDirection.xz;
	}

	//Nature renderer params
	if (_GlobalShiver.y > 0) {
		strength += _GlobalShiver.y;
		speed += _GlobalShiver.x;
	}
	if (GlobalWindDirectionAndStrength.w > 0) {
		gustStrength += GlobalWindDirectionAndStrength.w;
		direction.xz += GlobalWindDirectionAndStrength.xy;
	}

	s.ambientStrength = strength;
	s.speed = speed;
	s.direction = direction;
	s.swinging = swinging;
	s.mask = mask;
	s.randObject = randObject;
	s.randVertex = randVertex;
	s.randObjectStrength = randObjectStrength;
	s.gustStrength = gustStrength;
	s.gustFrequency = gustFrequency;

	return s;
}

//World-align UV moving in wind direction
float2 GetGustingUV(float3 wPos, WindSettings s) {
	return (wPos.xz * s.gustFrequency * 0.01) + (_Time.x * s.speed * s.gustFrequency * 0.01) * -s.direction.xz;
}

float SampleGustMapLOD(float3 wPos, WindSettings s) {
	float2 gustUV = GetGustingUV(wPos, s);
	float gust = tex2Dlod(_WindMap, float4(gustUV, 0,0)).r;

	gust *= s.gustStrength * s.mask;

	return gust;
}
float4 GetWindOffset(in float3 positionOS, in float3 wPos, float rand, WindSettings s) {

	float4 offset;

	//Random offset per vertex
	float f = length(positionOS.xz) * s.randVertex;
	float strength = s.ambientStrength * 0.5 * lerp(1, rand, s.randObjectStrength);
	//Combine
	float sine = sin(s.speed * (_Time.x + (rand * s.randObject) + f));
	//Remap from -1/1 to 0/1
	sine = lerp(sine  * 0.5 + 0.5, sine, s.swinging);

	//Apply gusting
	float gust = SampleGustMapLOD(wPos, s);

	//Scale sine
	sine = sine * s.mask * strength;

	//Mask by direction vector + gusting push
	offset.xz = sine + gust;
	offset.y = s.mask;

	//Summed offset strength
	float windWeight = length(offset.xz) + 0.0001;
	//Slightly negate the triangle-shape curve
	windWeight = pow(windWeight, 1.5);
	offset.y *= windWeight;

	//Wind strength in alpha
	offset.a = sine + gust;

	return offset;
}

//Bend map UV
float2 GetBendMapUV(in float3 wPos) {
	float2 uv = _BendMapUV.xy / _BendMapUV.z + (_BendMapUV.z / (_BendMapUV.z * _BendMapUV.z)) * wPos.xz;

	//Since version 7.3.1, UV must be flipped
//#if VERSION_GREATER_EQUAL(7,4)
//	uv.y = 1 - uv.y;
//#endif

	return uv;
}
float4 GetBendVectorLOD(float3 wPos)
{
	if (_BendMapUV.w == 0) return float4(0.5, wPos.y, 0.5, 0.0);

	float2 uv = GetBendMapUV(wPos);

	float4 v = tex2Dlod(_BendMap, float4(uv, 0,0)).rgba;

	//Remap from 0.1 to -1.1
	v.x = v.x * 2.0 - 1.0;
	v.z = v.z * 2.0 - 1.0;

	return v;
}

float4 GetBendOffset(float3 wPos, BendSettings b) {
	float4 vec = GetBendVectorLOD(wPos);

	float4 offset = float4(wPos, vec.a);

	float grassHeight = wPos.y;
	float bendHeight = vec.y;
	float dist = grassHeight - bendHeight;

	//Note since 7.1.5 somehow this causes the grass to bend down after the bender reaches a certain height
	//dist = abs(dist); //If bender is below grass, dont bend up

	float weight = saturate(dist);

	offset.xz = vec.xz * b.mask * weight * b.pushStrength;
	offset.y = b.mask * (vec.a * 0.75) * weight * b.flattenStrength;

	float influence = 1;

	//Pass the mask, so it can be used to lerp between wind and bend offset vectors
	offset.a = vec.a * weight * influence;

	//Apply mask
	offset.xyz *= offset.a;

	return offset;
}













BendSettings PopulateBendSettings(uint mode, float mask, float pushStrength, float flattenStrength, float perspCorrection)
{
	BendSettings s = (BendSettings)0;

	s.mode = mode;
	s.mask = mask;
	s.pushStrength = pushStrength;
	s.flattenStrength = flattenStrength;
	s.perspectiveCorrection = perspCorrection;

	return s;
}

float ObjectPosRand01() {
	return frac(UNITY_MATRIX_M[0][3] + UNITY_MATRIX_M[1][3] + UNITY_MATRIX_M[2][3]);
}
float3 GetPivotPos() {
	return float3(UNITY_MATRIX_M[0][3], UNITY_MATRIX_M[1][3] + 0.25, UNITY_MATRIX_M[2][3]);
}


float3 CameraPositionWS(float3 wPos)
{
	return _WorldSpaceCameraPos;

	/*
	//Not using _WorldSpaceCameraPos, since it doesn't have correct values during shadow and vertex passes *shrug*
	//https://issuetracker.unity3d.com/issues/shadows-flicker-by-moving-the-camera-when-shader-is-using-worldspacecamerpos-and-terrain-has-draw-enabled-for-trees-and-details

#if defined(SHADERPASS_SHADOWS) || defined(SHADERPASS_DEPTH_ONLY) //Fragment stage of depth/shadow passes
	return UNITY_MATRIX_I_V._m03_m13_m23;
#else //Fragment stage
	return _WorldSpaceCameraPos;
#endif
*/
}
//Combination of GetVertexPositionInputs and GetVertexNormalInputs with bending

void GetVertexData(float4 vertex, float3 normalOS, float rand, WindSettings s, BendSettings b, inout GrassVertexData data)
{
	data = (GrassVertexData)0;

	float4 wPos = mul(unity_ObjectToWorld, vertex);

	//Ensure the grass always bends down, even in negative directions (reverse abs)
	//bendWeight = (bendWeight < 0) ? -bendWeight : bendWeight;

	float3 worldPos = lerp(wPos, GetPivotPos(), b.mode);
	float4 windVec = GetWindOffset(vertex.xyz, wPos, rand, s);
	float4 bendVec = GetBendOffset(worldPos, b);

	float3 offsets = lerp(windVec.xyz, bendVec.xyz, bendVec.a);

	half3 viewDirectionWS = normalize(CameraPositionWS(wPos).xyz - wPos);
	float NdotV = dot(float3(0, 1, 0), viewDirectionWS);

	//Avoid pushing grass straight underneath the camera in a falloff of 4 units (1/0.25)
	float dist = saturate(distance(wPos.xz, CameraPositionWS(wPos).xz) * 0.25);

	//Push grass away from camera position
	float2 pushVec = -viewDirectionWS.xz;
	float perspMask = b.mask * b.perspectiveCorrection * dist * NdotV;
	offsets.xz += pushVec.xy * perspMask;

	//Apply bend offset
	wPos.xz += offsets.xz;
	wPos.y -= offsets.y;

	//Vertex positions in various coordinate spaces
	data.positionWS = wPos.xyz;
	data.positionVS = mul(UNITY_MATRIX_V, wPos);
	data.positionCS = mul(UNITY_MATRIX_VP, wPos);

	float4 ndc = data.positionCS * 0.5f;
	data.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
	data.positionNDC.zw = data.positionCS.zw;


#if ADVANCED_LIGHTING
	//Normals
	float3 oPos = TransformWorldToObject(wPos); //object-space position after displacement in world-space
	float3 bentNormals = lerp(normalOS, normalize(vertex.xyz - oPos), length(offsets)); //weight is length of wind/bend vector
#else
	float3 bentNormals = normalOS;
#endif

	data.tangentWS = float3(1.0, 0.0, 0.0);
	data.bitangentWS = float3(0.0, 1.0, 0.0);
	data.normalWS = UnityObjectToWorldNormal(bentNormals);



}
// 透光色
half3 Translucency(float3 viewDirectionWS, LWRP_Light light, float amount) {
	float VdotL = max(0, dot(-viewDirectionWS, light.direction)) * amount;

	//TODO: Incorperate size parameter
	VdotL = pow(VdotL, 4) * 8;

	//Translucency masked by shadows and grass mesh bottom
	float tMask = VdotL * light.shadowAttenuation * light.distanceAttenuation;

	//Fade the effect out as the sun approaches the horizon (75 to 90 degrees)
	float sunAngle = dot(float3(0, 1, 0), light.direction);
	float angleMask = saturate(sunAngle * 6.666); /* 1.0/0.15 = 6.666 */

	tMask *= angleMask;

	return saturate(tMask * light.color);
}
//Single channel overlay
float BlendOverlay(float a, float b)
{
	return (b < 0.5) ? 2.0 * a * b : 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
}

//RGB overlay
float3 BlendOverlay(float3 a, float3 b)
{
	float3 color;
	color.r = BlendOverlay(a.r, b.r);
	color.g = BlendOverlay(a.g, b.g);
	color.b = BlendOverlay(a.b, b.b);
	return color;
}
half PerceptualSmoothnessToPerceptualRoughness(half perceptualSmoothness)
{
	return (1.0 - perceptualSmoothness);
}
// 镜面反射高亮
float3 SpecularHighlight(LWRP_Light light, half smoothness, half3 normalWS, half3 viewDirectionWS) {

	float3 halfVec = normalize(float3(light.direction) + float3(viewDirectionWS));
	half NdotH = max(0, saturate(dot(normalWS, halfVec)));

	half perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
	half roughnesss = max(PerceptualRoughnessToRoughness(perceptualRoughness), 0.001);

	half roughnesss2MinOne = (roughnesss * roughnesss) - 1.0h;
	half normalizationTerm = roughnesss * 4.0h + 2.0h;

	float d = NdotH * NdotH * roughnesss2MinOne + 1.00001f;

	half LoH = saturate(dot(light.direction, halfVec));
	half LoH2 = LoH * LoH;

	half3 specularReflection = (roughnesss * roughnesss) / ((d * d) * max(0.1h, LoH2) * normalizationTerm);

	specularReflection *= light.distanceAttenuation * light.shadowAttenuation * smoothness;

	return light.color * specularReflection;

}




float4 ApplyVertexColor(in float4 vertexPos, in float3 wPos, in float3 baseColor, in float mask, in float aoAmount, in float darkening, in float4 hue, in float posOffset)
{
	float4 col = float4(baseColor, 1);

	//Apply hue
	col.rgb = lerp(col.rgb, hue.rgb, posOffset * hue.a);
	//Apply darkening
	float rand = frac(vertexPos.r * 4);

	float vertexDarkening = lerp(col.a, col.a * rand, darkening * mask); //Only apply to top vertices
	//Apply ambient occlusion
	float ambientOcclusion = lerp(col.a, col.a * mask, aoAmount);

	col.rgb *= vertexDarkening * ambientOcclusion;

	//Pass vertex color alpha-channel to fragment stage. Used in some shading functions such as translucency
	col.a = mask;

	return col;
}

float FadeFactor(float3 wPos, float4 params)
{
	if (params.z == 0) return 0;

	float pixelDist = length(CameraPositionWS(wPos).xyz - wPos.xyz);

	//Distance based scalar
	return saturate((pixelDist - params.x) / params.y);
}
//// 计算高度缩放
//float CalculateHeightsScale(float3 worldPosition)
//{
//	float foliageWorldDifferences = (float)_FoliageAreaSize / _FoliageAreaResolution;
//	float length = worldPosition.xz - _WorldSpaceCameraPos.xz;
//	float scale =min(1, 1 - ((length - foliageWorldDifferences) / (_FoliageAreaResolution - _FoliageAreaSize)));
//	return scale;
//}
//Incorperates LOD dithering so only one clip operation is performed
void AlphaClip(float alpha, float cutoff, float3 clipPos, float3 wPos, float4 fadeParams)
{
	float f = 1;

	f -= FadeFactor(wPos, fadeParams);

	//Does not work, current and next LOD both have the same LODFade value. Unity bug?
	/*
#ifdef LOD_FADE_CROSSFADE
	float p = GenerateHashedRandomFloat(clipPos.xy);
	f *= unity_LODFade.x - CopySign(p, unity_LODFade.x);
#endif
*/

#ifdef _ALPHATEST_ON
	clip((alpha * f) - cutoff);
#endif
}
#endif // _KTSS_BRDF_CGINC_
