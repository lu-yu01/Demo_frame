#ifndef _GPUMECANIM_VAT_URP_HEADER
#define _GPUMECANIM_VAT_URP_HEADER

#include "Simple_FragLighting_URP.hlsl"

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};



UNITY_INSTANCING_BUFFER_START(Props)
    UNITY_DEFINE_INSTANCED_PROP(int, _TexArrayIdx)
    UNITY_DEFINE_INSTANCED_PROP(float2, _PosRange)
    UNITY_DEFINE_INSTANCED_PROP(float, _OffsetX)
    UNITY_DEFINE_INSTANCED_PROP(float, _PreOffsetX)
    UNITY_DEFINE_INSTANCED_PROP(float, _AnimY)
    UNITY_DEFINE_INSTANCED_PROP(float, _PreAnimY)
    UNITY_DEFINE_INSTANCED_PROP(float, _BlendWeight) 
UNITY_INSTANCING_BUFFER_END(Props)

TEXTURE2D_ARRAY(_VertPosTex); SAMPLER(sampler_VertPosTex);
TEXTURE2D_ARRAY(_NormTex); SAMPLER(sampler_NormTex);

float4 _VertPosTex_TexelSize;
float4 _NormTex_TexelSize;

float3 CalcNormalBasedOnXY(float x, float y, float z_sign)
{
    // z_sign need to remap from {0,1} to {-1,1}
    z_sign = z_sign * 2 - 1;

    float z = sqrt(saturate(1 - x * x - y * y)) * z_sign;

    return float3(x, y, z);
}

float4x4 QuaternionToMatrix(float4 q)
{
    //https://www.cnblogs.com/bbsno1/archive/2013/08/18/3266744.html

    float x2 = pow(q.x, 2);
    float y2 = pow(q.y, 2);
    float z2 = pow(q.z, 2);
    float w2 = pow(q.w, 2);
    float xy = q.x * q.y;
    float xz = q.x * q.z;
    float xw = q.x * q.w;
    float yz = q.y * q.z;
    float yw = q.y * q.w;
    float zw = q.z * q.w;

    /*
    float4 mat0 = float4(2 * (x2 + w2) - 1, 2 * (xy + zw), 2 * (xz - yw), 0);
    float4 mat1 = float4(2 * (xy - zw),     2 * (y2 + w2) - 1, 2 * (yz + xw), 0);
    float4 mat2 = float4(2 * (xz + yw),     2 * (yz - xw),     2 * (z2 + w2) - 1, 0);*/
    float4 mat0 = float4(1 - 2 * (y2 + z2), 2 * (xy - zw), 2 * (xz + yw), 0);
    float4 mat1 = float4(2 * (xy + zw), 1 - 2 * (x2 + z2), 2 * (yz - xw), 0);
    float4 mat2 = float4(2 * (xz - yw), 2 * (yz + xw), 1 - 2 * (x2 + y2), 0);
    float4 mat3 = float4(0, 0, 0, 1);
    float4x4 mat = float4x4(mat0, mat1, mat2, mat3);
    return mat;
    
}

void SampleNormalTangent(int vid, float offsetX, float y, int texArrIdx, inout float3 normal, inout float3 tangent)
{
    // Dealing with normal and tangent 
    float4 normTangent = SAMPLE_TEXTURE2D_ARRAY_LOD(_NormTex, sampler_NormTex, float2(vid * _NormTex_TexelSize.x + offsetX, y), texArrIdx, 0);

    // remap from [0,1] to [-1,1]
    normTangent = normTangent * 2 - float4(1, 1, 1, 1);
    /*
        //               normal+                 normal-
        //  tangent+  3(11 in binary)       1(01 in binary)
        //  tangent-  2(10 in binary)       0(00 in binary)
        float z_sign = lowPosAndNrmSign.w * 10;//  mul 10, sign become to 0,1,2,3, then use binary trick to decode
        float norm_sign = floor(z_sign / 2);
        float tangent_sign = z_sign - 2 * norm_sign;

        normal = CalcNormalBasedOnXY(normTangent.x, normTangent.y, norm_sign);
        tangent.xyz = CalcNormalBasedOnXY(normTangent.z, normTangent.w, tangent_sign);
     */
    float4x4 mat = QuaternionToMatrix(normTangent);
    normal = float3(mat[0].z, mat[1].z, mat[2].z);
    tangent.xyz = float3(mat[0].y, mat[1].y, mat[2].y);
}

