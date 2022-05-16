#ifndef _GPUMECANIM_RIG_URP_HEADER
#define _GPUMECANIM_RIG_URP_HEADER

#include "Simple_FragLighting_URP.hlsl"

struct appdata_rig
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;

    float4 boneId : TEXCOORD1;
    float4 boneWeight : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


UNITY_INSTANCING_BUFFER_START(Props)
UNITY_DEFINE_INSTANCED_PROP(float, _OffsetX)
UNITY_DEFINE_INSTANCED_PROP(float, _PreOffsetX)
UNITY_DEFINE_INSTANCED_PROP(float, _AnimY)
UNITY_DEFINE_INSTANCED_PROP(float, _PreAnimY)
UNITY_DEFINE_INSTANCED_PROP(float, _BlendWeight)
UNITY_DEFINE_INSTANCED_PROP(int, _JointBoneId)
UNITY_DEFINE_INSTANCED_PROP(float4x4, _LocalScaleMatrix)
UNITY_DEFINE_INSTANCED_PROP(float4x4, _RootLocalToWorld)
//UNITY_DEFINE_INSTANCED_PROP(int, _BoneSampleQuality)
UNITY_INSTANCING_BUFFER_END(Props)

sampler2D _RigTex;
float4 _RigTex_TexelSize;


float4 GetMatrixRow(float x, float y, float offsetX)
{
    x = (x * _RigTex_TexelSize.x) + offsetX;

    return tex2Dlod(_RigTex, float4(x, y, 0, 0));

}

float4x4 GetMatrix(float x, float y, float offsetX)
{
    float4 mat0 = GetMatrixRow(x, y, offsetX);
    float4 mat1 = GetMatrixRow(x + 1, y, offsetX);
    float4 mat2 = GetMatrixRow(x + 2, y, offsetX);
    float4 mat3 = float4(0, 0, 0, 1);

    float4x4 mat = float4x4(mat0, mat1, mat2, mat3);
    return mat;
}

float4x4 GetJointMatrix(float x, float y, float offsetX)
{
    float4x4 localScaleMatrix = UNITY_ACCESS_INSTANCED_PROP(Props, _LocalScaleMatrix);
    float4x4 rootLocalToWorldMatix = UNITY_ACCESS_INSTANCED_PROP(Props, _RootLocalToWorld);
    float4x4 mat = GetMatrix(x, y, offsetX);

    mat = mul(mat, localScaleMatrix);
    mat = mul(rootLocalToWorldMatix, mat);
    return mat;
}

void SampleBoneAnimation(appdata_rig v, inout float4 vertPos, inout float3 normal)
{
    float y = UNITY_ACCESS_INSTANCED_PROP(Props, _AnimY);
    float offsetX = UNITY_ACCESS_INSTANCED_PROP(Props, _OffsetX);
    //int sampleQuality = UNITY_ACCESS_INSTANCED_PROP(Props, _BoneSampleQuality);
    vertPos = float4(0, 0, 0, 1);
    normal = float3(0, 0, 0);

    for (int i = 0; i < 4; i++)
    {
        float weight = v.boneWeight[i];
        if (weight > 0)
        {
            int x = v.boneId[i] * 3;
            float4x4 mat = GetMatrix(x, y, offsetX);
#if ANIM_BLENDING
            float preY = UNITY_ACCESS_INSTANCED_PROP(Props, _PreAnimY);
            float preOffsetX = UNITY_ACCESS_INSTANCED_PROP(Props, _PreOffsetX);
            float blendWeight = UNITY_ACCESS_INSTANCED_PROP(Props, _BlendWeight);
            float4x4 preMat = GetMatrix(x, preY, preOffsetX);
            mat = lerp(preMat, mat, blendWeight);
#endif
            vertPos += (mul(mat, v.vertex) * weight);
            normal += (mul((float3x3)mat, v.normal) * weight);
        }
    }
}
void SampleJointAnimation(appdata_rig v, inout float4 vertPos, inout float3 normal)
{
    int x = UNITY_ACCESS_INSTANCED_PROP(Props, _JointBoneId) * 3;
    float y = UNITY_ACCESS_INSTANCED_PROP(Props, _AnimY);
    float offsetX = UNITY_ACCESS_INSTANCED_PROP(Props, _OffsetX);

    float4x4 mat = GetJointMatrix(x, y, offsetX);

    vertPos = mul(mat, v.vertex);
    normal = mul((float3x3)mat, v.normal);
#if ANIM_BLENDING
    float preY = UNITY_ACCESS_INSTANCED_PROP(Props, _PreAnimY);
    float preOffsetX = UNITY_ACCESS_INSTANCED_PROP(Props, _PreOffsetX);
    float blendWeight = UNITY_ACCESS_INSTANCED_PROP(Props, _BlendWeight);
    float4x4 preMat = GetJointMatrix(x, preY, preOffsetX);

    float4 preVertPos = mul(preMat, v.vertex);
    float3 preNormal = mul(preMat, v.normal);

    vertPos = lerp(preVertPos, vertPos, blendWeight);
    normal = lerp(preNormal, normal, blendWeight);
#endif
}


v2f vert_rigOrJoint(appdata_rig v, uint vid : SV_VertexID)
{
    v2f o;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o); // necessary only if you want to access instanced properties in the fragment Shader.
    float4 vertPos = v.vertex;
    float3 normal = v.normal;

#if ANIM_IS_PLAYING
#if _ENABLE_JOINT
    SampleJointAnimation(v, vertPos, normal);
    o.vertex = mul(UNITY_MATRIX_VP, vertPos);
#else 
    SampleBoneAnimation(v, vertPos, normal);
    o.vertex = TransformObjectToHClip(vertPos.xyz);
#endif
#else
    o.vertex = TransformObjectToHClip(vertPos.xyz);
#endif        
    o.worldNormal = mul(normal, (float3x3) unity_WorldToObject);
    o.worldTangent = mul(unity_ObjectToWorld, v.tangent);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    return o;

}

#endif //_GPUMECANIM_RIG_URP_HEADER