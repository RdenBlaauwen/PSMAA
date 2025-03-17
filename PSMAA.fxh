
// TODO: replace this with language-specific values in te future
// reshade-specific definition should eventually go into the main file, not here
#define PSMAA_BUFFER_METRICS float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
#define PSMAATexture2D(tex) sampler tex 
#define PSMAASamplePoint(tex, coord) tex2D(tex, coord)

namespace PSMAA {
  /**
  * Get the luma weighted delta between two vectors
  */
  float GetDelta(float3 cA, float3 cB, float rangeA, float rangeB) {
    float colorfulness = max(rangeA, rangeB)
    float3 cDelta = abs(cA - cB);

    float colorDelta = colorfulness * Functions::max(cDelta);
    float euclidianDelta = (1f - colorfulness) * Color::luma(colorDelta)
    return colorDelta + euclidianDelta;
  }

  /**
  * Get the deltas for the current pixel. Combines euclidian luma detection with color detection dynamically based on the colorfulness of the pixels.
  */
  float2 GetDeltas(float3 cLeft, float3 cTop, float3 cCurrent, float rangeLeft, float rangeTop, float rangeCurrent) {
    float2 deltas;
    deltas.x = GetDelta(cLeft, cCurrent, rangeLeft, rangeCurrent);
    deltas.y = GetDelta(cTop, cCurrent, rangeTop, rangeCurrent);

    return deltas;
  }

  namespace Pass {

    /**
    * Decided to leave the offset as an array, because I'll likely need more values in the future.
    */
    void DeltaCalculationVS(float2 texcoord, out float4 offset[1]) {
        offset[0] = mad(PSMAA_BUFFER_METRICS.xyxy, float4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy);
    }

    // Perhaps `out float2 deltas` should be `inout float2 deltas` instead?
    void DeltaCalculationPS(float2 texcoord, float4 offset[1], PSMAATexture2D(colorGammaTex), out float2 deltas) {
      float3 current = PSMAASamplePoint(colorGammaTex, texcoord).rgb;
      float3 left = PSMAASamplePoint(colorGammaTex, offset[0].xy).rgb;
      float3 top = PSMAASamplePoint(colorGammaTex, offset[0].zw).rgb;

      float rangeCurrent = Functions::max(current) - Functions::min(current);
      float rangeLeft = Functions::max(left) - Functions::min(left);
      float rangeTop = Functions::max(top) - Functions::min(top);

      deltas = GetDeltas(left, top, current, rangeLeft, rangeTop, rangeCurrent);
    }

    void EdgeDetectionPS(
      float2 texcoord,
      float4 offset[3],
      PSMAATexture2D(deltaTex),
      float2 baseThreshold,
      float localContrastAdaptationFactor,
      inout float2 edgesOutput
    ) {
        // Calculate color deltas:
        float4 delta;
        float4 colorRange;

        float2 C = PSMAASamplePoint(deltaTex, texcoord).rg;

        delta.x = C.r;
        delta.y = C.g;

        // We do the usual threshold:
        float2 edges = step(threshold, delta.xy);

        // Early return if there is no edge:
        if (!Lib::any(edges))
            discard;

        // Calculate right and bottom deltas:
        float Cright = PSMAASamplePoint(deltaTex, offset[1].xy).r;
        delta.z = Cright;

        float Cbottom  = PSMAASamplePoint(deltaTex, offset[1].zw).g;
        delta.w = Cbottom;

        // Calculate the maximum delta in the direct neighborhood:
        float2 maxDelta = max(delta.xy, delta.zw);

        // Calculate left-left and top-top deltas:
        float Cleftleft  = PSMAASamplePoint(deltaTex, offset[0].xy).r;
        delta.z = Cleftleft;

        float Ctoptop = PSMAASamplePoint(deltaTex, offset[0].zw).g;
        delta.w = Ctoptop;

        // Calculate the final maximum delta:
        maxDelta = max(maxDelta.xy, delta.zw);
        float finalDelta = max(maxDelta.x, maxDelta.y);

        // Local contrast adaptation:
        edges.xy *= step(finalDelta, localContrastAdaptationFactor * delta.xy);

        edgesOutput = edges;
    }
  }
}