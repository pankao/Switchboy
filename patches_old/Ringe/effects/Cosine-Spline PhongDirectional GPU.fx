//@author: woei
//@help: creates a cosine spline along 3d coordinates, calcualted on the GPU
//@tags: line, spline, cosine
// PARAMETERS-------------------------------------------------------------------
//transforms
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tWV: WORLDVIEW;
float4x4 tWVP: WORLDVIEWPROJECTION;
#include <effects\PhongDirectional.fxh>

//texture
texture Tex <string uiname="Texture";>;
sampler Samp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (Tex);          //apply a texture to the sampler
    MipFilter = LINEAR;         //sampler states
    MinFilter = LINEAR;
    MagFilter = LINEAR;
	AddressU = clamp;
	AddressU = clamp;
};

float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;
float4x4 tColor <string uiname="Color Transform";>;
float alpha = 1.;

int Size;
texture pTex <string uiname="Position Texture";>;
sampler pSamp = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (pTex);          //apply a texture to the sampler
    MipFilter = POINT;         //sampler states
    MinFilter = POINT;
    MagFilter = POINT;
	AddressU = clamp;
	ADDRESSV = wrap;
};

struct vs2ps
{
    float4 PosWVP: POSITION;
    float4 TexCd : TEXCOORD0;
	float4 PosCd : TEXCOORD1;
    float3 LightDirV: TEXCOORD2;
    float3 ViewDirV: TEXCOORD3;
    float3 Tang : TEXCOORD4;
    float3 Bi : TEXCOORD5;
	float4 Depth : TEXCOORD6;
};
//---- Cosine-Spline -----------------------------------------------------------
struct pota { float4 Pos; float4 Tang; };
pota CosineSpline(float4 p1, float4 p2, float range) {
	pota Out = (pota)0;
	const float PI = 3.14159265359; 
	
	float mu = frac(range);
	float4 l = lerp(p1,p2,mu);
	mu = (1-cos(mu*PI))/2;
	l.yz = (p1.yz*(1-mu)+p2.yz*mu);
	Out.Pos = l;
	
	float4 t = p1-p2;
	mu = PI*sin(PI*mu)*0.5;
	t.yz = p2.yz*mu - p1.yz*mu;
	Out.Tang = t;
	return Out;
}
// VERTEXSHADER-----------------------------------------------------------------
float pitch;
vs2ps VS_Spline(float4 PosO: POSITION, float4 TexCd : TEXCOORD0, float4 PosCd : TEXCOORD1)
{
    vs2ps Out = (vs2ps)0;
    Out.LightDirV = normalize(-mul(lDir, tV));
	
	float cSize = (Size-1)*0.9999;
	float4 cCd = PosCd;	
	cCd.x = floor(cCd.x*(cSize))/cSize;

    float4 p1 = tex2Dlod(pSamp, cCd);
	float4 p2 = tex2Dlod(pSamp, float4(cCd.x+(1./cSize),cCd.yzw));	
    
	pota curve = CosineSpline(p1,p2,PosCd.x*cSize);
    float4 spline = curve.Pos;

    float3 tang = normalize(curve.Tang);
    float3 bitang= normalize(cross(tang,float3(0,sin(pitch),cos(pitch))));	
    PosO.xyz=spline.xyz+(PosO.y*spline.w*bitang);
	
    Out.PosWVP  = mul(PosO, tWVP);	
    Out.TexCd = mul(cCd, tTex);

    //normal in view space
    Out.ViewDirV = -normalize(mul(PosO, tWV));
    Out.Tang = tang;
    Out.Bi = bitang;
	Out.Depth = mul(PosO, tWVP);
    return Out;
}
// PIXELSHADER------------------------------------------------------------------
float4 PS(vs2ps In): COLOR
{
	float4 col = tex2D(Samp, In.TexCd);
    float3 n = normalize(cross(In.Tang,In.Bi));    
    col.rgb *= PhongDirectional(n, In.ViewDirV, In.LightDirV);;
    col.a*=alpha;
    return mul(col, tColor);
}

float4 PS_Depth(vs2ps In): COLOR
{
    float4 col = In.Depth.z;
    col.a =1;
    return col;
}
// TECHNIQUES-------------------------------------------------------------------
technique CosineSpline_PhongDirectional
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_2_0 PS();
    }
}
technique CosineSpline_Depth
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_2_0 PS_Depth();
    }
}