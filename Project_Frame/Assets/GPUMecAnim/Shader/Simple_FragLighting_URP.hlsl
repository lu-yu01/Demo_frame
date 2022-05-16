#ifndef _SIMPLE_FRAGLIGHTING_URP_HEADER
#define _SIMPLE_FRAGLIGHTING_URP_HEADER

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct v2f
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 worldNormal : TEXCOORD1;
    float4 worldTangent : TEXCOORD2;

    UNITY_VERTEX_INPUT_INSTANCE_ID // necessary only if you want to access instanced properties in fragment Shader.
};

sampler2D _MainTex;
float4 _MainTex_ST;

real4 frag(v2f i) : SV_Target
{
    // sample the texture
    UNITY_SETUP_INSTANCE_ID(i); // necessary only if any instanced properties are going to be accessed in the fragment Shader.

    real4 col = tex2D(_MainTex, i.uv);

    real3 normalDir = normalize(i.worldNormal);

    real3 lightDir = normalize(_MainLightPosition.xyz);

    real3 diffuse = _MainLightColor.rgb * max(dot(normalDir, lightDir), 0);

    col += float4(diffuse, 1);

    return col;
}

#endif //_SIMPLE_FRAGLIGHTING_URP_HEADER