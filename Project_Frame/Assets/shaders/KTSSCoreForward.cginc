



#include "BS_KTSSBRDF.cginc"

    VertexOutputForwardBase vertBase (VertexInput v) { return vertForwardBase(v); }
    //VertexOutputForwardAdd vertAdd (VertexInput v) { return vertForwardAdd(v); }
	half4 fragBase (VertexOutputForwardBase i) : SV_Target { return fragForwardBaseInternal(i); }
    //half4 fragAdd (VertexOutputForwardAdd i) : SV_Target { return fragForwardAddInternal(i, (half4)1, (float3)1, (float4)0); }

