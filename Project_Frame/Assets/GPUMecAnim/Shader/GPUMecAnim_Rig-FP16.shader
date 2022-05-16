// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "GPUMecAnim/RigAnimation"
{
    //https://docs.unity3d.com/Manual/GPUInstancing.html
    Properties
    {
        [Toggle(_ENABLE_JOINT)]
        _EnableJoint("是否是挂点", Float) = 0

        _MainTex("Texture", 2D) = "white" {}
        _RigTex("Rig Texture", 2D) = "black"{}
        //_BoneId("指定Tick骨骼ID",int) = 0
        //_AnimY("AnimY",Float) = 0
        //_PreAnimY("PreAnimY",Float) = 0
        //_OffsetX("OffsetX",Float) = 0
        //_PreOffsetX("PreOffsetX",Float) = 0


        //_BlendWeight("BlendWeight",Float) = 0
        //_BoneSampleQuality("Bone Sample Quality",Int) = 0

        [Toggle(ISRECEIVEDN)]
        _FillWithRed("是否受光照影响", Float) = 0
    }

    HLSLINCLUDE
    #include "GPUMecAnim_Rig_URP.hlsl"    
	uniform float4 _SkyColor;		

    real4 frag_GM5(v2f i) : SV_Target
    {
        UNITY_SETUP_INSTANCE_ID(i);
        float4 col = tex2D(_MainTex, i.uv);
		#ifdef ISRECEIVEDN
			col *= _SkyColor;
		#endif
		return col;
	}

    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert_rigOrJoint
            #pragma fragment frag_GM5
            #pragma shader_feature ISRECEIVEDN
            #pragma shader_feature _ENABLE_JOINT
            #pragma multi_compile_instancing   
            #pragma multi_compile ___ ANIM_IS_PLAYING
            #pragma multi_compile ___ ANIM_BLENDING
            ENDHLSL
        }
    }
}
