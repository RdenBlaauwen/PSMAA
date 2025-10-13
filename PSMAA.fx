#include ".\reshade-shared\macros.fxh"

#define SMAA_PRESET_CUSTOM
#define SMAA_CUSTOM_SL 1

#include "ReShadeUI.fxh"

uniform int _MaxSearchSteps < __UNIFORM_DRAG_INT1
	ui_label = "Max Search Steps";
	ui_min = 0;
	ui_max = 128;
	ui_step = 1;
> = 32;

uniform int _MaxSearchStepsDiag < __UNIFORM_DRAG_INT1
	ui_label = "Max Diagonal Search Steps";
	ui_min = 0;
	ui_max = 64;
	ui_step = 1;
> = 19;

uniform int _CornerRounding < __UNIFORM_DRAG_INT1
	ui_label = "Corner Rounding";
	ui_min = 0;
	ui_max = 100;
	ui_step = 1;
> = 10;

uniform float2 _EdgeDetectionThreshold <
	ui_label = "Edge Threshold";
	ui_type = "slider";
	ui_min = .004;
	ui_max = .15;
	ui_step = .001;
> = float2(.005, .05);

uniform float2 _CMAALCAFactor <
	ui_label = "CMAA LCA Factor";
	ui_type = "slider";
	ui_min = 0;
	ui_max = .3;
	ui_step = .01;
> = float2(.22, .15);

uniform float2 _SMAALCAFactor <
	ui_label = "SMAA LCA Factor";
	ui_type = "slider";
	ui_min = 1.5;
	ui_max = 4f;
	ui_step = .1;
> = float2(2f, 2f);

uniform float2 _CMAALCAforSMAALCAFactor <
	ui_label = "CMAA LCA adjust. of SMAA LCA";
	ui_type = "slider";
	ui_min = -1;
	ui_max = 1;
	ui_step = .01;
> = float2(-.45, 0);

uniform float _ThreshFloor < __UNIFORM_DRAG_FLOAT1
	ui_label = "Threshold floor";
	// TODO: build comprehensive texture + bitrate macro system to replace this sad ui_min value
	ui_min = .004;
	ui_max = .03;
	ui_step = .001;
> = .01;

uniform float _PreProcessingThresholdMultiplier <
	ui_category = "Pre-Processing";
	ui_label = "ThresholdMultiplier";
	ui_type = "slider";
	ui_min = 1f;
	ui_max = 10f;
	ui_step = .1;
	ui_tooltip = "How much higher is the pre-processing threshold than the edge detection threshold?\n"
							"Recommended values [2..6]";
> = 3.5f;

uniform float _PreProcessingCmaaLCAMultiplier <
	ui_category = "Pre-Processing";
	ui_label = "CmaaLCAMultiplier";
	ui_type = "slider";
	ui_min = .1;
	ui_max = 1f;
	ui_step = .01;
	ui_tooltip = "Recommended values [0.25..0.75]";
> = .65;

uniform float _PreProcessingStrength <
	ui_category = "Pre-Processing";
	ui_label = "Strength";
	ui_type = "slider";
	ui_min = 0f;
	ui_max = 1f;
	ui_step = .01;
	ui_tooltip = "Strength of the pre-processing step.\n"
							"Recommended values [0.5..0.85]";
> = .65;

uniform float _PreProcessingStrengthThresh <
	ui_category = "Pre-Processing";
	ui_label = "Strength thresh";
	ui_type = "slider";
	ui_min = 0f;
	ui_max = .15f;
	ui_step = .001;
	ui_tooltip = "Strengths below this val are skipped";
> = .15;

uniform float _PreProcessingLumaPreservationBias <
	ui_category = "Pre-Processing";
	ui_label = "LumaPreservationBias";
	ui_type = "slider";
	ui_min = -.8f;
	ui_max = .8f;
	ui_step = .05;
> = .5f;

