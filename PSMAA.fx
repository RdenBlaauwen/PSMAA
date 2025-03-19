#define SMAA_PRESET_CUSTOM
#define SMAA_CUSTOM_SL 1

#include "ReShadeUI.fxh"

uniform float _EdgeDetectionThreshold < __UNIFORM_DRAG_FLOAT1
	ui_label = "Edge Threshold";
	ui_min = 0.050; ui_max = 0.15; ui_step = 0.001;
> = 0.09;

uniform float _ContrastAdaptationFactor < __UNIFORM_DRAG_FLOAT1
	ui_label = "Local Contrast Adaptation Factor";
	ui_min = 1.5; ui_max = 4.0; ui_step = 0.1;
	ui_tooltip = "High values increase anti-aliasing effect, but may increase artifacts.";
> = 2.0;

uniform int _Debug < __UNIFORM_COMBO_INT1
  ui_label = "Debug output";
  ui_items = "None\0Deltas\0Edges\0";
> = 0;

#include "ReShade.fxh"

// Libraries
#include ".\reshade-shared\functions.fxh"
#include ".\reshade-shared\color.fxh"

// Sources files
#include ".\PSMAA.fxh"

#define SMAA_RT_METRICS PSMAA_BUFFER_METRICS

#define SMAATexture2D(tex) PSMAATexture2D(tex)
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
#define SMAASampleLevelZeroPoint(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
#define SMAASampleLevelZeroOffset(tex, coord, offset) tex2Dlod(tex, float4(coord + offset * SMAA_RT_METRICS.xy, 0.0, 0.0))
#define SMAASample(tex, coord) tex2D(tex, coord)
#define SMAASamplePoint(tex, coord) PSMAASamplePoint(tex, coord)
#define SMAASampleOffset(tex, coord, offset) tex2D(tex, coord + offset * SMAA_RT_METRICS.xy)
#define SMAA_FLATTEN [flatten]
#define SMAA_BRANCH [branch]

#include ".\SMAA.fxh"


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
};
sampler deltaSampler
{
  Texture = deltaTex;
};

texture edgesTex < pooled = true; >
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG8;
};
sampler edgesSampler
{
	Texture = edgesTex;
};

void PSMAADeltaCalulationVSWrapper(
  in uint id : SV_VertexID, 
  out float4 position : SV_Position, 
  out float2 texcoord : TEXCOORD0, 
  out float4 offset[1] : TEXCOORD1
)
{
  PostProcessVS(id, position, texcoord);
  PSMAA::Pass::DeltaCalculationVS(texcoord, offset);
}

void PSMAADeltaCalulationPSWrapper(
  float4 position : SV_Position,
  float2 texcoord : TEXCOORD0, 
  float4 offset[1] : TEXCOORD1, 
  out float2 deltas : SV_Target0
)
{
  PSMAA::Pass::DeltaCalculationPS(texcoord, offset, colorGammaSampler, deltas);
}

void PSMAAEdgeDetectionVSWrapper(
	in uint id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
	out float4 offset[3] : TEXCOORD1
)
{
	PostProcessVS(id, position, texcoord);
	SMAAEdgeDetectionVS(texcoord, offset);
}

void PSMAAEdgeDetectionPSWrapper(
  float4 position : SV_Position,
  float2 texcoord : TEXCOORD0, 
  float4 offset[3] : TEXCOORD1, 
  out float2 edges : SV_Target
)
{
  PSMAA::Pass::EdgeDetectionPS(texcoord, offset, deltaSampler, _EdgeDetectionThreshold, _ContrastAdaptationFactor, edges);
  // PSMAA::Pass::HybridDetection(texcoord, offset, colorGammaSampler, _EdgeDetectionThreshold, _ContrastAdaptationFactor, edges);
}

void SMAANeighborhoodBlendingWrapVS(
	in uint id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
	out float4 offset : TEXCOORD1)
{
	PostProcessVS(id, position, texcoord);
	SMAANeighborhoodBlendingVS(texcoord, offset);
}


void PSMAABlendingPSWrapper(
	float4 position : SV_Position,
  float2 texcoord : TEXCOORD0, 
  float4 offset : TEXCOORD1,  
  out float4 color : SV_Target
)
{
  if(_Debug == 0) discard;

  if(_Debug == 1) {
    color = tex2D(deltaSampler, texcoord).rgba;
  } else if(_Debug == 2) {
    color = tex2D(edgesSampler, texcoord).rgba;
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
  pass EdgeDetection
  {
    VertexShader = PSMAAEdgeDetectionVSWrapper;
    PixelShader = PSMAAEdgeDetectionPSWrapper;
    RenderTarget = edgesTex;
    ClearRenderTargets = true;
		StencilEnable = true;
		StencilPass = REPLACE;
		StencilRef = 1;
  }
  pass Blending
  {
    // TODO: consider renaming this VSWrapper to something more generic
    // alternatively, Consider giving this pass it's own VS
    VertexShader = SMAANeighborhoodBlendingWrapVS;
    PixelShader = PSMAABlendingPSWrapper;
		SRGBWriteEnable = true;
  }
}