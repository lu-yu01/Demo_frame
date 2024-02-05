﻿Shader "KTGame/KT_PlanarShadow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_ShadowInvLen("ShadowInvLen", float) = 1.0
    	_ShadowFadeParams("_ShadowFadeParams", Vector) = (0.0, 1.5, 0.7, 0.0)
    	_ShadowPlane  ("ShadowPlane", vector) = (0,1,0,0)
    	_ShadowColor ("ShadowColor", vector) = (0,0,0,1)
    }

    SubShader
    {
        Tags { "LightMode" = "LightweightForward" "RenderType"="Opaque" "Queue" = "Geometry+120" }
        LOD 100

        Pass
        {
        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                //UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                //UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                //UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
			}
				ENDCG
		}

		Pass
		{
			 Tags { "LightMode" = "SRPDefaultUnlit"}
			Name "PlanarShadow"
			//Tags { "LightMode" = "Always" }

			Blend SrcAlpha OneMinusSrcAlpha
			//ZWrite Off
			//Cull Back
			//ColorMask RGB

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

		HLSLPROGRAM
		    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#pragma vertex vert
			#pragma fragment frag

			float4 _ShadowPlane;
			float4 _ShadowProjDir;
			float4 _WorldPos;
			float _ShadowInvLen;
			float4 _ShadowFadeParams;
			//float _ShadowFalloff;
			float4 _ShadowColor;

			struct appdata
			{
				float4 vertex			: POSITION;
			};

			struct v2f
			{
				float4 vertex			: SV_POSITION;
				float3 xlv_TEXCOORD0	: TEXCOORD0;
				float3 xlv_TEXCOORD1	: TEXCOORD1;
			};

			v2f vert(appdata v)
			{
				v2f o;
				 //灯光方向
                Light mainLight = GetMainLight();
                float3 lightdir = normalize(mainLight.direction);
				//float3 lightdir = normalize(_ShadowProjDir);
				float3 worldpos = mul(unity_ObjectToWorld, v.vertex).xyz;
				 //_ShadowPlane = float4(0,1,0,0);
				float distance = dot(_ShadowPlane.xwz - worldpos, _ShadowPlane.xyz) / dot(_ShadowPlane.xyz, lightdir.xyz);
				worldpos = worldpos + distance * lightdir.xyz;
				o.vertex = mul(unity_MatrixVP, float4(worldpos, 1.0));
				o.xlv_TEXCOORD0 = worldpos.xyz;
				o.xlv_TEXCOORD1 = worldpos;
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float3 posToPlane_2 = (i.xlv_TEXCOORD0 - i.xlv_TEXCOORD1);
				float4 color;

				//_ShadowInvLen = 0.3;
				color.xyz = _ShadowColor.xyz;
				//_ShadowFadeParams = float4(0.0, 1.5, 0.7, 0.0);
				color.w = (pow((1.0 - clamp(((sqrt(dot(posToPlane_2, posToPlane_2)) * _ShadowInvLen) - _ShadowFadeParams.x), 0.0, 1.0)), _ShadowFadeParams.y) * _ShadowFadeParams.z) * _ShadowColor.w;

				return color;
			}

		ENDHLSL
		}
    }
}