uniform float _PreProcessingLumaPreservationStrength <
	ui_category = "Pre-Processing";
	ui_label = "LumaPreservationStrength";
	ui_type = "slider";
	ui_min = 1f;
	ui_max = 3f;
	ui_step = .05;
	ui_tooltip = "1 = normal strength, 5 = max";
> = 1.5f;

uniform float _PreProcessingGreatestCornerCorrectionStrength <
	ui_category = "Pre-Processing";
	ui_label = "Greatest Corner Correction Strength";
	ui_type = "slider";
	ui_min = 0f;
	ui_max = 1f;
	ui_step = .01;
> = .85;

uniform bool _ShowOldPreProcessing <
	ui_category = "Pre-Processing";
	ui_label = "Show Old Pre-Processing";
	ui_tooltip = "Use the old pre-processing method.";
> = false;

uniform bool _SmoothingEnabled <
	ui_category = "Bean Smoothing";
	ui_label = "Enable Bean Smoothing";
> = true;

// uniform bool _OldSmoothingEnabled <
// 	ui_category = "Bean Smoothing";
// 	ui_label = "use old Smoothing";
// > = false;

uniform bool _SmoothingDeltaWeightDebug <
	ui_category = "Bean Smoothing";
	ui_label = "_SmoothingDeltaWeightDebug";
> = false;

uniform float _SmoothingMinDeltaWeight <
	ui_category = "Bean Smoothing";
	ui_label = "_SmoothingMinDeltaWeight";
	ui_type = "slider";
	ui_min = 0f;
	ui_max = .2;
	ui_step = 0.01f;
> = .1;

uniform float _SmoothingMaxDeltaWeight <
	ui_category = "Bean Smoothing";
	ui_label = "_SmoothingMaxDeltaWeight";
	ui_type = "slider";
	ui_min = .15;
	ui_max = .75;
	ui_step = 0.01f;
> = .5;

uniform float _SmoothingDeltaWeightDynamicThreshold <
	ui_category = "Bean Smoothing";
	ui_label = "Dynamic threshold";
	ui_type = "slider";
	ui_min = 0f;
	ui_max = 1f;
	ui_step = 0.01f;
> = .8;

uniform bool _SharpeningEnabled <
	ui_category = "Sharpening";
	ui_label = "Enable CAS Sharpening";
> = false;

uniform bool _UseOldCas <
	ui_category = "Sharpening";
	ui_label = "_UseOldCas";
> = false;

uniform float _SharpeningCompensationStrength <
    ui_category = "Sharpening";
    ui_label = "Compensation Strength";
    ui_type = "slider";
    ui_min = 0f;
    ui_max = 2f;
    ui_step = .1;
> = 1.2;

uniform float _SharpeningCompensationCutoff <
    ui_category = "Sharpening";
    ui_label = "Compensation Cutoff";
    ui_type = "slider";
    ui_min = 0f;
    ui_max = 1f;
    ui_step = .01;
> = .15;

uniform float _SharpeningEdgeBias <
    ui_category = "Sharpening";
    ui_label = "Edge Bias";
    ui_type = "slider";
    ui_min = -4f;
    ui_max = 0f;
    ui_step = .1;
> = -1f;

uniform float _SharpeningSharpness <
    ui_category = "Sharpening";
    ui_label = "Sharpness";
    ui_type = "slider";
    ui_min = 0f;
    ui_max = 1f;
    ui_step = .01;
> = 0f;

uniform float _SharpeningBlendingStrength <
    ui_category = "Sharpening";
    ui_label = "Blending Strength";
    ui_type = "slider";
    ui_min = 0f;
    ui_max = 1f;
    ui_step = .01;
> = .5;

uniform bool _SharpeningDebug <
		ui_category = "Sharpening";
		ui_label = "_SharpeningDebug";
		ui_type = "radio";
> = false;

#ifndef SHOW_DEBUG
	#define SHOW_DEBUG 0
#endif
// preprocessor variable dedicated to debug library, turns it on or off
#define SHARED_DEBUG__ACTIVE_ SHOW_DEBUG

