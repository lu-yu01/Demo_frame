// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// 参数和数据结构定义文件

#ifndef _KTSS_INPUT_H_
#define _KTSS_INPUT_H_

#include "BS_AutoLight.cginc"

#if (_DETAIL_MULX2 || _DETAIL_MUL || _DETAIL_ADD || _DETAIL_LERP)
#define _DETAIL 1
#endif
#ifndef CARDTOOL_CHARACTER_BODY
#define CARDTOOL_CHARACTER_BODY 0
#endif

#ifndef CHARACTER_EYE
#define CHARACTER_EYE 0
#endif
#ifndef SHADER_SHOW_DEBUG
#define SHADER_SHOW_DEBUG 0
#endif
//******************全局参数******************
//PBR高光颜色
fixed4 PBRSpecColor;
//主角位置
float4 MainPlayerPos;
// 不透明场景贴图
sampler2D   SolidScreenImage;
//角色cubemap
UNITY_DECLARE_TEXCUBE(PlayerCubeMap);
float4 PlayerCubeMap_HDR;
//角色阴影pow
float PowAtten;
// 是否为编辑器查看
float IsEditorView;

half4 _ScalePowLightmap;

//--------场景--------

//潮湿度
half _Humidity;
//风
float4 _WindVector;float4 _WindParams;
//雪
float4 _SnowVector; fixed4 _SnowColor; float _SnowDepth; float _Snow; float _SnowWetness; 
//远处高光衰减
half _EnableFarSpec;
//雾,雾的颜色,噪声雨水贴图，高低和远近，pow和speed，强度远处高度和噪声
half4 _GlobalFarColorAttenPowMin;
fixed4 Globle_FogNearColor, Globle_FogFarColor;
half4 Globel_FarFog;
half4 Globel_SkyFogColor;
half4 Globel_SkyFog;
half4 Globel_SkyGroundFog;
half4 AtmosphereOcclusion_Parameter;
half4 AtmosphereOcclusion_Color;
half FarFogDensity;
sampler2D Globle_FogNoiseTex;
half4 Globle_FogHeightFar, Globel_FogPowerSpeed;
half4 Globel_FogScaleHeightNoise;

////雪的大小
//half _Snow;
////雪的颜色
//fixed4 _SnowColor;
////雪的方向
//float4 _SnowDir;
////雪润度
//float _Wetness;


half _EyeIrisSpecularPow;
half _EyeIrisSpecularLit;
sampler2D _EyeIrisSpecularMask;

sampler2D _AlphaMaskTex;
half _AlphaMaskInv;
half4 _PBRShadowColor;
half4 _PBRFringeShadowColor;
// 卡通影子颜色
half4 _CartoonShadowColor;
// 卡通的影子和漫反射区域控制参数
half _DiffuseThreshold;
// 卡通影子过度
half _CartoonBodyShadowOver;
sampler2D _CartoonShadowTexture;
// 
sampler2D _CartoonBodyMask;
sampler2D _CartoonBodyShadowMask;
sampler2D _CBMask;
sampler2D _CartoonBodyMaskZYE;

// 身体水的法线图
sampler2D _WaterBumpMap;
float4 _WaterBumpMap_ST;
// 身体水的流速图
sampler2D _WaterPannerMask;
// 水流强度图
sampler2D _WaterPowerMask;
// 散射控制图
sampler2D _TransMask;


//--------灯光--------
// x 场景光的使用权重,y角色光的使用权重,z场景背景贴图使用权重,w场景反射球使用权重
half4 LightSolidImageSceneCubeSider;
// 场景灯光的颜色，方向
half4 MainSceneLightColor,MainSceneLightDir;
// 卡通灯光位置
half4 CartoolLightPos;
// 角色灯光的颜色，方向
half4 MainPlayerLightColor,MainPlayerLightDir, MainPlayerEyeLightDir;
half4 PlayerCartoolLightColor, PlayerCartoolLightDir;
// 主角的补光信息
half4 PlayerViewScanePBRLightColor, PlayerViewScanePBRLightDir;
// 角色UI灯光的颜色，方向
half4 UI_MainPlayerLightColor,UI_MainPlayerLightDir;
// 是否使用后处理光源，1表示使用后处理光源，0表示使用unity的光源
float ImageEffLight = 1;
// 水的流速
half _WaterSpeed;
half _WaterGlossiness;
half _WaterMetallic;
half _HumidWeight;

