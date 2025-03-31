
// IMPLEMENTATION
// The following preprocessor variables should be defined in the main file:
// #define PSMAA_USE_SIMPLIFIED_DELTA_CALCULATION
// #define PSMAA_BUFFER_METRICS
// #define PSMAA_PIXEL_SIZE
// #define PSMAA_THRESHOLD_FLOOR
// #define PSMAA_SMAA_LCA_FACTOR_FLOOR
// #define PSMAATexture2D(tex)
// #define PSMAASamplePoint(tex, coord)
// #define PSMAAGatherLeftEdges(tex, coord)
// #define PSMAAGatherTopEdges(tex, coord)
//
// Reshade example:
// #define PSMAA_USE_SIMPLIFIED_DELTA_CALCULATION 0 
// #define PSMAA_BUFFER_METRICS float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
// #define PSMAA_PIXEL_SIZE BUFFER_PIXEL_SIZE
// #define PSMAA_THRESHOLD_FLOOR 0.018
// #define PSMAA_SMAA_LCA_FACTOR_FLOOR 1.5
// #define PSMAATexture2D(tex) sampler tex 
// #define PSMAASamplePoint(tex, coord) tex2D(tex, coord)
// #define PSMAAGatherLeftEdges(tex, coord) tex2Dgather(tex, texcoord, 0);
// #define PSMAAGatherTopEdges(tex, coord) tex2Dgather(tex, texcoord, 1);