#if SHOW_DEBUG

uniform int _Debug <
		ui_category = "Debug";
ui_type = "combo";
ui_label = "Debug output";
ui_items = "None\0Max Local Luma\0Luma\0Filtered image only\0Deltas\0Edges\0";
> = 0;

#endif

// Libraries
#include ".\reshade-shared\functions.fxh"
#include ".\reshade-shared\color.fxh"
#include ".\reshade-shared\debug.fxh"

#ifndef PSMAA_USE_SIMPLIFIED_DELTA_CALCULATION
#define PSMAA_USE_SIMPLIFIED_DELTA_CALCULATION 0
#endif

#include "ReShade.fxh"

// PSMAA preprocessor variables
#define PSMAA_BUFFER_METRICS float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
#define PSMAA_THRESHOLD_FLOOR _ThreshFloor
#define PSMAA_PIXEL_SIZE BUFFER_PIXEL_SIZE
#define PSMAATexture2D(tex) sampler tex
#define PSMAASamplePoint(tex, coord) tex2D(tex, coord)
#define PSMAASampleLevelZero(tex, coord) tex2Dlod(tex, float4(coord, 0f, 0f))
#define PSMAASampleLevelZeroOffset(tex, coord, offset) tex2Dlodoffset(tex, float4(coord, coord), offset)
#define PSMAAGatherLeftEdges(tex, coord) tex2Dgather(tex, coord, 0);
#define PSMAAGatherTopEdges(tex, coord) tex2Dgather(tex, coord, 1);

#define PSMAA_PRE_PROCESSING_THRESHOLD_MULTIPLIER _PreProcessingThresholdMultiplier
#define PSMAA_PRE_PROCESSING_CMAA_LCA_FACTOR_MULTIPLIER _PreProcessingCmaaLCAMultiplier
#define PSMAA_PRE_PROCESSING_EXTRA_PIXEL_SOFTENING .15
#define PSMAA_PRE_PROCESSING_LUMA_PRESERVATION_BIAS _PreProcessingLumaPreservationBias
#define PSMAA_PRE_PROCESSING_LUMA_PRESERVATION_STRENGTH _PreProcessingLumaPreservationStrength
#define PSMAA_PRE_PROCESSING_STRENGTH _PreProcessingStrength
#define PSMAA_PRE_PROCESSING_MIN_STRENGTH .15
#define PSMAA_PRE_PROCESSING_STRENGTH_THRESH _PreProcessingStrengthThresh
#define PSMAA_PRE_PROCESSING_GREATEST_CORNER_CORRECTION_STRENGTH _PreProcessingGreatestCornerCorrectionStrength
#define PSMAA_EDGE_DETECTION_FACTORS_HIGH_LUMA float4(_EdgeDetectionThreshold.y, _CMAALCAFactor.y, _SMAALCAFactor.y, _CMAALCAforSMAALCAFactor.y)
#define PSMAA_EDGE_DETECTION_FACTORS_LOW_LUMA float4(_EdgeDetectionThreshold.x, _CMAALCAFactor.x, _SMAALCAFactor.x, _CMAALCAforSMAALCAFactor.x)
#define PSMAA_SHARPENING_COMPENSATION_STRENGTH _SharpeningCompensationStrength
#define PSMAA_SHARPENING_COMPENSATION_CUTOFF _SharpeningCompensationCutoff
#define PSMAA_SHARPENING_EDGE_BIAS _SharpeningEdgeBias
#define PSMAA_SHARPENING_SHARPNESS _SharpeningSharpness
#define PSMAA_SHARPENING_BLENDING_STRENGTH _SharpeningBlendingStrength
#define PSMAA_SHARPENING_DEBUG _SharpeningDebug

#include ".\PSMAA.fxh"
#include ".\PSMAA.old.fxh"

