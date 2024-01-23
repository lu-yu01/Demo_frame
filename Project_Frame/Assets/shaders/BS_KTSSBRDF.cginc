// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
// PBR 函数定义文件
#ifndef _KTSS_BRDF_CGINC_
	#define _KTSS_BRDF_CGINC_


	#include "BS_KTSSCore.cginc"
	#include "BS_LWRP.cginc"




	VertexOutputForwardBase vertForwardBase(VertexInput v)
	{
		UNITY_SETUP_INSTANCE_ID(v);// 目的在于让 InstanceID在 shader 函数里面能被访问到
		VertexOutputForwardBase o;
		UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBase, o); //初始化给定变量为 0
		UNITY_TRANSFER_INSTANCE_ID(v, o);// 使用它可以将实例 ID 从输入结构复制到顶点着色器中的输出结构。仅当您需要访问片段着色器中的每个实例数据时才需要这样做。
		//UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

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

		//o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);

		//UNITY_TRANSFER_FOG(o, o.pos);
		return o;
	}

	sampler2D _FireTex;
	float4 _FireTex_ST;
	half _FresnelInt;
	float4 _Firecolor01,_Firecolor02;
	half _BlackMask,_FireSpeed,_Fresnelhurt;

	half4 fragForwardBaseInternal(VertexOutputForwardBase i)
	{
		FRAGMENT_SETUP(s)
		UNITY_SETUP_INSTANCE_ID(i); // 目的在于让 InstanceID在 shader 函数里面能被访问到
		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

		half atten = 0;
		
		LWRP_Light lwrp_light = LWRP_GetMainLight();

		#ifdef LIGHTMAP_ON
		#else
//			UNITY_LIGHT_ATTENUATION(tatten, i, s.posWorld);
			atten = 1;
		#endif
		half occlusion = 1.0f;
		#if _METALLICGLOSSMAP
			occlusion = Occlusion(i.tex.xy);
		#endif
		
		LWRP_BRDFData brdfData;
		LWRP_InitializeBRDFData(s.albedo, s.metallic, s.specColor, s.smoothness, s.alpha, brdfData);

	
		s.bakedGI = LWRP_SampleSHPixel(i.ambientOrLightmapUV.rgb, s.normalWorld);
		half3 shadowColor = lerp(_PBRShadowColor.rgb, _PBRFringeShadowColor.rgb, atten) * (1.0h - atten) + atten;

		// 计算环境颜色
		half3 color = LWRP_GlobalIllumination(brdfData, s.bakedGI, occlusion, s.normalWorld, -s.eyeVec);
		
		half3 spec_color = 0;
		half3 diff_color = 0;
		half3 totall_spec_color = 0;
		half3 totall_diff_color = 0;
		LWRP_LightingPhysicallyBased(brdfData, lwrp_light, s.normalWorld, -s.eyeVec, spec_color, diff_color);
		totall_spec_color += spec_color;
		totall_diff_color += diff_color;
		
		color = color + max(totall_diff_color,0);
		totall_spec_color *= atten * occlusion;

		color += totall_spec_color;
		
		color *= shadowColor;
		

		#if CARDTOOL_CHARACTER_BODY

	    	half4 mask_info = GetCombinedMask(i.tex.xy);
	    	half cartoonMask = mask_info.r;
		    half cartoonShadowMask = mask_info.g;
	    	half emissionMask = mask_info.b;

			half4 shadowTexColor = GetCartoonShadowTex(i.tex.xy);
			half3 cattoomColor = GetCartoon(s,lwrp_light, s.posWorld.xyz, i.CarToolVertexNormal, _CartoonShadowColor * shadowTexColor, atten, cartoonShadowMask);
			
	    	color = lerp(cattoomColor, color, cartoonMask.r);
	    	color += lerp(s.albedo,_EmissionColor * s.albedo,0.2) * max(_MinEmissionScale, dot(s.normalWorld, -s.eyeVec))*emissionMask;
			
		#endif
		
		half4 rc = half4(color, 0);
		rc.a = 1;

		return rc;
	}

#endif // _KTSS_BRDF_CGINC_