// 冰冻效果
half4 _IceColor;
half4 _IceTransColor;
half4 _IceTransLight;
half _IceGlossiness;
half _IceMetallic;
half _IceWeight;
half _Cilpran;
half4 _FireColor;
half _FireRange;


sampler2D _IceColorTex; half4 _IceColorTex_ST;
sampler2D _IceMaskTex;

sampler2D _IceNormalMap; half4 _IceNormalMap_ST;
float _IceNormalMapScale;

half _GrayWeight;
half _GrayLit;

sampler2D _EmissionMask;
//程序控制开关
half EmssionScale;
//点光源和自发光整体强度
half SceneLightBrightness;
//点光位置,范围和强度
float4 PointLightPos[250]; half4 PointLightRangeIntansity[250]; fixed3 PointLightCol[250];
//点光颜色
fixed4 HighPointLightCol0, HighPointLightCol1, HighPointLightCol2, HighPointLightCol3, HighPointLightCol4, HighPointLightCol5, HighPointLightCol6, HighPointLightCol7;

//--------InstancingNPC--------
sampler2D _boneTexture;
int _boneTextureBlockWidth;
int _boneTextureBlockHeight;
int _boneTextureWidth;
int _boneTextureHeight;

//Grass

// 草的高度图
sampler2D _GrassHeightMap;
float4 _HeightMapArea;
float2 _HeightMapRange;
sampler2D _GrassScaleMap;
float4 _GrassScaleMapArea;

// 草的风力扰动贴图
sampler2D _WindPatternTex;
// 草的碰撞信息贴图
sampler2D _GrassDisplacementTex;
// 草碰撞信息图的范围信息
float4 _GrassDisplacementArea;

// 1 显示金属度，2显示粗糙度,3显示AO，4显示影子,5 显示法线，6 树叶受光效果
float _DebugView;

float4 _WindDir;
float2 _WindPatternSize;
float4 _WindInfo;
float2 _LodDistance;
float _MaterialID;

#define WindDir 				    _WindDir.xy
#define WindOffset 				    _WindDir.zw
#define WindLargeSmallScalePower    _WindInfo.xy
#define WindSmallFrequency		    _WindInfo.z

#define DISPLACEINFO_SCALE(info)    info.a
#define DISPLACEINFO_NORMAL(info)   info.xyz
#define DECODE_GRASS_OFFSET(uv)     uv.zw

#define GRASS_TILE_POSITION         unity_ObjectToWorld._14_24_34
#define DISPLACEMENT_POWER          1.0


//******************标准PBR参数******************
half4       _Color;
half        _Cutoff;
sampler2D   _MainTex;half4 _MainTex_ST;
sampler2D   _BumpMap; half4 _BumpMap_ST; half _BumpScale;
sampler2D   _EmissionMap;half4 _EmissionMap_ST;
sampler2D   _SpecGlossMap;
sampler2D   _MetallicGlossMap;
half        _Metallic;
half        _Glossiness;
half        _GlossMapScale;
half        _UVSec;
half4       _EmissionColor;
half _MinEmissionScale;
uniform half4 _TimeEditor;
sampler2D _ColorTex;
sampler2D _FluoroscopyTex;
half4 _ColorTex_TexelSize;

//Aniso
fixed4 _SpecularColor0, _SpecularColor1;
half4 _ShiftPower;
sampler2D _AnisoTex; half4 _AnisoTex_ST;

//SSS
fixed4 _TransColor;half _TransDir;half4 _TransLight;
half _sssMainTexPower;
half _CurveFactor;
sampler2D _SkinTex;sampler2D _TransTex;

//Lightmap(BigBuilding)
half _LightmapScale;
sampler2D _CustomLightmap; half4 _CustomLightmap_ST;

//细节贴图/法线
sampler2D _DetailAlbedoMap;half4 _DetailAlbedoMap_ST;
sampler2D _DecalNormalTex; half _DetailNormalDistance;
sampler2D _DetailMask;
sampler2D _DetailNormalMap;
half4 _DetailColor;
half _DetailNormalTiling;
half _DetailTiling;
half _DetailMaxValue;
half _DetailPower;
half _DetailNormalMapScale;
half _DetailMetallic;
half _DetailGlossiness;
half _DetailCover;
half _InvDetailCover;






//******************Other******************
//LandTerrain
UNITY_DECLARE_TEX2DARRAY(_MainTexArr);
UNITY_DECLARE_TEX2DARRAY(_BumpMapArr);
sampler2D _TerrainBlendTex; sampler2D _BumpBlendTex;