#ifdef SMAA_PRESET_CUSTOM
#define SMAA_MAX_SEARCH_STEPS _MaxSearchSteps
#define SMAA_MAX_SEARCH_STEPS_DIAG _MaxSearchStepsDiag
#define SMAA_CORNER_ROUNDING _CornerRounding
#endif

#define SMAA_RT_METRICS PSMAA_BUFFER_METRICS

#define SMAATexture2D(tex) PSMAATexture2D(tex)
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) PSMAASampleLevelZero(tex, coord)
#define SMAASampleLevelZeroPoint(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
#define SMAASampleLevelZeroOffset(tex, coord, offset) PSMAASampleLevelZeroOffset(tex, coord, offset)
#define SMAASample(tex, coord) tex2D(tex, coord)
#define SMAASamplePoint(tex, coord) PSMAASamplePoint(tex, coord)
#define SMAASampleOffset(tex, coord, offset) tex2D(tex, coord + offset * SMAA_RT_METRICS.xy)
#define SMAA_FLATTEN [flatten]
#define SMAA_BRANCH [branch]

#include ".\SMAA.fxh"

#define SMOOTHING_STRENGTH_MOD 1f
#define EDGE_THRESHOLD_MOD 0.35
#define SMOOTHING_THRESHOLD 0.05
#define SMOOTHING_SATURATION_DIVISOR_FLOOR 0.01
#define SMOOTHING_MIN_ITERATIONS 5f
#define SMOOTHING_MAX_ITERATIONS 20f
#define SMOOTHING_LUMA_WEIGHTS float3(0.2126, 0.7152, 0.0722)
#define SMOOTHING_BUFFER_RCP_HEIGHT BUFFER_RCP_HEIGHT
#define SMOOTHING_BUFFER_RCP_WIDTH BUFFER_RCP_WIDTH
#define SMOOTHING_DEBUG false
#define SMOOTHING_DELTA_WEIGHT_DEBUG _SmoothingDeltaWeightDebug
#define SMOOTHING_USE_CORNER_WEIGHT _SmoothingCornerWeightMix
#define SMOOTHING_DELTA_WEIGHT_FLOOR .06
#define SMOOTHING_MIN_DELTA_WEIGHT _SmoothingMinDeltaWeight
#define SMOOTHING_MAX_DELTA_WEIGHT _SmoothingMaxDeltaWeight
#define SMOOTHING_DELTA_WEIGHT_PREDICATION_FACTOR _SmoothingDeltaWeightDynamicThreshold
#define SMOOTHING_ENABLED true
#define SmoothingTexture2D(tex) PSMAATexture2D(tex)
#define SmoothingSamplePoint(tex, coord) PSMAASamplePoint(tex, coord)
#define SmoothingSampleLevelZero(tex, coord) PSMAASampleLevelZero(tex, coord)
#define SmoothingGatherLeftDeltas(tex, coord) PSMAAGatherLeftEdges(tex, texcoord);
#define SmoothingGatherTopDeltas(tex, coord) PSMAAGatherTopEdges(tex, texcoord);

#include ".\BeanSmoothing.fxh"

texture colorInputTex : COLOR;
sampler colorGammaSampler
{
	Texture = colorInputTex;
	MipFilter = POINT;
};
sampler colorLinearSampler
{
	Texture = colorInputTex;
	MipFilter = Point;
	SRGBTexture = true;
};

texture maxLocalLumaTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = R8;
};
sampler maxLocalLumaSampler
{
	Texture = maxLocalLumaTex;
};

texture originalLumaTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = R8;
};
sampler originalLumaSampler
{
	Texture = originalLumaTex;
};

texture filterStrengthTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG8;
};
sampler filterStrengthSampler
{
	Texture = filterStrengthTex;
};

texture deltaTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG8;
};
sampler deltaSampler
{
	Texture = deltaTex;
};

texture edgesTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG8;
};
sampler edgesSampler
{
	Texture = edgesTex;
};

texture weightTex
{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA8;
};
sampler weightSampler
{
	Texture = weightTex;
};

