// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
#pragma exclude_renderers d3d11 gles
// PBR 函数定义文件
#ifndef _KTSS_BRDF_CGINC_
	#define _KTSS_BRDF_CGINC_


	#include "BS_KTSSCore.cginc"
	// 包含自定义的全局光定义文件
//	#include "BS_KTSSGlobalIllumination.cginc"
	#include "BS_LWRP.cginc"


	sampler2D unity_NHxRoughness;

	//-------------------------------------------------------------------------------------

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
		UNITY_SETUP_INSTANCE_ID(i); // 目的在于让 InstanceID在 shader 函数里面能被访问到
		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

		half atten = 0;
		half3 lm = half3(0.0, 0.0, 0.0);
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
		

		//判断和主角的距离
		half playerDis = PlayerLength(s.posWorld);
		//把距离转换为0-1
		half dis01 = min(1, playerDis / Globle_FogHeightFar.w);
		// 
		#if _DECAL_MAP
			#if _GLOSS_FROM_ALBEDO_A
			#else
			
			#endif
		#endif
		// 使用潮湿度权重设置
		/*#if USING_HUMID_WEIGHT
			s.metallic = lerp(s.metallic, _WaterMetallic, _HumidWeight);
			s.smoothness = lerp(s.smoothness, _WaterGlossiness, _HumidWeight);
		#endif*/

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

	
		s.bakedGI = LWRP_SampleSHPixel(i.ambientOrLightmapUV.rgb, s.normalWorld) + lm;
		half3 shadowColor = lerp(_PBRShadowColor.rgb, _PBRFringeShadowColor.rgb, atten) * (1.0h - atten) + atten;

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
		/*#ifdef SCENE_LIGHTING
			LWRP_LightingPhysicallyBased(brdfData, lwrp_player_light, s.normalWorld, -s.eyeVec, spec_color, diff_color);

			totall_spec_color += spec_color * 0.5f;
		#endif*/

	/*	#if !LIGHTMAP_ON
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
		#endif*/
		// 漫反射和环境光不能超过1，被Bloom变成灯泡
		//color = min(1,color + max(totall_diff_color,0));硬是把写好的Bloom取消了,内部写的HDR全不能用了
		color = color + max(totall_diff_color,0);


		/*#if USING_GRAY
			half gray = dot(color.rgb, 1) / 3 * _GrayLit;
			color = lerp(color.rgb, gray.rrr, _GrayWeight);
		#endif*/


		totall_spec_color *= atten * occlusion;

		#if CHARACTER_EYE

			//fixed3 reflectDir = normalize(reflect(-lwrp_light.direction, s.normalWorld));
			//fixed3 specular = lwrp_light.color.rgb * pow(saturate(dot(reflectDir, -s.eyeVec)), _EyeIrisSpecularPow) * _EyeIrisSpecularLit * (atten * 0.7 + 0.3);
			//fixed4 eyemask = GetEyeIrisSpecularMask(i.tex.xy);
			//specular += totall_spec_color;
			//// 不能超过1，不然会被Bloom处理成电灯泡
			//float sp_lit = max(specular.r, max(specular.g, specular.b)) * eyemask.r;
			//color += sp_lit;
			//// 不能超过1，不然会被Bloom处理成电灯泡
			//color = min(1, color);
			////return sp_lit;
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
			/*half4 mask_info = GetCBMask(i.tex.xy);
			half cartoonMask = mask_info.g;
			half cartoonShadowMask = mask_info.b;
			half emissionMask = mask_info.r;*/
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

#endif // _KTSS_BRDF_CGINC_
