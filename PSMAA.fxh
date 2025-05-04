
// IMPLEMENTATION
// The following preprocessor variables should be defined in the main file:
// #define PSMAA_USE_SIMPLIFIED_DELTA_CALCULATION
// #define PSMAA_BUFFER_METRICS
// #define PSMAA_PIXEL_SIZE
// #define PSMAATexture2D(tex)
// #define PSMAASamplePoint(tex, coord)
// #define PSMAAGatherLeftEdges(tex, coord)
// #define PSMAAGatherTopEdges(tex, coord)
// #define PSMAA_THRESHOLD_FLOOR
// #define PSMAA_EDGE_DETECTION_FACTORS_HIGH_LUMA
// #define PSMAA_EDGE_DETECTION_FACTORS_LOW_LUM
// These are float4's with the following values:
// x: threshold
// y: CMAA LCA factor
// z: SMAA LCA factor
// w: SMAA LCA adjustment bias by CMAA local contrast
//
// Reshade example:
// #define PSMAA_USE_SIMPLIFIED_DELTA_CALCULATION 0 
// #define PSMAA_BUFFER_METRICS float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
// #define PSMAA_PIXEL_SIZE BUFFER_PIXEL_SIZE
// #define PSMAATexture2D(tex) sampler tex 
// #define PSMAASamplePoint(tex, coord) tex2D(tex, coord)
// #define PSMAAGatherLeftEdges(tex, coord) tex2Dgather(tex, texcoord, 0);
// #define PSMAAGatherTopEdges(tex, coord) tex2Dgather(tex, texcoord, 1);
// #define PSMAA_THRESHOLD_FLOOR 0.018
// #define PSMAA_EDGE_DETECTION_FACTORS_HIGH_LUMA float4(threshold, CMAALCAFactor, SMAALCAFactor, SMAALCAAdjustmentBiasByCMAALocalContrast)
// #define PSMAA_EDGE_DETECTION_FACTORS_LOW_LUMA float4(threshold, CMAALCAFactor, SMAALCAFactor, SMAALCAAdjustmentBiasByCMAALocalContrast)

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

  void GatherNeighborDeltas(
      PSMAATexture2D(deltaTex), 
      float4 gatherOffset,
      out float4 horzDeltas,
      out float4 vertDeltas
  ) {
      horzDeltas = PSMAAGatherTopEdges(deltaTex, gatherOffset.xy);
      horzDeltas = horzDeltas.wzxy;
      // gathered from left
      // [  ]  [  ]   [  ]
      // [hx]  [hy]   [  ]
      // [hz]  [hw]   [  ]
      vertDeltas = PSMAAGatherLeftEdges(deltaTex, gatherOffset.zw);
      vertDeltas = vertDeltas.wzxy;
      // gathered from top
      // [  ]  [vx]   [vy]
      // [  ]  [vz]   [vw]
      // [  ]  [  ]   [  ]
  }

  float2 CalculateCMAALocalContrast(float4 vertDeltas, float4 horzDeltas, float cmaaLCAFactor) {
      float2 cmaaLCA;
      cmaaLCA.r = Functions::max(vertDeltas.x, vertDeltas.y, vertDeltas.z, horzDeltas.w);
      cmaaLCA.g = Functions::max(horzDeltas.x, horzDeltas.y, horzDeltas.z, vertDeltas.w);
      return cmaaLCA * cmaaLCAFactor;
  }

  float2 DetectEdges(float2 deltas, float threshold, float2 cmaaLCA) {
      float2 currDeltas = deltas - cmaaLCA.rg;
      return step(threshold, currDeltas);
  }

  float2 GetSMAAExtremesDeltas(PSMAATexture2D(deltaTex), float4 offset) {
      return float2(
          PSMAASamplePoint(deltaTex, offset.xy).r,  // leftLeftDelta
          PSMAASamplePoint(deltaTex, offset.zw).g   // topTopDelta
      );
  }

  float2 ApplySMAALCA(
    float2 edges,
    // x = bottom, y = top, z = toptop
    float3 horizontalDeltas,
    // x = right, y = left, z = leftleft
    float3 verticalDeltas,
    // x: SMAA's local contrast adaptation factor
    // y: SMAA LCA adjustment bias by CMAA local contrast
    float2 LCAFactors,
    float2 cmaaLocalContrast
  )
  {
    float2 maxDeltas = float2(Functions::max(verticalDeltas), Functions::max(horizontalDeltas));
    float finalDelta = max(maxDeltas.r, maxDeltas.g);

    float2 currDeltas = mad(cmaaLocalContrast, LCAFactors.y, float2(verticalDeltas.y, horizontalDeltas.y));
    edges.rg *= step(finalDelta, LCAFactors.x * currDeltas.rg); //TODO: try removing the .rg's

    return edges;
  }

  namespace Pass {
    void PreProcessingPS(
      float3 NW,
      float3 W,
      float3 SW,
      float3 N,
      float3 C,
      float3 S,
      float3 NE,
      float3 E,
      float3 SE,
      out float3 filteredCopy,  // output current color (C)
      out float luma            // output maximum luma from all nine samples
    )
    { 
      float lNW = Color::luma(NW);
      float lW  = Color::luma(W);
      float lSW = Color::luma(SW);
      float lN  = Color::luma(N);
      float lC  = Color::luma(C);
      float lS  = Color::luma(S);
      float lNE = Color::luma(NE);
      float lE  = Color::luma(E);
      float lSE = Color::luma(SE);

      // Calculate the maximum luma among all samples
      luma = Functions::max(lNW, lW, lSW, lN, lC, lS, lNE, lE, lSE);
      // Set the filtered copy as the current texel color: C.
      filteredCopy = C;
    }

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
      PSMAATexture2D(lumaTex),
      out float2 edgesOutput
  ) 
  {
      float4 horzDeltas, vertDeltas;
      GatherNeighborDeltas(deltaTex, offset[0], horzDeltas, vertDeltas);

      float localLuma = PSMAASamplePoint(lumaTex, texcoord).r;
      // Adjust threshold and LCA factors according to the max local luma
      float4 detectionFactors = lerp(PSMAA_EDGE_DETECTION_FACTORS_LOW_LUMA, PSMAA_EDGE_DETECTION_FACTORS_HIGH_LUMA, localLuma);
      detectionFactors.x = max(detectionFactors.x, PSMAA_THRESHOLD_FLOOR);

      float2 cmaaLCA = CalculateCMAALocalContrast(vertDeltas, horzDeltas, detectionFactors.y);
      float2 edges = DetectEdges(float2(vertDeltas.z, horzDeltas.y), detectionFactors.x, cmaaLCA);
      
      // discard if there is no edge
      if (dot(edges,float2(1.0, 1.0)) == 0f) discard;

      // Get extremes for SMAA LCA
      float2 extremesDeltas = GetSMAAExtremesDeltas(deltaTex, offset[1]);

      // [  ]  [  ]   [  ]
      // [e.y] [vz]   [vw]
      // [  ]  [  ]   [  ]
      float3 vertDeltas2 = float3(vertDeltas.w, vertDeltas.z, extremesDeltas.x);
      // [  ]  [e.y]  [  ]
      // [  ]  [hy]   [  ]
      // [  ]  [hw]   [  ]
      float3 horzDeltas2 = float3(horzDeltas.w, horzDeltas.y, extremesDeltas.y);

      edgesOutput = ApplySMAALCA(edges, horzDeltas2, vertDeltas2, detectionFactors.zw, cmaaLCA);
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