half4 _SpecParams[8];	half4 _SpecParams0, _SpecParams1, _SpecParams2, _SpecParams3, _SpecParams4, _SpecParams5, _SpecParams6, _SpecParams7;
half _NormalScales[8];	/*half4 _NormalScale,_NormalScale2;  */
half _Tiles[8];			
//half4 _AmbientAndPreview;(等写完编辑器脚本后整合为一个)
half _AmbientColorAtten; half _AmbientOcclusion; half _PreviewType;
// xy 是玩家投影的中心点，z 是屏幕宽高比，w 范围值
half4 OcclusionInfo;

//地形
sampler2D _MetallicTex;
half _Metallic0;
half _Metallic1;
half _Metallic2;
half _Metallic3;
half _Smoothness0;
half _Smoothness1;
half _Smoothness2;
half _Smoothness3;
sampler2D _Splat0, _Splat1, _Splat2, _Splat3;
float4 _Splat0_ST, _Splat1_ST, _Splat2_ST, _Splat3_ST;
sampler2D _Normal0, _Normal1, _Normal2, _Normal3;
float _NormalScale0, _NormalScale1, _NormalScale2, _NormalScale3;
//float _HeightThreshold;
//half _GrassThreshold, _VerticalThreshold, _HeightThreshodlTest, _RiverThreshold;
//half _LerpSmoothness0, _LerpSmoothness1, _LerpSmoothness2, _LerpSmoothness3, _LerpSmoothness4;
//fixed4 _Color;
//sampler2D _MainTex;
sampler2D _Control;	float4 _Control_ST;	float4 _Control_TexelSize;
//sampler2D _Splat0, _Splat1, _Splat2, _Splat3;
//sampler2D _Normal0, _Normal1, _Normal2, _Normal3;

sampler2D _TerrainHeightmapTexture;
sampler2D _TerrainNormalmapTexture;
float4    _TerrainHeightmapRecipSize;   // float4(1.0f/width, 1.0f/height, 1.0f/(width-1), 1.0f/(height-1))
float4    _TerrainHeightmapScale;       // float4(hmScale.x, hmScale.y / (float)(kMaxHeight), hmScale.z, 0.0f)
half4 _NormalScale;


//	Face/Body
fixed _DecalID[12];
sampler2D _DecalTex; 
sampler2D _BlendTex;
fixed4 _DecalColor[12];
fixed _DecalNormalScale[12];
fixed _DecalMetallic[12];
fixed _DecalSmoothness[12];
half _FaceClip[4];
//(等写完编辑器脚本后整合为一个)
fixed _HorizontalAmount; fixed _VerticalAmount; fixed _UVHorizontalAmount; fixed _UVVerticalAmount;
fixed _HorizontalAmount1;
sampler2D _CombineTex;sampler2D _DecalTex1;
fixed4 _Color1; fixed4 _Color2; fixed4 _Color3;

//Building
half4 _SmoothnessMeta;

#ifdef TERRAIN
#ifdef  UNITY_INSTANCING_ENABLED
UNITY_INSTANCING_BUFFER_START(Terrain)
UNITY_DEFINE_INSTANCED_PROP(float4, _TerrainPatchInstanceData) // float4(xBase, yBase, skipScale, ~)
UNITY_INSTANCING_BUFFER_END(Terrain)
#endif
#endif


#ifdef NPC_INSTANCING
#ifdef UNITY_INSTANCING_ENABLED
UNITY_INSTANCING_BUFFER_START(Props)
UNITY_DEFINE_INSTANCED_PROP(half, preFrameIndex)
#define preFrameIndex_arr Props
UNITY_DEFINE_INSTANCED_PROP(half, frameIndex)
#define frameIndex_arr Props
UNITY_DEFINE_INSTANCED_PROP(half, transitionProgress)
#define transitionProgress_arr Props
UNITY_DEFINE_INSTANCED_PROP(half4, par)
#define pars_arr Props
UNITY_DEFINE_INSTANCED_PROP(half4, par2)
#define pars2_arr Props
UNITY_DEFINE_INSTANCED_PROP(half4, hitTime)
#define hitTime_arr Props
UNITY_DEFINE_INSTANCED_PROP(half4, hitColor)
#define hitColor_arr Props
UNITY_DEFINE_INSTANCED_PROP(half4, _HSV)
#define _HSV_arr Props

UNITY_INSTANCING_BUFFER_END(Props)
#else
uniform float frameIndex;
uniform float preFrameIndex;
uniform float transitionProgress;
uniform fixed4 par;
uniform fixed4 par2;
uniform fixed4 hitTime;
uniform fixed4 hitColor;
#endif

