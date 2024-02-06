Shader "GM5/GrubUnlit"
{
    Properties
    {
        [MainTexture] _BaseMap("Texture", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1, 1, 1, 1)
        //_Cutoff("AlphaCutout", Range(0.0, 1.0)) = 0.5
       // [HDR] _EmissionColor("Emission Color", Color) = (0,0,0)
      //  [NoScaleOffset]_EmissionMap("Emission Map", 2D) = "white" {}

      //  [ToggleOff] _IsReceiveDN("�Ƿ�����ҹϵͳӰ��", Float) = 1.0
      //  [ToggleOff] _IsAmbientColor("是否使用环境光", Float) = 0

      //  [Header(Alpha)]
	  //  [Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 1
      //  _Cutoff("_Cutoff (Alpha Cutoff)", Range(0.0, 1.0)) = 0.5 // alpha clip threshold
        
        [Header(Shadow)]
        _GroundHeight("_GroundHeight", Float) = 1
        _ShadowColor("_ShadowColor", Color) = (1,1,1,1)
        _ShadowDir ("ShadowDir", vector) = (1,1,1,1)

        // BlendMode
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("Src", Float) = 1.0
        [HideInInspector] _DstBlend("Dst", Float) = 0.0
        [HideInInspector] _ZWrite("ZWrite", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0

        // Editmode props
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0

        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (0.5, 0.5, 0.5, 1)
        [HideInInspector] _SampleGI("SampleGI", float) = 0.0 // needed from bakedlit
    }

    SubShader
    {
         Tags
           {
              "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel"="4.5"
           }
        Pass
        {
            Name "ForwardLit"
            Tags
           {
              "LightMode" = "UniversalForward"
           }
        
          LOD 100

          Blend [_SrcBlend][_DstBlend]
          ZWrite [_ZWrite]
          Cull [_Cull]
            HLSLPROGRAM
            #include "GrubUnlitInput.hlsl"
            #pragma target 4.0

            #pragma vertex vert
            #pragma fragment frag
            //#pragma shader_feature _ALPHATEST_ON
            //#pragma shader_feature _ALPHAPREMULTIPLY_ON
            //#pragma shader_feature _EMISSION
           // #pragma shader_feature _ISRECEIVEDN_OFF
           // #pragma shader_feature _IsAmbientColor_OFF

            // -------------------------------------
            // Unity defined keywords
            //#pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

           

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float fogCoord : TEXCOORD2;
                float4 vertex : SV_POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            uniform float4 _SkyColor;
            uniform float4 _baseColorline;

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half2 uv = input.uv;
                half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                // #ifdef _IsAmbientColor_OFF
                // if(_baseColorline.r == 0) // 增加热更新兼容
                // {
                //    _baseColorline = float4(1,1,1,1);
                // }
                // _BaseColor.rgb *= _baseColorline; 
                // #endif
                half3 color = texColor.rgb * _BaseColor.rgb;
                half alpha = texColor.a * _BaseColor.a;
                AlphaDiscard(alpha, _Cutoff);
              

                // #ifdef _ALPHAPREMULTIPLY_ON
                // color *= alpha;
                // #endif

                //#ifdef _EMISSION
               // color += _EmissionColor;
                //#endif

                //color = MixFog(color, input.fogCoord);
                half4 finalColor;
                // #ifdef _ISRECEIVEDN_OFF
                // finalColor = half4(color, alpha) * _SkyColor;
                // #else
                finalColor = half4(color, alpha);
             //   #endif
                return finalColor;
            }
            ENDHLSL
        }

         Pass
        {
            Name "PlanarShadow"
            Tags { "LightMode" = "SRPDefaultUnlit"}
            //用使用模板测试以保证alpha显示正确
            Stencil
            {
                Ref 0
                Comp Equal
                WriteMask 255
                ReadMask 255
                Pass Invert
                Fail Keep
                ZFail Keep
            }

            //透明混合模式
            Blend SrcAlpha OneMinusSrcAlpha

           ZWrite Off
          // Cull Back
          //ColorMask RGB

            //深度稍微偏移防止阴影与地面穿插
           // Offset -1 , 0

            HLSLPROGRAM
          
            #pragma multi_compile_instancing
             #pragma multi_compile _ DOTS_INSTANCING_ON
             #include "GrubUnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag
            
            struct appdata
            {
                float4 vertex : POSITION;
                //float2 uv : TEXCOORD0;
                 UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                //float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float3 ShadowProjectPos(float4 vertPos)
            {
                float3 shadowPos;
                //得到顶点的世界空间坐标
               float3 worldPos = mul(unity_ObjectToWorld , vertPos).xyz;
                //灯光方向
               // Light mainLight = GetMainLight();
               // float3 lightDir = float3(1,1,1);
                //阴影的世界空间坐标（低于地面的部分不做改变）
                shadowPos.y = min(worldPos.y , _GroundHeight);
                shadowPos.xz = worldPos.xz - _ShadowDir.xz * max(0 , worldPos.y - _GroundHeight) / _ShadowDir.y; 
                return shadowPos;
            }
            
            v2f vert (appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                //得到阴影的世界空间坐标
                float3 shadowPos = ShadowProjectPos(v.vertex);
                o.vertex = TransformWorldToHClip(shadowPos);
                //阴影颜色
                o.color = _ShadowColor;
               // o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                return i.color;
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}