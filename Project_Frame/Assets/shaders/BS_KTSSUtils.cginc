// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// 工具函数定义文件
#ifndef _KTSS_UTILS_CGINC_
	#define _KTSS_UTILS_CGINC_

	#include "UnityLightingCommon.cginc"
	#include "BS_KTSSUnityCG.cginc"
	#include "UnityShaderVariables.cginc"
	#include "UnityInstancing.cginc"

	//#include "UnityLightingCommon.cginc"
	//#include "AutoLight.cginc"
	#include "BS_KTSSConfig.cginc"

	//#include "BS_UnityShadowLibrary.cginc"
	// 包含定点声明文件
	#include "BS_KTSSInput.cginc"

	#define SIDE_TO_SIDE_FREQ1 1.975
	#define SIDE_TO_SIDE_FREQ2 0.793
	#define UP_AND_DOWN_FREQ1 0.375
	#define UP_AND_DOWN_FREQ2 0.193

	#ifdef _TERRAIN_TEX_4_
		#define TERRAIN_TEXTURE_COUNT 4
	#elif _TERRAIN_TEX_3_
		#define TERRAIN_TEXTURE_COUNT 3
	#elif _TERRAIN_TEX_2_
		#define TERRAIN_TEXTURE_COUNT 2
	#endif
	#ifndef TERRAIN_TEXTURE_COUNT
		#define TERRAIN_TEXTURE_COUNT 1
	#endif


	//根据模型法线决定采用xyUV还是zyUV,objectBump为objectWorldBump
	float2 XZUV(float3 worldPos, half3 PowObjectWorldBump)
	{
		float2 zUV = float2(PowObjectWorldBump.z > 0 ? -worldPos.x : worldPos.x, worldPos.y);
		float2 xUV = float2(PowObjectWorldBump.x < 0 ? -worldPos.z : worldPos.z, worldPos.y);
		if (PowObjectWorldBump.x>PowObjectWorldBump.z)
		{
			return xUV;
		}
		return zUV;
	}
	//根据法线的Y值算出雨天法线流向
	void RainNormal(inout half3 normal, float4 xzyUV, half bumpY,half powBump=8, half scaleTitle = 0.1)
	{
		return;
		half4 xzyTitleUV = xzyUV*scaleTitle;
		half3 rainNormal = tex2D(Globle_FogNoiseTex, xzyTitleUV.xy + _Time.y*0.2) * 2 - 1;
		//half3 rainNormal2 = tex2D(Globle_FogNoiseTex, xzyTitleUV.zw + _Time.y*0.18) * 2 - 1;
		normal.xy += rainNormal.xy*_Humidity*0.3 * bumpY;
	}

	void VertSnow(inout float3 worldVertex,half3 worldNormal)
	{
		half3 snowVector = normalize(_SnowVector);
		if (dot(worldNormal, snowVector) >= lerp(1, -1, ((1 - _SnowWetness)*_Snow * 2) / 3))
		{
			worldVertex += (snowVector + worldNormal)*_SnowDepth*_Snow*worldNormal;
		}
	}

	//树叶顶点运动相关
	float4 SmoothCurve(float4 x) {
		return x * x * (3.0 - 2.0 * x);
	}
	float4 TriangleWave(float4 x) {
		return abs(frac(x + 0.5) * 2.0 - 1.0);
	}
	float4 CubicSmooth(float4 vData)
	{
		return vData * vData * (3.0 - 2.0 * vData);
	}
	float4 TrigApproximate(float4 vData)
	{
		return (CubicSmooth(TriangleWave(vData)) - 0.5) * 2.0;
	}
	float4 SmoothTriangleWave(float4 x) {
		return SmoothCurve(TriangleWave(x));
	}
	float4 SineApproximation(float4 x)
	{
		return CubicSmooth(TriangleWave(x));
	}
	void ApplyMainBending(inout float3 pos, float bendScale, float3 wind) {
		pos += wind * bendScale;
	}
	void ApplyDetailBending(inout float3 pos,float3 normal,float branchPhase,float branchAtten,float branchAmp,	float detailSpeed,float edgeAtten,float edgeAmp)
	{
		float vertexPhase = dot(pos, branchPhase);
		float2 wavesIn = _Time.y*0.8 + float2(vertexPhase, branchPhase);
		float4 freqs = float4(SIDE_TO_SIDE_FREQ1, SIDE_TO_SIDE_FREQ2, UP_AND_DOWN_FREQ1, UP_AND_DOWN_FREQ2);
		float4 waves = (frac(wavesIn.xxyy * freqs) * 2.0 - 1.0) * detailSpeed;
		waves = SmoothTriangleWave(waves);

		float2 wavesSum = waves.xz + waves.yw;
		//pos.xzy += wavesSum.xxy * float3(EdageAtten * detailAmp * Normal.xy, BrachAtten * BranchAmp);
		pos.xzy += wavesSum.xxy * float3(edgeAtten * edgeAmp * normal.xy, branchAtten * branchAmp);
	}

	// 计算到玩家之间的距离
	float PlayerLength(float3 worldPos)
	{ 
		//编辑器采用世界相机位置，运行时采用后面
		return length( worldPos.xyz - MainPlayerPos.xyz );
	}

	//雾效计算
	inline void SimulateFog(float3 pos, inout fixed4 col,half playerDis,half farDis01)
	{

		// 削弱远处物体的亮度增加场景的体感
		half colorDis = saturate(playerDis / (AtmosphereOcclusion_Parameter.x));
		col.rgb = lerp(col.rgb, col.rgb * AtmosphereOcclusion_Color, AtmosphereOcclusion_Parameter.y * colorDis * colorDis);

		if (Globle_FogHeightFar.z == 0)return;
		

		//-----------高低和远近-----------
		//高度衰减 .. lengthFog*0.1代表每距离主角10米增加1米高度，然后再加上一个随着主角上升雾效也越来越浓
		// 高度雾最远距离(写死1000:代表500米后全部都是雾)playerDis/1000
		half height_Far = playerDis *0.01;
		half heightDis01 = saturate((pos.y - Globle_FogHeightFar.y) / (Globle_FogHeightFar.x));
		//Pow远近和高度
		half2 fog_FarHeight = pow(half2(farDis01, min(1,height_Far)), Globel_FogPowerSpeed.xy);

		//-----------噪声图-----------
		#if _GLOSS_FROM_ALBEDO_A | _NO_FOG_NOISSE
			fixed noise0 = 0.5;
			fixed noise1 = 0.5;
		#else
			//噪声图采样	*0.03是因为把贴图缩放别太密
			fixed noise0 = tex2D(Globle_FogNoiseTex, (pos.xz - (pos.yy - pos.xz) * 0.5)*0.002 + _Time.y * Globel_FogPowerSpeed.zw).b ;
			fixed noise1 = tex2D(Globle_FogNoiseTex, (pos.xz + pos.yy * 0.3) * 0.003 + _Time.y * Globel_FogPowerSpeed.zw + noise0 * 0.1).b;
		#endif
		fixed noisefar = (noise1 - 0.5) * noise0;
		fixed noise = noise0 * noise1 + noisefar * 0.2;

		// 11111111111111111111111111111111111111111111
		// 高低
		fixed height01 = 1 - saturate((pos.y - Globle_FogHeightFar.y) / (Globle_FogHeightFar.x));
		fixed height01Nos = pow(height01, Globel_FogPowerSpeed.y);
		height01Nos = lerp(height01Nos, height01Nos + height01Nos * noise * Globel_FogScaleHeightNoise.z, 0.2);


		fixed far01 =  saturate((playerDis - Globle_FogHeightFar.z) / Globle_FogHeightFar.w);
		fixed far01Nos = pow(far01, Globel_FogPowerSpeed.x);
		// 噪声图的使用浓度
		far01Nos = lerp(far01Nos,far01Nos + far01Nos * noise * Globel_FogScaleHeightNoise.z,0.2);
		// 距离影响高度雾的浓度
		height01Nos *= saturate(far01Nos * Globel_FogScaleHeightNoise.x);


		fixed3 nearCol = lerp(col.rgb, Globle_FogNearColor.rgb, height01Nos);

		col.rgb = lerp(col.rgb, Globle_FogNearColor.rgb, height01Nos);
		// 混合远处的雾
		col.rgb = nearCol.rgb;
		fixed far_color_w = 1 - saturate((pos.y - (Globle_FogHeightFar.y - Globle_FogHeightFar.x * 0.5)) / Globle_FogHeightFar.x);
		far_color_w = pow(far_color_w, Globel_SkyGroundFog.y);


		fixed3 sky_col = lerp(Globle_FogFarColor, Globle_FogNearColor, min(1,far_color_w + far_color_w * noise));
		half farDis = max(0,playerDis - Globel_FarFog.w);
		heightDis01 = pow(min(1, farDis / Globel_FarFog.z), Globel_FarFog.x);
		noisefar = noisefar * heightDis01 * Globel_FarFog.y ;
		height_Far = min(1, heightDis01 + heightDis01 * noisefar);
		height_Far = height_Far * FarFogDensity;
		col.rgb = lerp(col, sky_col, height_Far);


		// 加持颜色
		col.rgb = max(0,min(col.rgb,2));

		//col.rgb = sky_col;
		//用于后处理区分场景和角色




		//col = 0;

	}
	inline void SkyboxFog(float3 dir,inout fixed3 col)
	{

		if (Globle_FogHeightFar.z == 0)return;




		// 混合远处的雾
		col.rgb = col.rgb;
		float yp =1 - saturate((dir.y - Globel_SkyFog.y) / Globel_SkyFog.x);
		yp = pow(yp, Globel_SkyFog.z);
		col.rgb = lerp(col, Globel_SkyFogColor,yp * Globel_SkyFog.w);

		// 处理地平线的雾
		float gp = 1 - saturate((dir.y - (Globel_SkyFog.y  - Globel_SkyGroundFog.x)) / Globel_SkyGroundFog.x);
		gp = pow(gp, Globel_SkyGroundFog.y);
		fixed noisefar = (tex2D(Globle_FogNoiseTex, (dir.xz + dir.yy * 0.3) * 0.1  + _Time.y * Globel_FogPowerSpeed.zw).b - 0.5) * (1 - gp);
		col.rgb = lerp(col, Globle_FogNearColor , saturate(gp + gp * noisefar));

		// 加持颜色
		col.rgb = max(0, min(col.rgb, 2));
		//col.rgb = yp;

	}

	//雾效计算AO
	inline void SimulateFogAo(float3 pos, inout fixed4 col,float ao, half playerDis, half farDis01)
	{

		// 关闭雾效？？？？
		if (Globle_FogHeightFar.z == 0)
		{
			col.rgb *= ao;
			return;
		}

		float fogTotal = 0.0f;
		//-----------高低和远近-----------
		//高度衰减 .. lengthFog*0.1代表每距离主角10米增加1米高度，然后再加上一个随着主角上升雾效也越来越浓
		// 高度雾最远距离(写死1000:代表500米后全部都是雾)playerDis/1000
		half height_Far = playerDis * 0.01;
		half heightDis01 = saturate((pos.y - Globle_FogHeightFar.y) / (Globle_FogHeightFar.x));
		//Pow远近和高度
		half2 fog_FarHeight = pow(half2(farDis01, min(1, height_Far)), Globel_FogPowerSpeed.xy);

		//-----------噪声图-----------
		//噪声图采样	*0.03是因为把贴图缩放别太密
		fixed noise0 = tex2D(Globle_FogNoiseTex, (pos.xz - (pos.yy - pos.xz) * 0.5)*0.002 + _Time.y * Globel_FogPowerSpeed.zw).b;
		fixed noise1 = tex2D(Globle_FogNoiseTex, (pos.xz + pos.yy * 0.3) * 0.003 + _Time.y * Globel_FogPowerSpeed.zw + noise0 * 0.1).b;
		fixed noisefar = (noise1 - 0.5) * noise0;
		fixed noise = noise0 * noise1 + noisefar * 0.2;


		// 11111111111111111111111111111111111111111111
		// 高低
		float height01 = 1 - saturate((pos.y - Globle_FogHeightFar.y) / (Globle_FogHeightFar.x));
		float height01Nos = pow(height01, Globel_FogPowerSpeed.y);
		height01Nos = lerp(height01Nos, height01Nos + height01Nos * noise * Globel_FogScaleHeightNoise.z, 0.2);


		float far01 = saturate((playerDis - Globle_FogHeightFar.z) / Globle_FogHeightFar.w);
		float far01Nos = pow(far01, Globel_FogPowerSpeed.x);
		// 噪声图的使用浓度
		far01Nos = lerp(far01Nos, far01Nos + far01Nos * noise * Globel_FogScaleHeightNoise.z, 0.2);
		// 距离影响高度雾的浓度
		height01Nos *= saturate(far01Nos) * Globel_FogScaleHeightNoise.x;


		fogTotal = lerp(0, 1, saturate(height01Nos));

		float far_color_w = 1 - saturate((pos.y - (Globle_FogHeightFar.y - Globle_FogHeightFar.x * 0.5)) / Globle_FogHeightFar.x);
		far_color_w = pow(far_color_w, Globel_SkyGroundFog.y);


		half farDis = max(0, playerDis - Globel_FarFog.w);
		heightDis01 = pow(min(1, farDis / Globel_FarFog.z), Globel_FarFog.x);
		noisefar = noisefar * min(1, heightDis01) * Globel_FarFog.y;
		height_Far = min(1, heightDis01 + heightDis01 * noisefar);
		height_Far = height_Far * FarFogDensity;
		fogTotal = 1 - lerp(fogTotal, 1, height_Far);
		col.rgb = lerp(col.rgb, col.rgb * ao,fogTotal * fogTotal);

	}
	inline void FogAo(float3 pos, inout fixed4 col, float ao)
	{
		col.rgb = ao;
		return;
		//判断和主角的距离
		half playerDis = PlayerLength(pos);
		//把距离转换为0-1
		half dis01 = min(1, playerDis / Globle_FogHeightFar.w);
		//col.rgb *= ao;
		SimulateFogAo(pos, col, ao, playerDis, dis01);
	}
	inline half FarColorAtten(float3 worldPos)
	{
		return pow(  (1- min(1,length(MainPlayerPos.xyz - worldPos.xyz) / _GlobalFarColorAttenPowMin.x)), _GlobalFarColorAttenPowMin.y) * _GlobalFarColorAttenPowMin.z + _GlobalFarColorAttenPowMin.w;
	}

	half LerpOneTo(half b, half t)
	{
		half oneMinusT = 1 - t;
		return oneMinusT + b * t;
	}

	half3 LerpWhiteTo(half3 b, half t)
	{
		half oneMinusT = 1 - t;
		return half3(oneMinusT, oneMinusT, oneMinusT) + b * t;
	}
	float4 TexCoords(VertexInput v)
	{
		float4 texcoord;
		texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex); // Always source from uv0

		#if USING_CHARACTER_UV2
			// 角色没有烘焙信息直接输出uv1信息
			texcoord.zw = v.uv1;
		#elif TERRAIN_MESH
			texcoord.zw = v.uv0 * unity_LightmapST.xy + unity_LightmapST.zw;
		#else
			// 烘焙信息
			texcoord.zw = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
		#endif
		return texcoord;
	}

	float4 TexCoordsTerrain(TerrainInput v)
	{
		float4 texcoord;
		texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex); // Always source from uv0

		texcoord.zw = texcoord.xy * unity_LightmapST.xy + unity_LightmapST.zw;
		return texcoord;
	}
	//优化后的rgb2hsv
	float3 rgb2hsv(float3 c)
	{
		float epsilon = 1e-10;
		float4 K = float4(0, -1 / 3, 2 / 3, -1);
		//float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
		//float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzw), step(p.x, c.r));
		float4 p = c.g < c.b ? float4(c.bg, K.wz) : float4(c.gb, K.xy);
		float4 q = c.r < p.x ? float4(p.xyw, c.r) : float4(c.r, p.yzx);
		float d = q.x - min(q.w, q.y);
		float h = abs((q.w - q.y) / (6 * d + epsilon) + q.z);
		float3 hcv = float3(h, d, q.x);
		float s = hcv.y / (hcv.z + epsilon);
		return float3(hcv.x, s, hcv.z);
	}

	float3 hsv2rgb(float3 c)
	{
		float R = abs(c.x * 6 - 3) - 1;
		float G = 2 - abs(c.x * 6 - 2);
		float B = 2 - abs(c.x * 6 - 4);
		float3 rgb = saturate(float3(R, G, B));
		return ((rgb - 1)*c.y + 1)*c.z;

		//float4 K = float4(1, 2 / 3, 1 / 3, 3);
		//float3 p = abs(frac(c.xxx + K.xyz) * 6 - K.www);
		//return c.z*lerp(K.xxx, saturate(p - K.xxx), c.y);
	}


	half3 UnpackScaleNormal(half4 packednormal, half bumpScale)
	{
		#if defined(UNITY_NO_DXT5nm)
			half3 normal;
			normal.xy = (packednormal.xy * 2 - 1);
			normal.xy *= bumpScale;
			normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
			return normal;
		#else
			half3 normal;
			normal.xy = (packednormal.wy * 2 - 1);
			normal.xy *= bumpScale;
			normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
			return normal;
		#endif
	}


	//! TODO: Control Map 应该Sample一次就好了.

	half DetailMask(float2 uv)
	{
		return tex2D(_MetallicGlossMap, uv).a;
	}


	//分块UV 
	half2 AreaUV(half2 uv, half uvHorizontal)
	{
		half2 modelAreaUV = half2(fmod(uv*uvHorizontal, uvHorizontal + 1));
		return frac(modelAreaUV);
	}

	//分块UV,返回当前UV块所对应的索引
	half2 AreaUV_OUT(half2 uv, half uvHorizontal, out half index)
	{
		half2 modelAreaUV = half2(fmod(uv*uvHorizontal, uvHorizontal + 1));
		half2 floorUV = floor(modelAreaUV);
		index = floorUV.y*uvHorizontal + floorUV.x;
		return modelAreaUV - floorUV;
	}

	//第N块的UV
	half2 AreaUV_Index(half2 uv, half decalHorizontal, int index) {
		//half2 tilingUV = uv - 0.5;
		//tilingUV *= UVTiling;
		//tilingUV += 0.5;
		half row = floor(index / decalHorizontal);
		half column = index - row*decalHorizontal;

		return (uv + half2(column, row)) / decalHorizontal;
	}

	//uvHorizontal代表uv分块，decalHorizonTal代表贴花分块
	half3 DecalAlbedo(half2 uv, out fixed4 decalColor, half uvHorizontal = 3, half decalHorizontal = 4)
	{

		decalColor = 0;
		half index = 0;

		//模型UV
		half2 modelUV = AreaUV_OUT(uv, uvHorizontal, index);

		//所对应贴花ID
		half decalID = _DecalID[index];
		decalColor = _DecalColor[index];
		//如果当前部位的贴花ID为0,返回0
		if (decalID == 0) return 0;
		//(decalID-1) ：ID从1开始
		half2 areaUV = AreaUV_Index(modelUV, decalHorizontal, decalID - 1);

		float3 decalTex = tex2D(_DecalTex, areaUV).rgb;

		//模型ID为睫毛时裁剪
		if (index == 11)
		{
			clip(decalTex.r - _Cutoff);
		}
		decalTex.r *= decalColor.a;
		//metallic = decalTex.g;
		//smoothness = decalTex.b;
		//decalTex = decalTex.r;
		return decalTex;
	}


	//uvHorizontal代表uv分块，decalHorizonTal代表贴花分块
	half3 DecalAlbedoNormal(half2 uv, out fixed4 decalColor, inout half3 decalNormal, out half metallic, out half smoothness, half uvHorizontal = 3, half decalHorizontal = 4)
	{
		half index = 0;
		decalNormal = 0;
		metallic = 0;
		smoothness = 0;
		decalColor = 0;

		//UV分块 重新映射到0-1，并返回当前UV块的索引
		half2 modelUV = AreaUV_OUT(uv, uvHorizontal, index);
		//根据当前UV索引 得到 当前UV对应的贴花索引(1为左下角)
		half decalID = _DecalID[(int)index];

		//UV2中第8块UV属于眉毛之类的存在了UV3所以这里不用处理
		if (decalID == 0 || index >7) return 0;

		decalColor = _DecalColor[index];
		//UV再次分块， 重新映射到0-1 ,得到出decalID所对应的贴花的UV
		half2 areaUV = AreaUV_Index(modelUV, decalHorizontal, decalID - 1);
		float3 decalTex = tex2D(_DecalTex, areaUV).rgb;
		//法线计算
		decalNormal = tex2D(_DecalNormalTex, areaUV).rgb;
		decalNormal.xy = decalNormal.xy * 2 - 1;
		//光滑度采自法线图B通道,然后乘以缩放值
		smoothness = decalNormal.z*_DecalSmoothness[index];
		decalNormal.z = sqrt(1.0 - saturate(dot(decalNormal.rg, decalNormal.rg)));
		//法线缩放
		decalNormal.xy *= _DecalNormalScale[index];
		metallic = _DecalMetallic[index];

		//UV中第8块UV为需要裁剪的区域
		//if (index > 7)
		//{
			//	clip(decalTex.r - _FaceClip[index-8]);
		//}
		return decalTex;
	}

	half3 DecalAlbedoNormal_Clip(half2 uv, inout fixed4 decalColor, inout half3 decalNormal, out half metallic, out half smoothness, half uvHorizontal = 3, half decalHorizontal = 4)
	{
		half index = 0;

		//UV分块 重新映射到0-1，并返回当前UV块的索引
		half2 modelUV = AreaUV_OUT(uv, uvHorizontal, index);
		half afterIndex = index;
		index += 8;
		//根据当前UV索引 得到 当前UV对应的贴花索引(1为左下角)
		half decalID = _DecalID[index];

		if (decalID == 0) return 0;

		decalColor = _DecalColor[index];
		//UV再次分块， 重新映射到0-1 ,得到出decalID所对应的贴花的UV
		half2 areaUV = AreaUV_Index(modelUV, decalHorizontal, decalID - 1);

		//RG:法线 B:光滑度
		float3 decalTex1 = tex2D(_DecalTex1, areaUV).rgb;

		//法线计算
		//half3 decal1Normal=0;
		//decal1Normal.xy= decalTex1.xy * 2 - 1;
		//光滑度采自缩放值，因为rg为法线，b为a值
		smoothness = _DecalSmoothness[index];
		//decal1Normal.z = sqrt(1.0 - saturate(dot(decal1Normal.rg, decal1Normal.rg)));
		////法线缩放
		//decal1Normal.xy *= _DecalNormalScale[index];

		//decalNormal += decal1Normal;

		metallic = _DecalMetallic[index];

		clip(decalTex1.b - _FaceClip[afterIndex]);

		return decalTex1;
	}

	//BlendTerrain采样
	void BlendDecalAlbedoBump(int vertexColorID, float4 xzyUV,fixed2 idUV,half absBumpY, out half4 blendAlbedo, out half4 blendBump,half mipmapDis)
	{
		//float4 uv = frac(xzyUV*0.1);
		float4 uv = frac(xzyUV*_Tiles[vertexColorID]);
		//#ifdef TEXSIZE1024
		//	4/1024	0.00390625		256/1024-edge*2	=	0.25-0.00390625*2=0.2421875
		float4 decalUV = uv* 0.2421875 + 0.00390625;
		//float tiling = lerp(0, 0.00390625 * 6, mipmapDis);
		float tiling = lerp(0, 0.0234375, mipmapDis);

		//优化：把float4变成half4 ,ddx,ddy统一用ddx
		//half4 partddxUV= clamp(0.2421875*ddx(xzyUV), -tiling, tiling);
		//half4 dx = partddxUV;
		//half4 dy = partddxUV;

		float4 dx = clamp(0.2421875*ddx(xzyUV), -tiling, tiling);
		float4 dy = clamp(0.2421875*ddy(xzyUV), -tiling, tiling);
		//#else
		//	//	4/2048	0.001953125		512/2048-edge*2	=	0.25-0.001953125*2=0.24609375
		//
		//	float4 decalUV = uv* 0.24609375 + 0.001953125;
		//	//float tiling = lerp(0, 0.001953125 * 6, mipmapDis);
		//	float tiling = lerp(0, 0.01171875, mipmapDis);
		//	//half4 partddxUV= clamp(0.24609375*ddx(xzyUV), -tiling, tiling);
		//	float4 dx = clamp(0.24609375*ddx(xzyUV), -tiling, tiling);
		//	float4 dy = clamp(0.24609375*ddy(xzyUV), -tiling, tiling);
		//#endif


		//dx = lerp(0, dx, mipmapDis);
		//dy = lerp(0, dy, mipmapDis);
		float4 realUV = decalUV + fixed4(idUV, idUV);

		//blendAlbedo=half4(0,1,0,1);
		blendAlbedo = lerp(tex2D(_TerrainBlendTex, realUV.xy, dx, dy), tex2D(_TerrainBlendTex, realUV.zw, dx.zw, dy.zw), absBumpY);
		//blendBump=half4(0,1,0,1);
		blendBump = lerp(tex2D(_BumpBlendTex, realUV.xy, dx, dy), tex2D(_BumpBlendTex, realUV.zw, dx.zw, dy.zw), absBumpY);

	}
	void ChangeColor(half3 blendTexRGB, inout half3 albedo)
	{
		half4 blendRGBA = half4(blendTexRGB, 1);
		blendRGBA.a = 1 - blendRGBA.r - blendRGBA.g - blendRGBA.b;
		//置灰公式
		float len = dot(albedo, half3(0.299, 0.587, 0.114));
		//half len = dot(albedo, albedo); 
		blendRGBA.rgb *= len;
		albedo = saturate(blendRGBA.r*_Color1 * 2 + blendRGBA.g*_Color2 * 2 + blendRGBA.b*_Color3 * 2) + blendRGBA.a*albedo;
		
	}

	half3 Albedo_OutSM(float4 texcoords, half3 normalWorld, inout half metallic, inout half smoothness)
	{
		half3 albedo = 0;
		half4 maskColor = 0;
		half4 decalColor = 0;
		half3  decalTex = 0;


		#if _BODYCOMBINETEX

			//左下角的Albedo 可以优化为 texcoords*2?
			albedo = _Color.rgb * tex2D(_CombineTex, texcoords.xy*0.5).rgb;


			//ChangeColor 左上角的变色选区
			maskColor = tex2D(_CombineTex, half2(texcoords.x*0.5, texcoords.y*0.5 + 0.5));
			ChangeColor(maskColor.rgb, albedo);

			//Smoothness、Metallic 右下角的金属度贴图
			half4 mg = tex2D(_CombineTex, half2(texcoords.x*0.5 + 0.5, texcoords.y*0.5));
			metallic = mg.r;
			smoothness = mg.g*_GlossMapScale;

			#if _DECAL
				//贴花albedo
				decalTex = DecalAlbedo(texcoords.zw, decalColor, 3, _HorizontalAmount);
				metallic = lerp(metallic, decalTex.g, decalTex.r);
				smoothness = lerp(smoothness, decalTex.b * _GlossMapScale, decalTex.r);
				albedo = lerp(albedo, decalColor.rgb, decalTex.r);
			#endif

			return albedo;
		#endif

		#if _DECAL
			albedo = _Color.rgb * tex2D(_MainTex, texcoords.xy).rgb;


			maskColor = tex2D(_BlendTex, texcoords.xy);
			ChangeColor(maskColor.rgb, albedo);

			decalTex = DecalAlbedo(texcoords.zw, decalColor);
			metallic = lerp(metallic, decalTex.g, decalTex.r);
			smoothness = lerp(smoothness, decalTex.b * _GlossMapScale, decalTex.r);
			albedo = lerp(albedo, decalColor, decalTex.r);
			return albedo;
		#endif

		albedo = _Color.rgb * tex2D(_MainTex, texcoords.xy).rgb;

		return albedo;
	}

	half3 Albedo_Face(float4 texcoords, float2 uv3, inout half3 decalNormal, inout half metallic, inout half smoothness)
	{
		//贴花属性
		half4 decalColor = 0;
		half decalMetallic = 0;
		half decalSmoothness = 0;


		//贴图颜色
		half3 albedo = _Color.rgb * tex2D(_MainTex, texcoords.xy).rgb;

		//贴花贴图颜色
		half3  decalTex = DecalAlbedoNormal(texcoords.zw, decalColor, decalNormal, decalMetallic, decalSmoothness, 4, _HorizontalAmount);
		//取透明值
		half alpha = max(decalTex.r, max(decalTex.g, decalTex.b));
		decalNormal *= alpha;
		//法线、金属度、光滑度、贴图颜色
		metallic += decalMetallic*alpha;
		smoothness = lerp(smoothness, decalSmoothness, alpha);
		albedo = lerp(albedo, decalTex.rgb*decalColor.rgb, alpha* decalColor.a);

		half decalMetallic2 = 0;
		half decalSmoothness2 = 0;
		half3  decalTex1 = DecalAlbedoNormal_Clip(uv3, decalColor, decalNormal, decalMetallic2, decalSmoothness2, 2, _HorizontalAmount1);

		//取透明值
		alpha = decalTex1.b;
		//法线、金属度、光滑度、贴图颜色
		metallic += decalMetallic2*alpha;
		smoothness = lerp(smoothness, decalSmoothness2, alpha);
		albedo = lerp(albedo, decalTex1.b*decalColor.rgb, alpha* decalColor.a);

		//albedo = decalTex;
		//albedo = decalNormal;

		return albedo;

	}
	half GetDecalMapWeight(half3 normalWorld)
	{
		half mask = 1;
		half w = normalWorld.y * 0.5 + 0.5;
		w = min(1,(w + (1 - _DetailMaxValue)));
		mask *= max(0, pow(w, _DetailPower) - 0.01);
		return mask;

	}
	half GetBodyIceMapWeight(float4 texcoords)
	{
		half mask = saturate( tex2D(_IceMaskTex, texcoords.xy).r+0.01);
		mask = 1 - smoothstep(_IceWeight * _IceWeight , _IceWeight, mask);

		return mask;

	}
	half3 Albedo(float4 texcoords, half decalMapWeight)
	{
		half3 albedo = tex2D(_MainTex, texcoords.xy).rgb;

		#ifdef ALBEDO_HSV
			#ifdef UNITY_INSTANCING_ENABLED
				half3 hsv = UNITY_ACCESS_INSTANCED_PROP(_HSV_arr, _HSV).xyz;
				if (hsv.x <  359.1)
				{
					albedo = rgb2hsv(albedo);
					albedo.r = hsv.x / 359;
					albedo.g *= hsv.y;  //调整饱和度
					albedo.b *= hsv.z;
					albedo = hsv2rgb(albedo);
				}
			#else
				if (_HSV.x <  359.1)
				{
					albedo = rgb2hsv(albedo);
					albedo.r = _HSV.x / 359;
					albedo.g *= _HSV.y;  //调整饱和度
					albedo.b *= _HSV.z;
					albedo = hsv2rgb(albedo);
				}
			#endif
		#endif

		albedo *= _Color.rgb;
		#if _DECAL_MAP
			#if _GLOSS_FROM_ALBEDO_A | _DECAL_MAP_COLOR_ONLY
				half3 detailAlbedo = _DetailColor.rgb * 0.217637; //2;
			#else
				half3 detailAlbedo = tex2D(_DetailAlbedoMap, TRANSFORM_TEX(texcoords.xy, _DetailAlbedoMap)).rgb * _DetailColor.rgb;
			#endif
			//return decalMapWeight;
			albedo = lerp(albedo,detailAlbedo, decalMapWeight * _DetailCover);
			albedo = lerp(albedo,detailAlbedo, (1 - decalMapWeight) * _InvDetailCover);
			//#endif
		#endif
		// 计算冰冻的颜色贴图
		#if BODY_ICE
			half ice_weight = GetBodyIceMapWeight(texcoords);

			half3 iceAlbedo = tex2D(_IceColorTex, TRANSFORM_TEX(texcoords.xy, _IceColorTex)).rgb * _IceColor.rgb;
			albedo = lerp(albedo, iceAlbedo, ice_weight);
		#endif
		// #if _CILPDISS_ON
		// 	half cilp_weight = tex2D(_IceMaskTex, texcoords.xy).r;
		// 	clip( (1-_Cilpran) - cilp_weight );
		// 	// half fireRange = (1-smoothstep(0,_FireRange, (1-_Cilpran) - cilp_weight));
		// 	// half4 fireColor = fireRange * _FireColor;
		// 	// albedo += fireColor;
		// #endif

		return albedo;
	}

	half3 PerPixelWorldNormal(half3 normalTangent, float4 tangentToWorld[3])
	{
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

		//half3 normalTangent = NormalInTangentSpace(i_tex);
		half3 normalWorld = normalize(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well

		return normalWorld;
	}
	// 卡通渲染身体的掩码图
	half GetCartoonBodyMask(float2 uv)
	{
		return tex2D(_CartoonBodyMask, uv).r;
	}
	half4 GetCartoonShadowTex(float2 uv)
	{
		return tex2D(_CartoonShadowTexture, uv);
	}
	half GetCartoonBodyShadowMask(float2 uv)
	{
		return tex2D(_CartoonBodyShadowMask, uv).r;
	}
	half GetEmissionMask(float2 uv)
	{
		return tex2D(_EmissionMask, uv).r;
	}
	half4 GetCombinedMask(float2 uv)
	{
		return tex2D(_CartoonBodyMaskZYE, uv);
	}
	half4 GetCBMask(float2 uv)
	{
		return tex2D(_CBMask, uv);
	}
	// 获取眼睛镜面反射掩码图信息
	half4 GetEyeIrisSpecularMask(float2 uv)
	{
		return tex2D(_EyeIrisSpecularMask, uv);
	}
	half Alpha(float2 uv)
	{
		return tex2D(_MainTex, uv).a * _Color.a;
	}

	half Occlusion(float2 uv)
	{
		#ifdef _GLOSS_FROM_ALBEDO_A
			return 1;
		#else
			return tex2D(_MetallicGlossMap, uv).b;
		#endif
	}

	half SmoothnessToPerceptualRoughness(half smoothness)
	{
		return (1 - smoothness);
	}
	inline half DotClamped(half3 a, half3 b)
	{
		#if (SHADER_TARGET < 30)
			return saturate(dot(a, b));
		#else
			return max(0.0h, dot(a, b));
		#endif
	}

	inline half LambertTerm(half3 normal, half3 lightDir)
	{
		return DotClamped(normal, lightDir);
	}

	// ----------------------------------------------------------------------------

	KTUnity_GlossyEnvironmentData UnityGlossyEnvironmentSetup(half Smoothness, half3 worldViewDir, half3 Normal, half3 fresnel0)
	{
		KTUnity_GlossyEnvironmentData g;

		g.roughness /* perceptualRoughness */ = SmoothnessToPerceptualRoughness(Smoothness);
		g.reflUVW = reflect(-worldViewDir, Normal);

		return g;
	}

	// ----------------------------------------------------------------------------
	half perceptualRoughnessToMipmapLevel(half perceptualRoughness)
	{
		return perceptualRoughness * UNITY_SPECCUBE_LOD_STEPS;
	}

	// ----------------------------------------------------------------------------
	half mipmapLevelToPerceptualRoughness(half mipmapLevel)
	{
		return mipmapLevel / UNITY_SPECCUBE_LOD_STEPS;
	}


	half SkinMask(float2 uv) {
		#if SKINMASK
			return 1.0 - tex2D(_MetallicGlossMap, uv).b;
		#else
			return 1.0;
		#endif
	}


	half2 MetallicGloss(float2 uv)
	{
		half2 mg;

		#ifdef _METALLICGLOSSMAP
			#ifdef _GLOSS_FROM_ALBEDO_A
				mg.r = 0;
				mg.g = tex2D(_MainTex, uv).a;
			#else
				mg = tex2D(_MetallicGlossMap, uv).rg;
			#endif
			mg.g = 1 - mg.g;
			mg.g = mg.g * _Glossiness;
			//mg.g =pow( mg.g ,0.4545);
		#else
			mg.r = _Metallic;
			mg.g = _Glossiness;
		#endif

		return mg;
	}

	half3 Emission(float2 uv)
	{
		#ifndef _EMISSION
			return 0;
		#else
			return tex2D(_MetallicGlossMap, uv).a * _EmissionColor.rgb;
		#endif

	}



	half3 BlendNormals(half3 n1, half3 n2)
	{
		return normalize(half3(n1.xy + n2.xy, n1.z*n2.z));
	}


	half3 NormalInTangentSpace(float4 texcoords, float3 worldPos,float2 zuv=0,half3 absbump=0)
	{
		#ifdef XZYUV
			half4 normal= tex2D(_BumpMap, texcoords.xy)*absbump.x;
			normal += tex2D(_BumpMap, texcoords.zw)*absbump.y;
			normal += tex2D(_BumpMap, zuv)*absbump.z;
			half3 normalTangent =  UnpackScaleNormal(normal, _BumpScale);
		#else
			half3 normalTangent = UnpackScaleNormal(tex2D(_BumpMap, texcoords.xy), _BumpScale);
		#endif

		//判断是否开了细节(DETAIL)？
		#if _DETAIL_MULX2
			//	half mask = 1;
			//	//half3 a = tex2D(_DetailNormalMap, texcoords.zw);
			//	//_DetailNormalMapScale  =  a.x+a.y+a.z > 0  ? 1 : 0;
			//
			//	//_DetailNormalMapScale = 1;
			//	half3 detailNormalTangent = UnpackScaleNormal(tex2D(_DetailNormalMap, texcoords.xy*_DetailNormalTiling), _DetailNormalMapScale);
			//#if _DETAIL_LERP
			//	normalTangent = lerp(
			//		normalTangent,
			//		detailNormalTangent,
			//		mask);
			//
			//#else
			//	normalTangent = lerp(
			//		normalTangent,
			//		BlendNormals(normalTangent, detailNormalTangent),
			//		mask);
			//
			//#endif
			half3 detailNormalTangent = UnpackScaleNormal(tex2D(_DetailNormalMap, texcoords.xy*_DetailNormalTiling), _DetailNormalMapScale);

			#ifdef FACESHADER
				normalTangent += detailNormalTangent*(1 - smoothstep(0, 2.5, length(_WorldSpaceCameraPos - worldPos)));
			#else
				normalTangent += detailNormalTangent*(1 - smoothstep(0, 20 + _DetailNormalDistance, length(_WorldSpaceCameraPos - worldPos)));
			#endif
		#endif

		return normalTangent;
	}

	//! 通过高光颜色得到高光的强度
	half SpecularStrength(half3 specular)
	{
		#if (SHADER_TARGET < 30)
			// SM2.0: instruction count limitation
			// SM2.0: simplified SpecularStrength
			return specular.r; // Red channel - because most metals are either monocrhome or with redish/yellowish tint
		#else
			return max(max(specular.r, specular.g), specular.b);
		#endif
	}


	inline half3 PreMultiplyAlpha(half3 diffColor, half alpha, half oneMinusReflectivity, out half outModifiedAlpha)
	{
		#if defined(_ALPHAPREMULTIPLY_ON)
			// NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)

			// Transparency 'removes' from Diffuse component
			diffColor *= alpha;

			#if (SHADER_TARGET < 30)
				// SM2.0: instruction count limitation
				// Instead will sacrifice part of physically based transparency where amount Reflectivity is affecting Transparency
				// SM2.0: uses unmodified alpha
				outModifiedAlpha = alpha;
			#else
				// Reflectivity 'removes' from the rest of components, including Transparency
				// outAlpha = 1-(1-alpha)*(1-reflectivity) = 1-(oneMinusReflectivity - alpha*oneMinusReflectivity) =
				//          = 1-oneMinusReflectivity + alpha*oneMinusReflectivity
				outModifiedAlpha = 1 - oneMinusReflectivity + alpha*oneMinusReflectivity;
			#endif
		#else
			outModifiedAlpha = alpha;
		#endif
		return diffColor;
	}





	half3x3 CreateTangentToWorldPerVertex(half3 normal, half3 tangent, half tangentSign)
	{
		// For odd-negative scale transforms we need to flip the sign
		half sign = tangentSign * unity_WorldTransformParams.w;
		half3 binormal = cross(normal, tangent) * sign;
		//tangent = cross(binormal, normal);
		return half3x3(tangent, binormal, normal);
	}

	//-------------------------------------------------------------------------------------
	// counterpart for NormalizePerPixelNormal
	// skips normalization per-vertex and expects normalization to happen per-pixel
	half3 NormalizePerVertexNormal(float3 n) // takes float to avoid overflow
	{
		#if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
			return normalize(n);
		#else
			return normalize(n); // will normalize per-pixel instead
		#endif
	}

	half3 NormalizePerPixelNormal(half3 n)
	{
		#if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
			return n;
		#else
			return normalize(n);
		#endif
	}
	//-------------------------------------------------------------------------------------
	// Common fragment setup

	// deprecated
	half3 WorldNormal(half4 tan2world[3])
	{
		return normalize(tan2world[2].xyz);
	}


	inline half OneMinusReflectivityFromMetallic(half metallic)
	{
		// We'll need oneMinusReflectivity, so
		//   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
		// store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
		//   1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) =
		//                  = alpha - metallic * alpha
		half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
		return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
	}

	inline half3 DiffuseAndSpecularFromMetallic(half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity,half smoothness)
	{
		specColor = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
		//PBRSpecColor

		//specColor = albedo * metallic;
		//specColor = lerp(PBRSpecColor, albedo, metallic);

		oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
		// 呵呵
		return  albedo * oneMinusReflectivity ;
		return albedo * 0.1 + albedo * oneMinusReflectivity * 0.9;
	}

	//-----------------------------------------------------------------------------
	// Helper to convert smoothness to roughness
	//-----------------------------------------------------------------------------




	half PerceptualRoughnessToRoughness(half perceptualRoughness)
	{
		return perceptualRoughness * perceptualRoughness;
	}

	half RoughnessToPerceptualRoughness(half roughness)
	{
		return sqrt(roughness);
	}

	// Smoothness is the user facing name
	// it should be perceptualSmoothness but we don't want the user to have to deal with this name
	half SmoothnessToRoughness(half smoothness)
	{
		return (1 - smoothness) * (1 - smoothness);
	}


	half ScaleDiffuse(half nl, half skinMask) {
		return nl * skinMask + (1.0 - skinMask);
	}

	//-------------------------------------------------------------------------------------

	inline half Pow4(half x)
	{
		return x*x*x*x;
	}

	inline half2 Pow4(half2 x)
	{
		return x*x*x*x;
	}

	inline half3 Pow4(half3 x)
	{
		return x*x*x*x;
	}

	inline half4 Pow4(half4 x)
	{
		return x*x*x*x;
	}

	// Pow5 uses the same amount of instructions as generic pow(), but has 2 advantages:
	// 1) better instruction pipelining
	// 2) no need to worry about NaNs
	inline half Pow5(half x)
	{
		return x*x * x*x * x;
	}

	inline half2 Pow5(half2 x)
	{
		return x*x * x*x * x;
	}

	inline half3 Pow5(half3 x)
	{

		return pow(x, 5);
		//return x*x * x*x * x;
	}

	inline half4 Pow5(half4 x)
	{
		return pow(x, 5);
		//return x*x * x*x * x;
	}

	inline half3 FresnelTerm(half3 F0, half cosA)
	{
		half t = Pow5(1 - cosA);   // ala Schlick interpoliation
		return F0 + (1 - F0) * t;
	}
	inline half3 FresnelLerp(half3 F0, half3 F90, half cosA)
	{
		half t = Pow5(1 - cosA);   // ala Schlick interpoliation
		return lerp(F0, F90, t);
	}
	// approximage Schlick with ^4 instead of ^5
	inline half3 FresnelLerpFast(half3 F0, half3 F90, half cosA)
	{
		half t = Pow4(1 - cosA);
		return lerp(F0, F90, t);
	}

	// Note: Disney diffuse must be multiply by diffuseAlbedo / PI. This is done outside of this function.
	half DisneyDiffuse(half NdotV, half NdotL, half LdotH, half perceptualRoughness)
	{
		half fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
		// Two schlick fresnel term
		half lightScatter = (1 + (fd90 - 1) * Pow5(1 - NdotL));
		half viewScatter = (1 + (fd90 - 1) * Pow5(1 - NdotV));

		return lightScatter * viewScatter;
	}

	// NOTE: Visibility term here is the full form from Torrance-Sparrow model, it includes Geometric term: V = G / (N.L * N.V)
	// This way it is easier to swap Geometric terms and more room for optimizations (except maybe in case of CookTorrance geom term)

	// Generic Smith-Schlick visibility term
	inline half SmithVisibilityTerm(half NdotL, half NdotV, half k)
	{
		half gL = NdotL * (1 - k) + k;
		half gV = NdotV * (1 - k) + k;
		return 1.0 / (gL * gV + 1e-5f); // This function is not intended to be running on Mobile,
		// therefore epsilon is smaller than can be represented by half
	}

	// Smith-Schlick derived for Beckmann
	inline half SmithBeckmannVisibilityTerm(half NdotL, half NdotV, half roughness)
	{
		half c = 0.797884560802865h; // c = sqrt(2 / Pi)
		half k = roughness * c;
		return SmithVisibilityTerm(NdotL, NdotV, k) * 0.25f; // * 0.25 is the 1/4 of the visibility term
	}



	inline half GGXTerm(half NdotH, half roughness)
	{
		half a2 = roughness * roughness;
		half d = (NdotH * a2 - NdotH) * NdotH + 1.0f; // 2 mad
		return UNITY_INV_PI * a2 / (d * d + 1e-7f); // This function is not intended to be running on Mobile,
		// therefore epsilon is smaller than what can be represented by half
	}

	inline half PerceptualRoughnessToSpecPower(half perceptualRoughness)
	{
		half m = PerceptualRoughnessToRoughness(perceptualRoughness);   // m is the true academic roughness.
		half sq = max(1e-4f, m*m);
		half n = (2.0 / sq) - 2.0;                          // https://dl.dropboxusercontent.com/u/55891920/papers/mm_brdf.pdf
		n = max(n, 1e-4f);                                  // prevent possible cases of pow(0,0), which could happen when roughness is 1.0 and NdotH is zero
		return n;
	}

	// BlinnPhong normalized as normal distribution function (NDF)
	// for use in micro-facet model: spec=D*G*F
	// eq. 19 in https://dl.dropboxusercontent.com/u/55891920/papers/mm_brdf.pdf
	inline half NDFBlinnPhongNormalizedTerm(half NdotH, half n)
	{
		// norm = (n+2)/(2*pi)
		half normTerm = (n + 2.0) * (0.5 / UNITY_PI);

		half specTerm = pow(NdotH, n);
		return specTerm * normTerm;
	}

	//-------------------------------------------------------------------------------------
	/*
	// https://s3.amazonaws.com/docs.knaldtech.com/knald/1.0.0/lys_power_drops.html

	const float k0 = 0.00098, k1 = 0.9921;
	// pass this as a constant for optimization
	const float fUserMaxSPow = 100000; // sqrt(12M)
	const float g_fMaxT = ( exp2(-10.0/fUserMaxSPow) - k0)/k1;
	float GetSpecPowToMip(float fSpecPow, int nMips)
	{
		// Default curve - Inverse of TB2 curve with adjusted constants
		float fSmulMaxT = ( exp2(-10.0/sqrt( fSpecPow )) - k0)/k1;
		return float(nMips-1)*(1.0 - clamp( fSmulMaxT/g_fMaxT, 0.0, 1.0 ));
	}

	//float specPower = PerceptualRoughnessToSpecPower(perceptualRoughness);
	//float mip = GetSpecPowToMip (specPower, 7);
	*/

	inline half3 Unity_SafeNormalize(half3 inVec)
	{
		half dp3 = max(0.001f, dot(inVec, inVec));
		return inVec * rsqrt(dp3);
	}

	float3 CalculateSinglePointLight(float3 pointLightPos, float3 worldPos, half4 color, float3 normal, float3 range)
	{
		float3 dir = pointLightPos - worldPos;
		float hitw = pow(max(0.0f, 1 - (length(dir) / range.x)), 1.5);
		dir = normalize(dir);
		hitw *= max(0.2f, dot(dir, normal));
		return  hitw * pow(color.rgb * range.y,2.2);
	}

	float3 ComputerRealTimePointLight(float3 last_color, float3 worldPos, float3 viewdir, float3 normal)
	{
		//float vdotn = dot(viewdir, normal);
		float3 ret = (float3)0;
		// 计算第一个光源
		ret += CalculateSinglePointLight(PointLightPos[0].xyz, worldPos, HighPointLightCol0, normal, PointLightRangeIntansity[0].xyz);
		// 计算第二个光源
		ret += CalculateSinglePointLight(PointLightPos[1].xyz, worldPos, HighPointLightCol1, normal, PointLightRangeIntansity[1].xyz);
		// 计算第三个光源
		ret += CalculateSinglePointLight(PointLightPos[2].xyz, worldPos, HighPointLightCol2, normal, PointLightRangeIntansity[2].xyz);
		// 计算第四个光源
		ret += CalculateSinglePointLight(PointLightPos[3].xyz, worldPos, HighPointLightCol3, normal, PointLightRangeIntansity[3].xyz);
		return last_color + ret * SceneLightBrightness;
	}


	LWRP_Light LWRP_GetMainLight()
	{
		LWRP_Light light;

		#ifdef SCENE_LIGHTING
			/*light.color = lerp(_LightColor0.rgb, pow(MainSceneLightColor.rgb, 2.2), LightSolidImageSceneCubeSider.x);

			light.lightPos = lerp(_WorldSpaceLightPos0, MainSceneLightDir, LightSolidImageSceneCubeSider.x);
			light.direction = light.lightPos.xyz;*/
		#elif defined(PLAYER_LIGHTING)
			light.color = lerp(_LightColor0.rgb, pow(MainPlayerLightColor.rgb, 2.2), LightSolidImageSceneCubeSider.y);
			light.lightPos = lerp(_WorldSpaceLightPos0, MainPlayerLightDir, LightSolidImageSceneCubeSider.y);
			light.direction = light.lightPos.xyz;
		#elif defined(CHARACTER_EYE)
			/*light.color = lerp(_LightColor0.rgb, pow(MainPlayerLightColor.rgb, 2.2), LightSolidImageSceneCubeSider.y);
			light.lightPos = lerp(_WorldSpaceLightPos0, MainPlayerEyeLightDir, LightSolidImageSceneCubeSider.y);
			light.direction = light.lightPos.xyz;*/
		#else
			/*light.direction = _WorldSpaceLightPos0.xyz;
			light.color = _LightColor0.rgb;*/
		#endif
		light.distanceAttenuation = 1.0;
		light.shadowAttenuation = 1.0;
		return light;
	}
	// 获取玩家补光信息
	LWRP_Light LWRP_GetPlayerMainLight()
	{
		LWRP_Light light;

		light.color = lerp(_LightColor0.rgb, pow(PlayerViewScanePBRLightColor.rgb, 2.2), LightSolidImageSceneCubeSider.y);
		light.lightPos = lerp(_WorldSpaceLightPos0, PlayerViewScanePBRLightDir, LightSolidImageSceneCubeSider.y);
		light.direction = light.lightPos.xyz;
		light.distanceAttenuation = 1.0;
		light.shadowAttenuation = 1.0;
		return light;
	}
	half3 GetCartoon(FragmentCommonData s, LWRP_Light light,float3 posWorld, half3 vertex_normal, half3 shadow_color, float light_atten,float shadow_weight)
	{
		float3 diffSamplerColor = s.albedo;
		float3 normalDirection = vertex_normal;

		float3 viewDirection = -s.eyeVec;
		float3 lightDirection;
		float attenuation = 1.0;

		//if (0.0 == light.lightPos.w) // directional light?
		//{
			//	attenuation = 1.0; // no attenuation
			//	lightDirection = light.direction;
		//}
		//else // point or spot light
		//{
			//	float3 vertexToLightSource = light.lightPos.xyz - posWorld.xyz;
			//	float distance = length(vertexToLightSource);
			//	attenuation = 1.0 / distance; // linear attenuation 
			//	lightDirection = normalize(vertexToLightSource);
		//}
		lightDirection = PlayerCartoolLightDir;
		//normalDirection.y = 0;
		//normalDirection = normalize(vertex_normal);
		//lightDirection = normalize(lightDirection);
		//lightDirection.y = 0;
		//lightDirection = normalize(lightDirection);
		// default: unlit 
		float max_lit = max(s.albedo.r, max(s.albedo.g, s.albedo.b));
		// low priority: diffuse illumination
		float ndv = max(0.2,dot(s.normalWorld, viewDirection));
		float ndl = (dot(normalDirection, lightDirection) * 0.5 + 0.5);




		float3 fragmentColor = lerp(s.albedo * shadow_color, shadow_color * s.albedo *( ndv) ,0.5);
		float rg = 1 - _DiffuseThreshold;
		float w = ( ndl
		- _DiffuseThreshold) / rg * _CartoonBodyShadowOver * min(attenuation, light_atten);
		w = 1 - saturate(w) ;
		float3 fragmentColor2 = light.color.rgb * diffSamplerColor.rgb;
		fragmentColor = lerp(fragmentColor2, fragmentColor, w * shadow_weight);
		// 卡通渲染部分不允许亮度超过1
		return min(1, fragmentColor);

	}
	// 构建点光信息
	UnityLight AdditiveLight(half3 lightDir, half atten)
	{
		UnityLight l;

		l.color = _LightColor0.rgb;
		l.dir = lightDir;
		#ifndef USING_DIRECTIONAL_LIGHT
			l.dir = NormalizePerPixelNormal(l.dir);
		#endif

		// shadow the light
		l.color *= atten;
		return l;
	}
	// 初始化间接光信息
	UnityIndirect ZeroIndirect()
	{
		UnityIndirect ind;
		ind.diffuse = 0;
		ind.specular = 0;
		return ind;
	}

	//草的函数

	float2 SmoothCurve(float2 x) {
		return x * x *(3.0 - 2.0 * x);
	}

	float2 TriangleWave(float2 x) {
		return abs(frac(x + 0.5) * 2.0 - 1.0);
	}

	float2 SmoothTriangleWave(float2 x) {
		return SmoothCurve(TriangleWave(x));
	}


	float SampleWindLargeScaleNormalizedPower(float2 worldXZ)
	{
		float2 sampleWorldPos = worldXZ - WindOffset;
		float2 windUV = sampleWorldPos / _WindPatternSize;
		return tex2Dlod(_WindPatternTex, float4(windUV, 0, 0));
	}

	float ComputeWindSmallScaleNormalizedPower(float initPhase)
	{
		float waveIn = _Time.y + initPhase;
		float2 waves = frac(float2(waveIn, waveIn) * WindSmallFrequency * float2(1.975, 0.793) * 2.0 - 1.0);
		waves = SmoothTriangleWave(waves);
		return waves.x + waves.y;
	}

	float SampleWindPower(float2 worldXZ, float initPhase)
	{
		float2 normalizedPower;
		normalizedPower.x = SampleWindLargeScaleNormalizedPower(worldXZ);
		// normalizedPower.y = ComputeWindSmallScaleNormalizedPower(initPhase);
		normalizedPower.y = ComputeWindSmallScaleNormalizedPower(worldXZ.x * 10 + worldXZ.y);
		return dot(normalizedPower, WindLargeSmallScalePower);
	}

	float4 SampleDisplacement(float2 worldXZ)
	{
		float2 sampleUV = (worldXZ - _GrassDisplacementArea.xy) / _GrassDisplacementArea.zw;
		return tex2Dlod(_GrassDisplacementTex, float4(sampleUV, 0, 0));
	}

	float ComputeLodScale(float2 grassWorldPosXZ)
	{
		float2 offset = abs(grassWorldPosXZ - _WorldSpaceCameraPos.xz);
		float xScale = smoothstep(_LodDistance.x - _LodDistance.y, _LodDistance.x, offset.x);
		float yScale = smoothstep(_LodDistance.x - _LodDistance.y, _LodDistance.x, offset.y);
		return (1.0f - xScale) * (1.0f - yScale);
	}

	float3 AnimateVertex(float3 worldPos, float3 encodeNormal, float heightFactor, float initPhase, float windFactor)
	{
		float windPower = SampleWindPower(worldPos.xz, initPhase);
		float3 decodeNormal = encodeNormal * 2.0 - 1.0;

		float3 displacement = DISPLACEMENT_POWER * decodeNormal;
		float3 vertexOffset = windFactor * heightFactor * windPower * float3(_WindDir.x, -0.35, _WindDir.y);
		worldPos += vertexOffset;// +heightFactor * float3(displacement.x, displacement.y - DISPLACEMENT_POWER, displacement.z);
		return worldPos;
	}

	float SampleHeightMap(float3 vertexWorldPos)
	{
		float2 uv = (vertexWorldPos.xz - _HeightMapArea.xy + float2(0.5, 0.5)) / _HeightMapArea.zw;
		return _HeightMapRange.x + _HeightMapRange.y * tex2Dlod(_GrassHeightMap, float4(uv, 0, 0));
	}
	float3 GetCameraForward()
	{
		return UNITY_MATRIX_IT_MV[2].xyz;
	}
	float3 GetCameraRight()
	{
		return UNITY_MATRIX_IT_MV[0].xyz ;
	}
	float3 GetCameraUp()
	{
		return UNITY_MATRIX_IT_MV[1].xyz ;
	}
	// 根据方向计算天空叠加图片的UV
	float2 CompoterSkyboxAddImageUVByDir(float3 vertex, float3 dir, float2 imageSize)
	{
		//vertex *= -1;
		float3 r = -normalize(cross(dir.xyz, float3(0, 0, 1)));
		float3 u = cross(dir.xyz, r);
		float2 imagePos = float2(dot(r, vertex.xyz), dot(u, vertex.xyz)) * imageSize;
		imagePos *= -1;
		imagePos += 0.5;
		return imagePos;
	}
	// 计算相当于摄像机中心的UV
	float2 CompoterSkyboxAddImageUVByCameraCenter(float3 vertex, float2 imageSize)
	{
		//vertex *= -1;
		float2 imagePos = float2(dot(GetCameraRight(), vertex.xyz), dot(GetCameraUp(), vertex.xyz)) * imageSize;
		imagePos *= -1;
		imagePos += 0.5;
		return imagePos;
	}
	half2 GetScreenColorUv(half4 screenPos)
	{
		float grabSign = 1;
		if (_ColorTex_TexelSize.y < 0)
		{
			grabSign = -1;
		}
		return half2(1, -1)*(screenPos.xy / screenPos.w) *0.5 + 0.5;
	}
	half4 GetScreenColor(half4 screenPos)
	{
		float grabSign = 1;
		if (_ColorTex_TexelSize.y < 0)
		{
			grabSign = -1;
		}
		return tex2D(_ColorTex, float2(1, grabSign)*(screenPos.xy / screenPos.w) );
	}
	// 世界法线
	half3 ComputerFluoroscopy(half3 color, float2 imageSize, half4 screenPos,half3 worldNormal)
	{
		float ys = _ColorTex_TexelSize.y / _ColorTex_TexelSize.x;
		half2 uv = float2(screenPos.xy / screenPos.w);
		half2 dis = (float2(uv)-0.5) * imageSize;
		dis.y /= ys;
		half4 mask = tex2D(_FluoroscopyTex,dis);
		//dis *= -1;
		//dis += 0.5;
		dis = abs(dis);
		half max_dis = max(dis.x, dis.y) * 1.25;
		max_dis = max_dis > 1 ? max(0, (1 - (max_dis - 1) * 4)) : 1;
		float w = pow(max_dis, 16);
		// 越是正对着摄像机就会越透明
		w -= (dot(GetCameraForward(), -worldNormal) * 0.5 + 0.5) * 0.2 - mask.r;
		half4 screenColor = GetScreenColor(screenPos);

		//return screenColor.rgb;
		return lerp(color, screenColor,max(0, w) * 0.4);
	}
	half ComputerFormScreenCenterDistance( half4 screenPos,float max_dis, float pw)
	{
		half2 uv = (float2(screenPos.xy / screenPos.w) - OcclusionInfo.xy) * 2;
		uv.y /= OcclusionInfo.z;
		half dis =1 - pow( max(0, OcclusionInfo.w - length(uv)) / max_dis, pw);
		dis = max(dis, 0.3);
		//return screenColor.rgb;
		return dis;
	}
	// 获取地形的高度
	float SampleHeightMapNew(float3 vertexWorldPos)
	{
		float2 localuv = vertexWorldPos.xz - _HeightMapArea.xy;
		float2 localuv_abs = abs(localuv);
		float2 index = 0;
		if (localuv_abs.x < 100 && localuv_abs.y < 100)
		{
			index = localuv * 2;
		}
		else
		{
			float xmove = localuv.x > 0 ? 200 : -200;
			float zmove = localuv.y > 0 ? 200 : -200;

			index = (localuv - 100) / 2.0f + float2(xmove, zmove);
		}
		float2 uv = (index + 512) / 1024.0;
		//uv.y = 1 - uv.y;
		return tex2Dlod(_GrassHeightMap, float4(uv, 0, 0));
	}
	// 是否为空的高度,地形的高度不能超过一万米
	bool IsNullHeight(float h)
	{
		return h > 9990.0f;
	}

	float SampleScaleMap(float2 worldXZ)
	{
		float2 sampleUV = (worldXZ - _GrassScaleMapArea.xy + float2(0.5, 0.5)) / _GrassScaleMapArea.zw;
		return smoothstep(_MaterialID - 0.5, _MaterialID, tex2Dlod(_GrassScaleMap, float4(sampleUV, 0, 0)).r);
	}

	float3 AnimationVertexInWorldSpace(float3 vertex, float2 grassOffset, float heightFactor, float initPhase, float windFactor)
	{
		float3 tilePosition = GRASS_TILE_POSITION;

		float3 grassWorldPos = float3(tilePosition.x + grassOffset.x, tilePosition.y, tilePosition.z + grassOffset.y);
		// 使用新的高度信息
		tilePosition.y = SampleHeightMapNew(grassWorldPos);
		float4 displaceInfo = SampleDisplacement(grassWorldPos.xz);
		// vertex *= DISPLACEINFO_SCALE(displaceInfo) * SampleScaleMap(grassWorldPos.xz) * ComputeLodScale(grassWorldPos.xz);

		// 计算世界位置
		float3 vertexWorldPos = vertex + tilePosition;

		//return vertexWorldPos;

		float3 rs = AnimateVertex(vertexWorldPos, DISPLACEINFO_NORMAL(displaceInfo), heightFactor, initPhase, windFactor);
		rs = tilePosition.y > 9990.0 ? float3(0, -100000.0, -100000.0) : rs;
		return rs;
	}

	float3 AnimateRigidVertex(float3 worldPos, float3 encodeNormal, float initPhase, float windFactor)
	{
		float windPower = SampleWindPower(worldPos.xz, initPhase);
		float3 decodeNormal = encodeNormal * 2.0 - 1.0;

		float3 displacement = DISPLACEMENT_POWER * decodeNormal;
		float3 vertexOffset = windFactor * windPower * float3(_WindDir.x, -0.35, _WindDir.y);
		worldPos += vertexOffset + float3(displacement.x, displacement.y - DISPLACEMENT_POWER, displacement.z);
		return worldPos;
	}

	float3 AnimationRigidMeshInWorldSpace(float3 vertex, float2 grassOffset, float initPhase, float windFactor)
	{
		float3 tilePosition = GRASS_TILE_POSITION;

		float3 grassWorldPos = float3(tilePosition.x + grassOffset.x, tilePosition.y, tilePosition.z + grassOffset.y);
		float4 displaceInfo = SampleDisplacement(grassWorldPos.xz);
		vertex *= DISPLACEINFO_SCALE(displaceInfo) * SampleScaleMap(grassWorldPos.xz);

		float3 newGrassWorldPos = AnimateRigidVertex(grassWorldPos, DISPLACEINFO_NORMAL(displaceInfo), initPhase, windFactor);

		float3 vertexWorldPos = vertex + tilePosition + newGrassWorldPos - grassWorldPos;
		vertexWorldPos.y += SampleHeightMap(newGrassWorldPos);
		return vertexWorldPos;
	}

	float3 RigidMeshInWorldSpace(float3 vertex, float2 grassOffset)
	{
		float3 tilePosition = GRASS_TILE_POSITION;

		float3 grassWorldPos = float3(tilePosition.x + grassOffset.x, tilePosition.y, tilePosition.z + grassOffset.y);
		vertex *= SampleScaleMap(grassWorldPos.xz);

		float3 vertexWorldPos = vertex + tilePosition;
		vertexWorldPos.y += SampleHeightMap(grassWorldPos);
		return vertexWorldPos;
	}

	float3 AnimationVertexInModelSpace(float3 vertex, float2 grassOffset, float heightFactor, float initPhase, float windFactor)
	{
		float3 vertexWorldPos = AnimationVertexInWorldSpace(vertex, grassOffset, heightFactor, initPhase, windFactor);

		return vertexWorldPos - GRASS_TILE_POSITION;
	}

	//树远小近大
	void  TreeAtten(inout float3 vertex,float4 Treepos)
	{
		half disAtten = length(_WorldSpaceCameraPos - Treepos);
		half treeatten = pow((1 - min(1, disAtten / _TreeAtten)), 0.8);
		vertex.xyz *= treeatten;
	}

	//地形相关

	//正常计算法线
	fixed4 UnpackNormalWithScale(fixed4 packednormal, half scale)
	{
		#ifndef UNITY_NO_DXT5nm
			packednormal.x *= packednormal.w;
		#endif
		fixed3 normal;
		normal.xy = (packednormal.xy * 2 - 1) * scale;
		normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
		return fixed4(normal, 1);
	}
	//从法线获取光滑度金属度（r:Smoothness(0.1-2) Scale g:Metallic 最大值 b:Metallic 金属度缩放 a:Metallic Pow(0.1 - 5) ）
	inline void PartBumpAndSmoothMeta(half bumpScale, half4 SpecParams, inout half4 bumpTex)
	{
		bumpTex.xy = bumpTex.xy * 2 - 1;
		half oneMinusSmoothness = (1 - bumpTex.z);
		//光滑度和金属度 
		half currentSmoothness = saturate(oneMinusSmoothness*SpecParams.x);
		//修改根据光滑度算金属度算法
		half currentMetallic = clamp(pow(oneMinusSmoothness, SpecParams.w)*SpecParams.z, saturate(SpecParams.y), 1);
		bumpTex.xy *= bumpScale;
		bumpTex.z = currentSmoothness;
		bumpTex.w = currentMetallic;
		//bumpTex.w = currentSmoothness;
	}
	//计算贴图和法线
	inline void SamplerTexByXYZ(half2 uv, half4 vertexColor, inout half4 xyzAlbedoTex, inout half4 xyzBumpTex, inout half smoothness, inout half metallic)
	{
		fixed4 tex0 = 0, tex1 = 0, tex2 = 0, tex3 = 0;
		half4 bump0 = 0, bump1 = 0, bump2 = 0, bump3 = 0;
		//V1
		//half weight = dot(vertexColor, half4(1, 1, 1, 1));
		//V2
		#	if TERRAIN_TEXTURE_COUNT == 1
		half weight = vertexColor.r;
		#	elif TERRAIN_TEXTURE_COUNT == 2
		half weight = dot(vertexColor.rg, half2(1, 1));
		#	elif TERRAIN_TEXTURE_COUNT == 3
		half weight = dot(vertexColor.rgb, half3(1, 1, 1));
		#	elif TERRAIN_TEXTURE_COUNT == 4
		half weight = dot(vertexColor, half4(1, 1, 1, 1));
		#	endif
		vertexColor /= (weight + 1e-3f);
		xyzAlbedoTex.rgb = 0;
		xyzBumpTex = 0;

		#ifdef TERRAIN_BLOCKTYPE
			#	if TERRAIN_TEXTURE_COUNT > 0
			//float2 uvSplat0 = (uv.xy*_Tile.x);
			half2 uvSplat0 = TRANSFORM_TEX(uv.xy, _Splat0);
			tex0 = tex2D(_Splat0, uvSplat0)* vertexColor.r;
			bump0 = tex2D(_Normal0, uvSplat0);
			PartBumpAndSmoothMeta(_NormalScale.x, _SpecParams0, bump0);
			xyzAlbedoTex.rgb += tex0.rgb;
			xyzBumpTex += bump0 * vertexColor.r;
			#	else
			xyzBumpTex = half4(0, 1, 0, 0);
			#	endif


			#	if TERRAIN_TEXTURE_COUNT > 1
			//float2 uvSplat1 = (uv.xy*_Tile.y);
			half2 uvSplat1 = TRANSFORM_TEX(uv.xy, _Splat1);
			tex1 = tex2D(_Splat1, uvSplat1)* vertexColor.g;
			bump1 = tex2D(_Normal1, uvSplat1);
			
			PartBumpAndSmoothMeta(_NormalScale.y, _SpecParams1, bump1);
			xyzAlbedoTex.rgb += tex1.rgb;
			xyzBumpTex += bump1 * vertexColor.g;
			#	endif


			#	if TERRAIN_TEXTURE_COUNT > 2
			//float2 uvSplat2 = (uv.xy*_Tile.z);
			half2 uvSplat2 = TRANSFORM_TEX(uv.xy, _Splat2);
			tex2 = tex2D(_Splat2, uvSplat2)* vertexColor.b;
			bump2 = tex2D(_Normal2, uvSplat2);
			PartBumpAndSmoothMeta(_NormalScale.z, _SpecParams2, bump2);
			xyzAlbedoTex.rgb += tex2.rgb;
			xyzBumpTex += bump2 * vertexColor.b;
			#	endif

			#	if TERRAIN_TEXTURE_COUNT > 3
			//float2 uvSplat3 = (uv.xy*_Tile.w);
			half2 uvSplat3 = TRANSFORM_TEX(uv.xy, _Splat3);
			tex3 = tex2D(_Splat3, uvSplat3)* vertexColor.a;
			bump3 = tex2D(_Normal3, uvSplat3);
			PartBumpAndSmoothMeta(_NormalScale.w, _SpecParams3, bump3);
			xyzAlbedoTex.rgb += tex3.rgb;
			xyzBumpTex += bump3 * vertexColor.a;
			#	endif


			smoothness = xyzBumpTex.z;
			metallic = xyzBumpTex.w;

			//合并计算法线Z值
			//xyzBumpTex.rg = xyzBumpTex.rg * 2 - 1;
			xyzBumpTex.z = sqrt(1.0 - saturate(dot(xyzBumpTex.rg, xyzBumpTex.rg)));
		#endif

		xyzAlbedoTex.rgb *= _Color.rgb;
		xyzAlbedoTex.a = weight;

	}
	//填充FragmentCommonData结构体，然后传递到PBR
	inline void InputFragData(TerrainOutput i, inout FragmentCommonData s, out half3 vertexNormal)
	{
		float3 pos = i.posWorld;

		//开启Instanced后在像素着色器里计算顶点法线
		#if TERRAIN 
			half3 vertexWorldNormal = normalize(tex2Dlod(_TerrainNormalmapTexture, half4(i.tex.xy, 0, 0)).xyz * 2 - 1);

			//vertexWorldNormal = half3(0, 0, 1);
			half3 vertexWorldTangent = normalize(cross(vertexWorldNormal, float3(0, 0, 1)));
			half3 vertexBiNormal = normalize(cross(vertexWorldTangent,vertexWorldNormal));

		#else
			half3 vertexWorldNormal = half3(0, 0, 1);
			vertexWorldNormal = mul(unity_ObjectToWorld, normalize(vertexWorldNormal));
			half3 vertexWorldTangent = cross(unity_ObjectToWorld._13_23_33, vertexWorldNormal);
			half3 vertexBiNormal = cross(vertexWorldTangent,vertexWorldNormal );
		#endif
		//顶点着色器里的环境光因为顶点着色器的vertexWorldNormal是错误的，所以挪进像素着色器里算
		vertexNormal = vertexWorldNormal;
		half Smoothness = 0;
		half Metallic = 0;
		half4 Albedo = half4(0, 0, 0, 0);
		half4 Normal = 0;

		//计算贴图和法线
		half2 splatUV = (i.tex.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
		half4 splat_control = tex2D(_Control, splatUV);
		SamplerTexByXYZ(i.tex, splat_control, Albedo, Normal, Smoothness, Metallic);


		//法线计算
		half3 tangent = vertexWorldTangent;
		half3 binormal = vertexBiNormal;
		half3 normal = vertexWorldNormal;

		#if UNITY_TANGENT_ORTHONORMALIZE
			normal = NormalizePerPixelNormal(normal);
			// ortho-normalize Tangent
			tangent = normalize(tangent - normal * dot(tangent, normal));
			// recalculate Binormal
			half3 newB = cross(tangent,normal);
			binormal = newB * sign(dot(newB, binormal));
		#endif
		#if USING_HUMID_WEIGHT
			//根据模型法线决定采用xyUV还是zyUV
			//half3 absBump = pow(abs(tangentToWorld[2]), 3);
			//float2 yUV = float2(worldPos.z, worldPos.x);
			//float2 xzUV = XZUV(worldPos, absBump);
			//float4 xzyUV = float4(xzUV, yUV);

			////根据法线决定雨流方向
			//RainNormal(normalTangent, xzyUV, absBump.y);
			Normal.xyz = lerp(Normal.xyz,  half3(0, 0, 1), _HumidWeight * 0.5);

		#endif
		//Normal.xyz = Normal.yzx;
		half3 normalWorld = normalize(tangent * Normal.x + binormal * Normal.y + normal * Normal.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well


		s.normalMap = Normal;
		s.metallic = Metallic;
		s.albedo = Albedo.rgb;
		s.alpha = Albedo.a;
		s.normalWorld = normalWorld.xyz;
		s.eyeVec = normalize( i.posWorld- _WorldSpaceCameraPos.xyz);
		s.posWorld = pos;
		half oneMinusReflectivity;
		half3 specColor;
		half3 diffColor = DiffuseAndSpecularFromMetallic(s.albedo, Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity, 1);
		s.diffColor = diffColor;
		s.specColor = specColor;
		s.smoothness = Smoothness;
		s.oneMinusReflectivity = oneMinusReflectivity;

	}

	//顶点法线填充
	void SplatmapVert(inout TerrainInput v)
	{
		#if TERRAIN 

			#ifdef  UNITY_INSTANCING_ENABLED
				float2 patchVertex = v.vertex.xy;
				float4 instanceData = UNITY_ACCESS_INSTANCED_PROP(Terrain, _TerrainPatchInstanceData);
				float4 uvscale = instanceData.z * _TerrainHeightmapRecipSize;


				float4 u_xlat1 = _TerrainHeightmapRecipSize * instanceData.z;
				float4 u_xlat2 = u_xlat1 * instanceData.xyxy;
				float2 uv2 = v.vertex.xy * u_xlat1.zw + u_xlat2.zw;




				float4 uvoffset = instanceData.xyxy * uvscale;
				uvoffset.xy += 0.5f * _TerrainHeightmapRecipSize.xy;
				float2 sampleCoords = (patchVertex.xy * uvscale.xy + uvoffset.xy);

				float hm = UnpackHeightmap(tex2Dlod(_TerrainHeightmapTexture, float4(sampleCoords, 0, 0)));
				v.vertex.xz = (patchVertex.xy + instanceData.xy) * _TerrainHeightmapScale.xz * instanceData.z;  //(x + xBase) * hmScale.x * skipScale;
				v.vertex.y = hm * _TerrainHeightmapScale.y;
				v.vertex.w = 1.0f;
				//float3 nor = tex2Dlod(_TerrainNormalmapTexture, float4(sampleCoords, 0, 0)).xyz;
				//v.normal = 2.0f * nor - 1.0f;
				//v.normal = half3(0, 1, 0);
				v.uv0.xy = (patchVertex.xy*uvscale.zw + uvoffset.zw);
				v.uv1.xy = uv2;
				//v.uv0.zw = uv2 * float2(0.0390625, 0.0390625) + float2(0.9453125, 0);
				v.uv0.zw = uv2 * unity_LightmapST.xy + unity_LightmapST.zw;
				//v.uv0 = instanceData;
				//v.uv3.xy = v.uv2.xy = v.uv1.xy = v.uv0.xy;
			#endif
		#endif
		//v.tangent.xyz = cross(v.normal, float3(0, 0, 1));
		//v.tangent.w = -1;
	}
	float3 ShowDebugColor(FragmentCommonData s,float att,float occ)
	{
		if (_DebugView > 6)// 显示贴图
		{
			return s.albedo;
		}
		else if (_DebugView > 5)// 显示法线
		{
			return s.normalWorld * 0.5 + 0.5;
		}
		else if (_DebugView > 4) // 显示影子
		{
			return att;
		}
		else if (_DebugView > 3) // 显示ao
		{
			return occ;
		}
		else if (_DebugView > 2) // 显示ao
		{
			return s.smoothness;
		}
		return s.metallic;
	}

#endif // _KTSS_UTILS_CGINC_
