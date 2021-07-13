#ifndef __KTSS_CORE_FORWARD_CGINC__
#define __KTSS_CORE_FORWARD_CGINC__

#if defined(UNITY_NO_FULL_STANDARD_SHADER)
#   define UNITY_STANDARD_SIMPLE 1
#endif

//#include "CGCommon/KTSSConfig.cginc"


    #include "BS_KTSSBRDF.cginc"


    VertexOutputForwardBase vertBase (VertexInput v) { return vertForwardBase(v); }
    VertexOutputForwardAdd vertAdd (VertexInput v) { return vertForwardAdd(v); }
	half4 fragBase (VertexOutputForwardBase i) : SV_Target { return fragForwardBaseInternal(i); }
    //half4 fragAdd (VertexOutputForwardAdd i) : SV_Target { return fragForwardAddInternal(i, (half4)1, (float3)1, (float4)0); }

	
		


#endif//__KTSS_CORE_FORWARD_CGINC__