void SampleVertPos(int vid, float offsetX, float y, int texArrIdx, float2 posRange,inout float3 vertPos)
{
    // data need to be decoded:  |       X      |       Y      |       Z      |    // rgb_low means first pixel, rgb_high means second pixel. 
    // data in texture           | r_low r_high | g_low g_high | g_low g_high |    // Such separation can reduce sample in case we want a lower precision of animation.
    float x1 = (2 * vid ) * _VertPosTex_TexelSize.x + offsetX;
    float3 pos_low = SAMPLE_TEXTURE2D_ARRAY_LOD(_VertPosTex, sampler_VertPosTex, float2(x1, y), texArrIdx, 0).xyz;
    ////decode first, then recover
    float n = posRange.x;
    float diff = posRange.y - n;

#if ANIM_ENABLE_HIGH_QUALITY
    float x2 = x1 + _VertPosTex_TexelSize.x;
    float3 pos_high = SAMPLE_TEXTURE2D_ARRAY_LOD(_VertPosTex, sampler_VertPosTex, float2(x2, y), texArrIdx, 0).xyz;
    float3 pos_nml = float3(pos_low.x + pos_high.x / 255, pos_low.y + pos_high.y / 255, pos_low.z + pos_high.z / 255);
    vertPos = pos_nml * diff + float3(n, n, n);
#else
    vertPos = pos_low * diff + float3(n, n, n);
#endif
}

v2f vert_vat(appdata v, uint vid : SV_VertexID)
{
    v2f o;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o); // necessary only if you want to access instanced properties in the fragment Shader.
    float3 vertPos = v.vertex.xyz;
    float3 normal = v.normal;
    float4 tangent = v.tangent;

#if ANIM_IS_PLAYING

    float2 posRange = UNITY_ACCESS_INSTANCED_PROP(Props, _PosRange);
    int texArrIdx = UNITY_ACCESS_INSTANCED_PROP(Props, _TexArrayIdx);
    float y = UNITY_ACCESS_INSTANCED_PROP(Props, _AnimY);
    float offsetX = UNITY_ACCESS_INSTANCED_PROP(Props, _OffsetX);

    SampleVertPos(vid, offsetX, y, texArrIdx, posRange, vertPos);
    SampleNormalTangent(vid, offsetX, y, texArrIdx, normal, tangent.xyz);

#if ANIM_BLENDING

    float preY = UNITY_ACCESS_INSTANCED_PROP(Props, _PreAnimY);
    float preOffsetX = UNITY_ACCESS_INSTANCED_PROP(Props, _PreOffsetX);
    float blendWeight = UNITY_ACCESS_INSTANCED_PROP(Props, _BlendWeight);
    float3 preVertPos;
    float3 preNormal;
    float3 preTangent;
    SampleVertPos(vid, preOffsetX, preY, texArrIdx, posRange, preVertPos);
    SampleNormalTangent(vid, preOffsetX, preY, texArrIdx, preNormal, preTangent);

    vertPos = lerp(preVertPos, vertPos, blendWeight);
    normal = lerp(preNormal, normal, blendWeight);
    tangent.xyz = lerp(tangent.xyz, preTangent, blendWeight);
#endif

#endif   
    o.vertex = TransformObjectToHClip(vertPos);
    o.worldNormal = mul(normal, (float3x3) unity_WorldToObject);
    o.worldTangent = mul(unity_ObjectToWorld, tangent);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    return o;
}

#endif //_GPUMECANIM_VAT_URP_HEADER