#endif


//树叶
#ifdef ALBEDO_HSV
#ifdef UNITY_INSTANCING_ENABLED
#else
half3 _HSV;
#endif
#else
half3 _HSV;
#endif
 half4 _HSVID; int _TreeID;

int _ShowID;
float _TreeAtten;

//BigBoss
sampler2D _Hitnoise;	float2 _Hitnoise_ST;
half4 _HitColor;
half  _HitScale;
half  _HitTime;
half  _HitSpeed;
half    _HitDis;
half    _HitStr;
half _TreeDurationTime;




//SimpleClip
half3 _TUL;
half2 _GlossShiness;
half4       _HurtColor;//受击颜色
half4       _OverlayColor;//遮罩颜色
half4       _GlossHurt;//受击范围
sampler2D _DissolveMap;
half _DissolveThreshold;
//float _ColorFactor;
float _DissolveEdge;
half4 _DissolveColor;
//half4 _DissolveEdgeColor;

//溶解
sampler2D _NoiseTex; float4 _NoiseTex_ST;
sampler2D _RampTex; float4 _RampTex_ST;
half _DissolveDir;
half _DissolveWidth;
half4 _DissolveSpeed;
half _WorldPosition;
fixed4 _EdgeColor1;
fixed4 _EdgeColor2;
half _EdgeColorWidth;



//KTEffect_Skill/Fresnel_Add
fixed _Fresnel;


//Dissolve
sampler2D _NoiseMap;	float4 _NoiseMap_ST;

//half4 _DiossolveCombine;(等写完编辑器脚本后整合为一个)
half _DissolvePosition; 

// Abstraction over Light shading data.
struct LWRP_Light
{
	half3   direction;
	half4   lightPos;
	half3   color;
	half    distanceAttenuation;
	half    shadowAttenuation;
};



fixed _AlphaScale;

//Flicker
half4 _DurationMinscale;

struct LandTerrain_Output {

	UNITY_POSITION(pos);
	half4 blend : COLOR; // blendsA
	float4 blend2:TEXCOORD7;
	float4 uv : TEXCOORD0; // posWorld
	//float4 normail : NORMAIL; // wNormal

	float4 tangentToWorldAndPackedData[3]    : TEXCOORD1;
	float4 ambientOrLightmapUV : TEXCOORD4;
	UNITY_SHADOW_COORDS(5)
		UNITY_FOG_COORDS(6)
		float3 eyeVec : TEXCOORD8;
};

//-------------------------------------------------------------------------------------
// Input functions
struct TerrainInput
{
	float4 vertex   : POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float4 uv0      : TEXCOORD0;
	float4 uv1      : TEXCOORD1;
};
struct TerrainOutput
{
	float4 pos                          : SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float4 tex                          : TEXCOORD0;
	float4 posWorld                 : TEXCOORD1;
	UNITY_LIGHTING_COORDS(2,3)
	UNITY_VERTEX_OUTPUT_STEREO
};
struct FarSceneInput
{
	float4 vertex   : POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float2 uv0      : TEXCOORD0;
	float2 uv1      : TEXCOORD1;
	half3 normal    : NORMAL;
};
struct FarSceneOutput
{
	float4 pos                          : SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float2 tex                          : TEXCOORD0;
	float3 normal						: NORMAL;
	float4 posWorld						: TEXCOORD1;
	float3 eyeVec                        : TEXCOORD2;
	float4 ambientOrLightmapUV           : TEXCOORD3;
};
struct VertexInput
{
	//uv1.xy和uv2.xy被用于采样lightmap图，参考VertexGIForward函数
	float4 vertex   : POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	half3 normal    : NORMAL;
	float4 uv0      : TEXCOORD0;
	float4 uv1      : TEXCOORD1;
	//#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
	float4 uv2      : TEXCOORD2;
	//#endif
	float4 uv3:TEXCOORD3;
	//#ifdef _TANGENT_TO_WORLD
	half4 tangent   : TANGENT;
	//#endif
	//half4 texcoord3:TEXCOORD4;
	fixed4 vertexColor : COLOR;
	float4 custom1 : TEXCOORD4;
};
struct FragmentCommonData
{
	half3 diffColor, specColor;
	// Note: smoothness & oneMinusReflectivity for optimization purposes, mostly for DX9 SM2.0 level.
	// Most of the math is being done on these (1-x) values, and that saves a few precious ALU slots.
	fixed oneMinusReflectivity, smoothness,metallic;
	fixed3 normalWorld;
	half3	eyeVec;
	float3 posWorld;
	fixed alpha;
	fixed3 albedo;
	fixed3 bakedGI;
	half3 normalMap;

#if UNITY_STANDARD_SIMPLE
	half3 reflUVW;
#endif

#if UNITY_STANDARD_SIMPLE
	fixed3 tangentSpaceNormal;
#endif
	half DecalMapWeight;
#if BODY_ICE
	half BodyIceWeight;
#endif
};
// ----------------------------------------------------------------------------
// GlossyEnvironment - Function to integrate the specular lighting with default sky or reflection probes
// ----------------------------------------------------------------------------
struct KTUnity_GlossyEnvironmentData
{
	// - Deferred case have one cubemap
	// - Forward case can have two blended cubemap (unusual should be deprecated).

