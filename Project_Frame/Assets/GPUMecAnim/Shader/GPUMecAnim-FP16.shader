Shader "GPUMecAnim/VertAnimation"
{
    //https://docs.unity3d.com/Manual/GPUInstancing.html
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _VertPosTex("Vert Pos Texture", 2DArray) = "black"{}
        _NormTex("Norm Pos Texture", 2DArray) = "black"{}
        [Toggle(ANIM_ENABLE_HIGH_QUALITY)] _HighQuality("HighQuality", Float) = 1
        //[ShowAsVector2] _PosRange("PosRange",Vector) = (0,0,0,0)
        //_AnimY("AnimY",Float) = 0
        //_PreAnimY("PreAnimY",Float) = 0
        //_BlendWeight("BlendWeight",Float) = 0
        //_TexArrayIdx("TexArrayIdx",Int) = 0

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert_vat
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile ___ ANIM_IS_PLAYING
            #pragma multi_compile ___ ANIM_ENABLE_HIGH_QUALITY
            #pragma multi_compile ___ ANIM_BLENDING

            #include "GPUMecAnim_VAT_URP.hlsl"
            
            ENDHLSL
        }
    }
}