texture areaTex < source = "AreaTex.png";
>
{
	Width = 160;
	Height = 560;
	Format = RG8;
};
sampler areaSampler
{
	Texture = areaTex;
};

texture searchTex < source = "SearchTex.png";
>
{
	Width = 64;
	Height = 16;
	Format = R8;
};
sampler searchSampler
{
	Texture = searchTex;
	MipFilter = Point;
	MinFilter = Point;
	MagFilter = Point;
};


void PSMAAPreProcessingPSWrapper(
	float4 position : SV_POSITION,
	float2 texcoord : TEXCOORD0,
	out float maxLocalLuma : SV_TARGET0,
	out float originalLuma : SV_TARGET1,
	out float2 filteringStrength : SV_TARGET2
)
{
	PSMAA::Pass::PreProcessingPS(texcoord, colorGammaSampler, maxLocalLuma, originalLuma, filteringStrength);
}

void PSMAAFilteringPSWrapper(
		float4 position : SV_Position,
		float2 texcoord : TEXCOORD0,
		out float4 color : SV_Target)
{
	PSMAA::Pass::FilteringPS(texcoord, colorLinearSampler, filterStrengthSampler, color);
}

// TODO: consider trying to calculate this in the PS instead.
void PSMAADeltaCalulationVSWrapper(
		in uint id : SV_VertexID,
		out float4 position : SV_Position,
		out float2 texcoord : TEXCOORD0,
		out float4 offset[1] : TEXCOORD1)
{
	PostProcessVS(id, position, texcoord);
	PSMAA::Pass::DeltaCalculationVS(texcoord, offset);
}

void PSMAADeltaCalulationPSWrapper(
		float4 position : SV_Position,
		float2 texcoord : TEXCOORD0,
		float4 offset[1] : TEXCOORD1,
		out float2 deltas : SV_Target0)
{
	PSMAA::Pass::DeltaCalculationPS(texcoord, offset, colorGammaSampler, deltas);
}

void PSMAAEdgeDetectionVSWrapper(
		in uint id : SV_VertexID,
		out float4 position : SV_Position,
		out float2 texcoord : TEXCOORD0,
		out float4 offset[2] : TEXCOORD1)
{
	PostProcessVS(id, position, texcoord);
	PSMAA::Pass::EdgeDetectionVS(texcoord, offset);
}

void PSMAAEdgeDetectionPSWrapper(
		float4 position : SV_Position,
		float2 texcoord : TEXCOORD0,
		float4 offset[2] : TEXCOORD1,
		out float2 edges : SV_Target)
{
	PSMAA::Pass::EdgeDetectionPS(texcoord, offset, deltaSampler, maxLocalLumaSampler, edges);
	// PSMAA::Pass::HybridDetection(texcoord, offset, colorGammaSampler, _EdgeDetectionThreshold, _SMAALCAFactor, edges);
}

void SMAABlendingWeightCalculationVSWrapper(
		in uint id : SV_VertexID,
		out float4 position : SV_Position,
		out float2 texcoord : TEXCOORD0,
		out float2 pixcoord : TEXCOORD1,
		out float4 offset[3] : TEXCOORD2)
{
	PostProcessVS(id, position, texcoord);
	SMAABlendingWeightCalculationVS(texcoord, pixcoord, offset);
}

float4 SMAABlendingWeightCalculationPSWrapper(
		float4 position : SV_Position,
		float2 texcoord : TEXCOORD0,
		float2 pixcoord : TEXCOORD1,
		float4 offset[3] : TEXCOORD2) : SV_Target
{
	return SMAABlendingWeightCalculationPS(texcoord, pixcoord, offset, edgesSampler, areaSampler, searchSampler, 0.0);
}

