
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
    float colorfulness = max(rangeA, rangeB);
    float3 cDelta = abs(cA - cB);

    float colorDelta = colorfulness * Functions::max(cDelta);
    float euclidianDelta = (1f - colorfulness) * Color::luma(cDelta);
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
      float2 threshold,
      float localContrastAdaptationFactor,
      out float2 edgesOutput
    ) {
        // return texcoord;
        // Calculate color deltas:
        float4 delta;
        float4 colorRange;

        float2 C = PSMAASamplePoint(deltaTex, texcoord).rg;

        delta.x = C.r;
        delta.y = C.g;

        // We do the usual threshold:
        float2 edges = step(threshold, delta.xy);

        // Early return if there is no edge:
        if (!Functions::any(edges))
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

    void HybridDetection(
      float2 texcoord,
      float4 offset[3],
      PSMAATexture2D(colorTex),
      float2 threshold,
      float localContrastAdaptationFactor,
      out float2 edgesOutput
    ) {
        // Calculate color deltas:
        float4 delta;
        float4 colorRange;

        float3 C = PSMAASamplePoint(colorTex, texcoord).rgb;
        float midRange = Functions::max(C) - Functions::min(C);

        float3 Cleft = PSMAASamplePoint(colorTex, offset[0].xy).rgb;
        float rangeLeft = Functions::max(Cleft) - Functions::min(Cleft);
        float colorfulness = max(midRange, rangeLeft);
        float3 t = abs(C - Cleft);
        delta.x = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t)); // TODO: refactor to use luma function instead

        float3 Ctop  = PSMAASamplePoint(colorTex, offset[0].zw).rgb;
        float rangeTop = Functions::max(Ctop) - Functions::min(Ctop);
        colorfulness = max(midRange, rangeTop);
        t = abs(C - Ctop);
        delta.y = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t));

        // We do the usual threshold:
        float2 edges = step(threshold, delta.xy);

        // Early return if there is no edge:
        if (!Functions::any(edges))
            discard;

        // Calculate right and bottom deltas:
        float3 Cright = PSMAASamplePoint(colorTex, offset[1].xy).rgb;
        t = abs(C - Cright);
        float rangeRight = Functions::max(Cright) - Functions::min(Cright);
        colorfulness = max(midRange, rangeRight);
        delta.z = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t));

        float3 Cbottom  = PSMAASamplePoint(colorTex, offset[1].zw).rgb;
        t = abs(C - Cbottom);
        float rangeBottom = Functions::max(Cright) - Functions::min(Cright);
        colorfulness = max(midRange, rangeBottom);
        delta.w = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t));

        // Calculate the maximum delta in the direct neighborhood:
        float2 maxDelta = max(delta.xy, delta.zw);

        // Calculate left-left and top-top deltas:
        float3 Cleftleft  = PSMAASamplePoint(colorTex, offset[2].xy).rgb;
        t = abs(Cleft - Cleftleft);
        float rangeLeftLeft = Functions::max(Cright) - Functions::min(Cright);
        colorfulness = max(rangeLeft, rangeLeftLeft);
        delta.z = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t));

        float3 Ctoptop = PSMAASamplePoint(colorTex, offset[2].zw).rgb;
        t = abs(Ctop - Ctoptop);
        float rangeTopTop = Functions::max(Cright) - Functions::min(Cright);
        colorfulness = max(rangeTop, rangeTopTop);
        delta.w = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t));

        // Calculate the final maximum delta:
        maxDelta = max(maxDelta.xy, delta.zw);
        float finalDelta = max(maxDelta.x, maxDelta.y);

        // Local contrast adaptation:
        edges.xy *= step(finalDelta, localContrastAdaptationFactor * delta.xy);

        edgesOutput = edges;
    }
  }
}