#include "ReShadeUI.fxh"

uniform int Debug < __UNIFORM_COMBO_INT1
  ui_label = "Debug output";
  ui_items = "None\0Deltas\0";
> = 0;

#include "ReShade.fxh"

// Libraries
#include ".\reshade-shared\functions.fxh"
#include ".\reshade-shared\color.fxh"

// Sources files
#include ".\PSMAA.fxh"

texture colorInputTex : COLOR;
sampler colorGammaSampler
{
	Texture = colorInputTex;
	MipFilter = POINT;
};

texture deltaTex < pooled = true; >
{
  Width = BUFFER_WIDTH;
  Height = BUFFER_HEIGHT;
  Format = RG16F;
}
sampler deltaSampler = sampler_state
{
  Texture = deltaTex;
};

void PSMAADeltaCalulationVSWrapper(
  in uint id : SV_VertexID, 
  out float4 position : SV_Position, 
  float2 texcoord : TEXCOORD0, 
  out float4 offset[1] : TEXCOORD1
)
{
  PostProcessVS(id, position, texcoord);
  PSMAA::Pass::DeltaCalculationVS(texcoord, offset);
}

void PSMAADeltaCalulationPSWrapper(
  float2 texcoord : TEXCOORD0, 
  float4 offset[1] : TEXCOORD1, 
  out float2 deltas : SV_Target0
)
{
  PSMAA::Pass::DeltaCalculationPS(texcoord, offset, colorGammaSampler, deltas);
}

void PSMAABlendingPSWrapper(
  float2 texcoord : TEXCOORD0, 
  float4 offset[1] : TEXCOORD1,
  out float4 color : SV_Target
)
{
  if(Debug == 0) discard;

  if(Debug == 1) {
    color = tex2D(deltaSampler, texcoord).rgba;
    return;
  }
}

technique PSMAA
{
  pass DeltaCalculation
  {
    VertexShader = PSMAADeltaCalulationVSWrapper;
    PixelShader = PSMAADeltaCalulationPSWrapper;
    RenderTarget = deltaTex;
    // TODO: test if these are necessary!
    // Especially the stencil stuff
    // https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md#techniques
    ClearRenderTargets = true;
		StencilEnable = true;
		StencilPass = REPLACE;
		StencilRef = 1;
  }
  pass Blending
  {
    // TODO: consider renaming this VSWrapper to something more generic
    // alternatively, Consider giving this pass it's own VS
    VertexShader = PSMAADeltaCalulationVSWrapper;
    PixelShader = PSMAABlendingPSWrapper;
		SRGBWriteEnable = true;
  }
}