void SMAANeighborhoodBlendingVSWrapper(
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
		out float4 color : SV_Target)
{

#if SHOW_DEBUG

	if (_Debug == 0)
	{
		color = SMAANeighborhoodBlendingPS(texcoord, offset, colorLinearSampler, weightSampler).rgba;
	}
	else if (_Debug == 1)
	{
		color = tex2D(maxLocalLumaSampler, texcoord).rrrr;
	}
	else if (_Debug == 2)
	{
		color = tex2D(originalLumaSampler, texcoord).rrrr;
	}
	else if (_Debug == 3)
	{
		color = tex2D(colorLinearSampler, texcoord);
	}
	else if (_Debug == 4)
	{
		color = tex2D(deltaSampler, texcoord).rgba;
	}
	else
	{
		color = tex2D(edgesSampler, texcoord).rgba;
	}

	color = Debug::applyDebugOptions(color);

#else

	color = SMAANeighborhoodBlendingPS(texcoord, offset, colorLinearSampler, weightSampler).rgba;

#endif
}

void SmoothingPSWrapper(
		float4 position : SV_Position,
		float2 texcoord : TEXCOORD0,
		float4 offset : TEXCOORD1,
		out float3 color : SV_Target)
{
	if (!_SmoothingEnabled)
		discard;
	// if (_OldSmoothingEnabled){
	// 	BeanSmoothingOld::SmoothingPS(texcoord, offset, deltaSampler, weightSampler, colorGammaSampler, color);
	// 	return;
	// }
	BeanSmoothing::SmoothingPS(texcoord, offset, deltaSampler, weightSampler, colorGammaSampler, maxLocalLumaSampler, color);
}

void CASPSWrapper(
		float4 position : SV_Position,
		float2 texcoord : TEXCOORD0,
		out float3 color : SV_Target)
{
	if (!_SharpeningEnabled)
		discard;
	// if (_UseOldCas)
	// {
	// 	CASOld::CASPS(texcoord, colorLinearSampler, color);
	// 	return;
	// }
	// CAS::CASPS(texcoord, colorLinearSampler, color);

	PSMAA::Pass::SharpeningPS(texcoord, originalLumaSampler, colorGammaSampler, deltaSampler, colorLinearSampler, color);
}

technique PSMAA
{
	pass PreProcessing
	{
		VertexShader = PostProcessVS;
		PixelShader = PSMAAPreProcessingPSWrapper;
		RenderTarget0 = maxLocalLumaTex;
		RenderTarget1 = originalLumaTex;
		RenderTarget2 = filterStrengthTex;
		// ClearRenderTargets = true;
	}
	pass Filtering
	{
		VertexShader = PostProcessVS;
		PixelShader = PSMAAFilteringPSWrapper;
		SRGBWriteEnable = true;
	}
	pass DeltaCalculation
	{
		VertexShader = PSMAADeltaCalulationVSWrapper;
		PixelShader = PSMAADeltaCalulationPSWrapper;
		RenderTarget = deltaTex;
		// TODO: test if these are necessary!
		// Especially the stencil stuff
		// https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md#techniques
		ClearRenderTargets = true;
		// StencilEnable = true;
		// StencilPass = REPLACE;
		// StencilRef = 1;
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
	pass BlendWeightCalculationPass
	{
		VertexShader = SMAABlendingWeightCalculationVSWrapper;
		PixelShader = SMAABlendingWeightCalculationPSWrapper;
		RenderTarget = weightTex;
		ClearRenderTargets = true;
		StencilEnable = true;
		StencilPass = KEEP;
		StencilFunc = EQUAL;
		StencilRef = 1;
	}
	pass Blending
	{
		// TODO: consider renaming this VSWrapper to something more generic
		// alternatively, Consider giving this pass it's own VS
		VertexShader = SMAANeighborhoodBlendingVSWrapper;
		PixelShader = PSMAABlendingPSWrapper;
		SRGBWriteEnable = true;
	}
	pass Smoothing
	{
		VertexShader = SMAANeighborhoodBlendingVSWrapper;
		PixelShader = SmoothingPSWrapper;
	}
	pass Sharpening
	{
		VertexShader = PostProcessVS;
		PixelShader = CASPSWrapper;
		SRGBWriteEnable = true;
	}
}