	// Surface properties use for cubemap integration
	half    roughness; // CAUTION: This is perceptualRoughness but because of compatibility this name can't be change :(
	half3   reflUVW;
};

struct VertexOutputForwardDissolve
{
		float4 pos                          : SV_POSITION;
		UNITY_VERTEX_INPUT_INSTANCE_ID
		float4 tex                          : TEXCOORD0;
		half3 eyeVec                        : TEXCOORD1;
		float4 tangentToWorldAndPackedData[3]: TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
		half4 ambientOrLightmapUV           : TEXCOORD5;
		float4 modelWorld                 : TEXCOORD6;

		// SH or Lightmap UV
		UNITY_SHADOW_COORDS(7)

		UNITY_VERTEX_OUTPUT_STEREO
};

struct VertexOutputForwardBase
{
	float4 pos                          : SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
#if CARDTOOL_CHARACTER_BODY
	half3 CarToolVertexNormal            : NORMAL;
#endif
	half4 tex                          : TEXCOORD0;
	half3 eyeVec                        : TEXCOORD1;
	float4 tangentToWorldAndPackedData[3]: TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
	half4 ambientOrLightmapUV           : TEXCOORD5;   
	// SH or Lightmap UV
	UNITY_LIGHTING_COORDS(6,7)

		// next ones would not fit into SM2.0 limits, but they are always for SM3.0+
#if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT||UV3
		float4 posWorld                 : TEXCOORD8;
#elif SCENE_FLUOROSCOPY
		half4 screenPos                 : TEXCOORD8;
#endif

#if EFFECT_HUE_VARIATION
	half4 vertexColor : COLOR;
#endif

float4 customoff : TEXCOORD9;

		UNITY_VERTEX_OUTPUT_STEREO
};

struct VertexOutputForwardAdd
{
	float4 pos                          : SV_POSITION;
	float4 tex                          : TEXCOORD0;
	half3 eyeVec                        : TEXCOORD1;
	float4 tangentToWorldAndLightDir[3]  : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:lightDir]
	float3 posWorld                     : TEXCOORD5;
	UNITY_SHADOW_COORDS(6)
		UNITY_FOG_COORDS(7)
		UNITY_VERTEX_OUTPUT_STEREO
};

sampler2D _WindMap; 
sampler2D sampler_WindMap;
float4 _GlobalWindParams;
//X: Strength
//W: (int bool) Wind zone present
float _WindStrength;
//Nature Renderer parameters
float4 GlobalWindDirectionAndStrength;
//X: Gust dir X
//Y: Gust dir Y
//Z: Gust speed
//W: Gust strength
float4 _GlobalShiver;
//X: Shiver speed
//Y: Shiver strength




float4 _BendMapUV;
sampler2D _BendMap;
float4 _BendMap_TexelSize;
float4 _ScaleBiasRT;


struct WindSettings
{
	float mask;
	float ambientStrength;
	float speed;
	float4 direction;
	float swinging;

	float randObject;
	float randVertex;
	float randObjectStrength;

	float gustStrength;
	float gustFrequency;
};


struct BendSettings
{
	uint mode;
	float mask;
	float pushStrength;
	float flattenStrength;
	float perspectiveCorrection;
};

struct GrassVertexData {
	//Positions
	float3 positionWS; // World space position
	float3 positionVS; // View space position
	float4 positionCS; // Homogeneous clip space position
	float4 positionNDC;// Homogeneous normalized device coordinates

	//Normals
	float3 tangentWS;
	float3 bitangentWS;
	float3 normalWS;
};


#endif // _KTSS_INPUT_H_