namespace PSMAA {
  /**
  * Get the luma weighted delta between two vectors
  */
  float GetDelta(float3 cA, float3 cB, float rangeA, float rangeB) {
    float3 cDelta = abs(cA - cB);
    float deltaLuma = Color::luma(cDelta);

    #if PSMAA_USE_SIMPLIFIED_DELTA_CALCULATION == 1

    return deltaLuma;

    #else

    float colorDelta = Functions::max(cDelta);
    float colorfulness = max(rangeA, rangeB);
    return lerp(deltaLuma, colorDelta, colorfulness);

    #endif
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

  float calcAdaptationFactor(float luminosityAdaptationFactor, float localLuma) {
    return mad(-luminosityAdaptationFactor, 1f - localLuma, 1f);
  }

  float adjustThreshold(float threshold, float adaptationFactor) {
    threshold *= adaptationFactor;
    return max(threshold, PSMAA_THRESHOLD_FLOOR); // floor
  }

  float adjustSMAALCAFactor(float SMAALCAFactor, float adaptationFactor) {
    // calc portion of SMAA's LCA factor that can be adapted
    float SMAALCAFactorAdaptableRange = saturate(SMAALCAFactor - PSMAA_SMAA_LCA_FACTOR_FLOOR);
    // adapt LCA factor and add back to the floor
    return mad(SMAALCAFactorAdaptableRange, adaptationFactor, PSMAA_SMAA_LCA_FACTOR_FLOOR);
  }

  float2 GetEdges(
    float4 verticalDeltas,
    float4 horizontalDeltas,
    float threshold,
    float CMAALCAFactor
  )
  {
    // v = Vertical deltas
    // h = Horizontal deltas
    // [  ]  [vx]   [vy]
    // [hx] [vz hy] [vw]
    // [hz]  [hw]   [  ]
    float2 cmaaLocalContrast;
    cmaaLocalContrast.r = Functions::max(verticalDeltas.x,verticalDeltas.y,verticalDeltas.z,horizontalDeltas.w);
    cmaaLocalContrast.g = Functions::max(horizontalDeltas.x,horizontalDeltas.y,horizontalDeltas.z,verticalDeltas.w);

    cmaaLocalContrast *= CMAALCAFactor;

    float2 currDeltas = float2(verticalDeltas.z, horizontalDeltas.y) - cmaaLocalContrast;

    // threshold *= mad(-contrastAdaptationFactors.y, 1f - localLuma, 1f);
    // threshold = max(threshold, PSMAA_THRESHOLD_FLOOR);

    return step(threshold, currDeltas);
  }

  float2 ApplySMAALCA(
    float2 edges,
    // x = bottom, y = top, z = toptop
    float3 horizontalDeltas,
    // x = right, y = left, z = leftleft
    float3 verticalDeltas,
    float SMAALCAFactor
  )
  {
    float2 maxDeltas = float2(Functions::max(verticalDeltas), Functions::max(horizontalDeltas));
    float finalDelta = max(maxDeltas.r, maxDeltas.g);

    float2 currDeltas = float2(verticalDeltas.y, horizontalDeltas.y);

    edges.rg *= step(finalDelta, SMAALCAFactor * currDeltas.rg); //TODO: try removing the .rg's

    return edges;
  }

  namespace Pass {

    /**
    * Calculates the offsets for the current pixel.
    * Decided to leave the offset as an array, because I'll likely need more values in the future.
    */
    void DeltaCalculationVS(float2 texcoord, out float4 offset[1]) {
        offset[0] = mad(PSMAA_BUFFER_METRICS.xyxy, float4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy);
    }

    /**
    * Calculate the top and left deltas for the current pixel.
    */
    void DeltaCalculationPS(float2 texcoord, float4 offset[1], PSMAATexture2D(colorGammaTex), out float2 deltas) {
      float3 current = PSMAASamplePoint(colorGammaTex, texcoord).rgb;
      float3 left = PSMAASamplePoint(colorGammaTex, offset[0].xy).rgb;
      float3 top = PSMAASamplePoint(colorGammaTex, offset[0].zw).rgb;

      float rangeCurrent = Functions::max(current) - Functions::min(current);
      float rangeLeft = Functions::max(left) - Functions::min(left);
      float rangeTop = Functions::max(top) - Functions::min(top);

      deltas = GetDeltas(left, top, current, rangeLeft, rangeTop, rangeCurrent);
    }


    void EdgeDetectionVS(float2 texcoord, out float4 offset[2]) {
      offset[0] = mad(PSMAA_PIXEL_SIZE.xyxy, float4(-.5, 0.0, 0.0, -.5), texcoord.xyxy);
      offset[1] = mad(PSMAA_BUFFER_METRICS.xyxy, float4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy);
    }
    /**
    * Calculate the edges for the current pixel. 
    * Temporary implementation for testing purposes. Should not be used in production for now.
    */
    void EdgeDetectionPS(
      float2 texcoord,
      float4 offset[2],
      PSMAATexture2D(deltaTex),
      float threshold,
      // x: CMAA's local contrast adaptation factor
      // y: local luminosity adaptation factor
      // z: SMAA's local contrast adaptation factor
      float3 contrastAdaptationFactors,
      out float2 edgesOutput
    ) 
    {
      // gather from left
      // [  ]  [  ]   [  ]
      // [hx]  [hy]   [  ]
      // [hz]  [hw]   [  ]
      float4 horzDeltas = PSMAAGatherTopEdges(deltaTex, offset[0].xy);
      horzDeltas = horzDeltas.wzxy;
      // gather from top
      // [  ]  [vx]   [vy]
      // [  ]  [vz]   [vw]
      // [  ]  [  ]   [  ]
      float4 vertDeltas = PSMAAGatherLeftEdges(deltaTex, offset[0].zw); 
      vertDeltas = vertDeltas.wzxy;

      float localLuma = 1f; // temp value for testing purposes. TODO: implement luma caching and use it here
      
      //calculate factor which lowers threshold and SMAA's LCA factor according to local luminosity
      float adjustmentFactor = calcAdaptationFactor(contrastAdaptationFactors.y, localLuma);

      threshold = adjustThreshold(threshold, adjustmentFactor);

      float2 edges = GetEdges(vertDeltas, horzDeltas, threshold, contrastAdaptationFactors.x);

      // Early return if there is no edge:
      if (edges.x == -edges.y) discard;

      // get leftmost and topmost extremes for SMAA LCA
      float leftLeftDelta = PSMAASamplePoint(deltaTex, offset[1].xy).r;
      float topTopDelta = PSMAASamplePoint(deltaTex, offset[1].zw).g;

      // [  ]  [ttd]  [  ]
      // [  ]  [hy]   [  ]
      // [  ]  [hw]   [  ]
      float3 horzDeltas2 = float3(horzDeltas.w, horzDeltas.y, topTopDelta);
      // [  ]  [  ]   [  ]
      // [lld] [vz]   [vw]
      // [  ]  [  ]   [  ]
      float3 vertDeltas2 = float3(vertDeltas.w, vertDeltas.z, leftLeftDelta);

      // adapt SMAA's LCA factor
      contrastAdaptationFactors.z = adjustSMAALCAFactor(contrastAdaptationFactors.z, adjustmentFactor);

      edgesOutput = ApplySMAALCA(edges, horzDeltas2, vertDeltas2, contrastAdaptationFactors.z);
    }

    /**
    * Conventional Edge detection algorithm which does not use a delta texture and does not rely
    * on a separate delta pass. For testing purposes only, to compare the performance to that of
    * the PSMAA edge detection method (which *does* separate the delta calculation from the edge detection).
    */
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
        if (edges.x == -edges.y) discard;

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