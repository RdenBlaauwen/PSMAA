// IMPLEMENTATION
// The following preprocessor variables should be defined in the main file:
// #define PSMAA_USE_SIMPLIFIED_DELTA_CALCULATION
// #define PSMAA_BUFFER_METRICS
// #define PSMAA_PIXEL_SIZE
// #define PSMAATexture2D(tex)
// #define PSMAASamplePoint(tex, coord)
// #define PSMAASampleLevelZero(tex, coord)
// #define PSMAASampleLevelZeroOffset(tex, coord, offset)
// #define PSMAAGatherLeftEdges(tex, coord)
// #define PSMAAGatherTopEdges(tex, coord)
// #define PSMAA_PRE_PROCESSING_THRESHOLD_MULTIPLIER
// #define PSMAA_PRE_PROCESSING_CMAA_LCA_FACTOR_MULTIPLIER
// #define PSMAA_PRE_PROCESSING_EXTRA_PIXEL_SOFTENING
// #define PSMAA_PRE_PROCESSING_LUMA_PRESERVATION_BIAS
// #define PSMAA_PRE_PROCESSING_LUMA_PRESERVATION_STRENGTH
// #define PSMAA_PRE_PROCESSING_STRENGTH
// #define PSMAA_PRE_PROCESSING_MIN_STRENGTH
// #define PSMAA_ALPHA_PASSTHROUGH
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
// #define PSMAASampleLevelZero(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
// #define PSMAASampleLevelZeroOffset(tex, coord, offset) tex2Dlodoffset(tex, float4(coord, coord), offset)
// #define PSMAAGatherLeftEdges(tex, coord) tex2Dgather(tex, texcoord, 0);
// #define PSMAAGatherTopEdges(tex, coord) tex2Dgather(tex, texcoord, 1);
// #define PSMAA_PRE_PROCESSING_THRESHOLD_MULTIPLIER 1f
// #define PSMAA_PRE_PROCESSING_CMAA_LCA_FACTOR_MULTIPLIER 1f
// #define PSMAA_PRE_PROCESSING_EXTRA_PIXEL_SOFTENING .15
// #define PSMAA_PRE_PROCESSING_LUMA_PRESERVATION_BIAS .5
// #define PSMAA_PRE_PROCESSING_LUMA_PRESERVATION_STRENGTH 1f
// #define PSMAA_PRE_PROCESSING_STRENGTH 1f
// #define PSMAA_PRE_PROCESSING_MIN_STRENGTH .15
// #define PSMAA_ALPHA_PASSTHROUGH 0
// #define PSMAA_THRESHOLD_FLOOR 0.018
// #define PSMAA_EDGE_DETECTION_FACTORS_HIGH_LUMA float4(threshold, CMAALCAFactor, SMAALCAFactor, SMAALCAAdjustmentBiasByCMAALocalContrast)
// #define PSMAA_EDGE_DETECTION_FACTORS_LOW_LUMA float4(threshold, CMAALCAFactor, SMAALCAFactor, SMAALCAAdjustmentBiasByCMAALocalContrast)
// #define PSMAA_EDGE_DETECTION_SHAPE_BASED_FACTORS float2(threshold, SMAALCAFactor)

namespace PSMAA
{
  /**
   * Get the luma weighted delta between two vectors
   */
  float GetDelta(float3 cA, float3 cB, float rangeA, float rangeB)
  {
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

  float GetDelta(float3 cA, float3 cB)
  {
    float rangeA = Functions::max(cA) - Functions::min(cA);
    float rangeB = Functions::max(cB) - Functions::min(cB);
    return GetDelta(cA, cB, rangeA, rangeB);
  }

  /**
   * Get the deltas for the current pixel. Combines euclidian luma detection with color detection dynamically based on the colorfulness of the pixels.
   */
  float2 GetDeltas(float3 cLeft, float3 cTop, float3 cCurrent, float rangeLeft, float rangeTop, float rangeCurrent)
  {
    float2 deltas;
    deltas.x = GetDelta(cLeft, cCurrent, rangeLeft, rangeCurrent);
    deltas.y = GetDelta(cTop, cCurrent, rangeTop, rangeCurrent);

    return deltas;
  }

  /**
   * Calculates a weighted average of a 9 tap pattern of pixels.
   * returns float3 localavg
   */
  float3 CalcLocalAvg(
      float3 NW, float3 N, float3 NE,
      float3 W, float3 C, float3 E,
      float3 SW, float3 S, float3 SE,
      float4 strength)
  {
    // pattern:
    //  e f g
    //  h a b
    //  i c d
    // TODO: optimise by caching repeating values, and by calculating inverse of the constants
    // and applying them to the sums using MAD operations where possible.
    // Reinforced
    float3 bottomHalf = (W + C + E + SW + S + SE) / 6f;
    float3 topHalf = (N + C + E + NW + W + NE) / 6f;
    float3 leftHalf = (NW + W + SW + N + C + S) / 6f;
    float3 rightHalf = (N + C + S + NE + E + SE) / 6f;

    float3 diagHalfNW = (SW + C + NE + N + W + NW) / 6f;
    float3 diagHalfSE = (SW + C + NE + E + SE + S) / 6f;
    float3 diagHalfNE = (NW + C + SE + NE + E + N) / 6f;
    float3 diagHalfSW = (NW + C + SE + W + S + SW) / 6f;

    float3 diag1 = (NW + C + SE) / 3f;
    float3 diag2 = (SW + C + NE) / 3f;

    float3 horz = (W + C + E) / 3f;
    float3 vert = (N + C + S) / 3f;

    float3 maxDesired = Functions::max(leftHalf, bottomHalf, diag1, diag2, topHalf, rightHalf, diagHalfNE, diagHalfNW, diagHalfSE, diagHalfSW);
    float3 minDesired = Functions::min(leftHalf, bottomHalf, diag1, diag2, topHalf, rightHalf, diagHalfNE, diagHalfNW, diagHalfSE, diagHalfSW);

    float3 maxLine = Functions::max(horz, vert, maxDesired);
    float3 minLine = Functions::min(horz, vert, minDesired);

    // Weakened
    float3 surround = (W + N + E + S + C) / 5f;
    float3 diagSurround = (NW + NE + SW + SE + C) / 5f;

    float3 maxUndesired = max(surround, diagSurround);
    float3 minUndesired = min(surround, diagSurround);

    // Constants for local average calculation
    static const float undesiredAmount = 2f;
    static const float DesiredPatternsWeight = 2f;
    static const float LineWeight = 1.3f;
    // Multiply by 2f, because each sum is from a pair of values
    static const float LocalAvgDenominator = mad(DesiredPatternsWeight + LineWeight, 2f, -undesiredAmount);

    float3 undesiredSum = -maxUndesired - minUndesired;
    float3 lineSum = maxLine + minLine;
    float3 desiredSum = maxDesired + minDesired;

    lineSum = mad(lineSum, LineWeight, undesiredSum);
    desiredSum = mad(desiredSum, DesiredPatternsWeight, lineSum);
    float3 localavg = desiredSum / LocalAvgDenominator;

    // If the new target pixel value is less bright than the max desired shape, boost it's value accordingly
    float maxLuma = Color::luma(maxLine);
    float minLuma = Color::luma(minLine);
    float localLuma = Color::luma(localavg);
    // TODO: try using delta between origLuma and localLuma to determine strength and direction of the boost/weakening
    // if new value is brighter than max desired shape, boost strength is 0f and localavg should be multiplied by 1f. Else, boost it.
    float boost = saturate(maxLuma - localLuma);
    float weaken = minLuma - localLuma;
    float origLuma = Color::luma(C);
    float direction = PSMAA_PRE_PROCESSING_LUMA_PRESERVATION_BIAS + origLuma - localLuma;
    direction = saturate(mad(direction, PSMAA_PRE_PROCESSING_LUMA_PRESERVATION_STRENGTH, .5));
    float mod = lerp(weaken, boost, direction);
    localavg *= 1f + mod; // add to 1, because the operation must increase the local avg, not take fraction of it

    return lerp(C, localavg, strength);
  }

  void GatherNeighborDeltas(
      PSMAATexture2D(deltaTex),
      float4 gatherOffset,
      out float4 horzDeltas,
      out float4 vertDeltas)
  {
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

  float2 CalculateCMAALocalContrast(float4 vertDeltas, float4 horzDeltas, float cmaaLCAFactor)
  {
    float2 cmaaLCA;
    cmaaLCA.r = Functions::max(vertDeltas.x, vertDeltas.y, vertDeltas.z, horzDeltas.w);
    cmaaLCA.g = Functions::max(horzDeltas.x, horzDeltas.y, horzDeltas.z, vertDeltas.w);
    return cmaaLCA * cmaaLCAFactor;
  }

  float2 DetectEdges(float2 deltas, float threshold, float2 cmaaLCA)
  {
    float2 currDeltas = deltas - cmaaLCA.rg;
    return step(threshold, currDeltas);
  }

  float2 GetSMAAExtremesDeltas(PSMAATexture2D(deltaTex), float4 offset)
  {
    return float2(
        PSMAASamplePoint(deltaTex, offset.xy).r, // leftLeftDelta
        PSMAASamplePoint(deltaTex, offset.zw).g  // topTopDelta
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
      float2 cmaaLocalContrast)
  {
    float2 maxDeltas = float2(Functions::max(verticalDeltas), Functions::max(horizontalDeltas));
    float finalDelta = max(maxDeltas.r, maxDeltas.g);

    float2 currDeltas = mad(cmaaLocalContrast, LCAFactors.y, float2(verticalDeltas.y, horizontalDeltas.y));
    edges.rg *= step(finalDelta, LCAFactors.x * currDeltas);

    return edges;
  }

  namespace Pass
  {
    void PreProcessingPS(
        float2 texcoord,
        PSMAATexture2D(colorGammaTex), // input color texture (C)
        out float4 filteredCopy,       // output current color (C)
        out float maxLocalLuma         // output maximum luma from all nine samples
    )
    {
      // NW N NE
      // W  C  E
      // SW S SE
      float3 NW = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(-1, -1)).rgb;
      float3 W = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(-1, 0)).rgb;
      float3 SW = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(-1, 1)).rgb;
      float3 N = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(0, -1)).rgb;
      float3 C = PSMAASampleLevelZero(colorGammaTex, texcoord).rgb;
      float3 S = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(0, 1)).rgb;
      float3 NE = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(1, -1)).rgb;
      float3 E = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(1, 0)).rgb;
      float3 SE = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(1, 1)).rgb;

      float3 maxNeighbourColor = Functions::max(NW, W, SW, N, S, NE, E, SE);
      float3 maxLocalColor = max(maxNeighbourColor, C);
      // These make sure that Red and Blue don't count as much as Green,
      // without making all results darker when taking the greatest component
      static const float3 LumaCorrection = float3(.297, 1f, .101);
      float prelimMaxLocalLuma = Functions::max(maxLocalColor * LumaCorrection);

      float4 deltas;
      deltas.r = GetDelta(W, C);
      deltas.g = GetDelta(N, C);
      deltas.b = GetDelta(E, C);
      deltas.a = GetDelta(S, C);

      // Use detection factors for edge detection here too, so that the results of this pass scale proportionally to the needs of edge detection.
      float2 detectionFactors = lerp(PSMAA_EDGE_DETECTION_FACTORS_LOW_LUMA.xy, PSMAA_EDGE_DETECTION_FACTORS_HIGH_LUMA.xy, prelimMaxLocalLuma);
      // scale with multipliers specific to this pass
      detectionFactors *= float2(PSMAA_PRE_PROCESSING_THRESHOLD_MULTIPLIER, PSMAA_PRE_PROCESSING_CMAA_LCA_FACTOR_MULTIPLIER);
      // Minimum threshold to prevent blending in very dark areas
      float threshold = max(detectionFactors.x, PSMAA_THRESHOLD_FLOOR);
      float cmaaLCAFactor = detectionFactors.y;

      float4 maxLocalDeltas;
      maxLocalDeltas.r = Functions::max(deltas.gba);
      maxLocalDeltas.g = Functions::max(deltas.bar);
      maxLocalDeltas.b = Functions::max(deltas.arg);
      maxLocalDeltas.a = Functions::max(deltas.rgb);

      deltas -= maxLocalDeltas * cmaaLCAFactor;

      float4 edges = step(threshold, deltas);
      // skip check for corners (to prevent interference with AA) and single lines (to prevent blur)
      float cornerNumber = (edges.r + edges.b) * (edges.g + edges.a);
      float edgeNumber = Functions::sum(edges);
      bool skipProcessing = (edgeNumber < 2f) || (cornerNumber == 1f);

      if (skipProcessing)
      {
        maxLocalLuma = prelimMaxLocalLuma;
        filteredCopy = float4(C, 0f); // no change, so set change to 0f
        return;
      }

      // Determine blending strength based on the number of edges detected
      float strength = max(cornerNumber / 4f, PSMAA_PRE_PROCESSING_MIN_STRENGTH);
      strength *= PSMAA_PRE_PROCESSING_STRENGTH;

      float3 localAvg = CalcLocalAvg(
          NW, N, NE, W, C, E, SW, S, SE,
          strength);

      // use result for local luma instead of the original color for more accurate results
      float3 finalMaxLocalColor = max(maxNeighbourColor, localAvg);
      maxLocalLuma = Functions::max(finalMaxLocalColor * LumaCorrection);

      static const float minChange = (1f / 6f); // TODO: add comprehensive way of dealing with min texture channel values
      // multiplying and then saturating prevents high values from being treated too strongly
      // and makes sure lower values can be presented more precisely in the limited range of values of a 2bit channel
      float change = GetDelta(C, localAvg) * 1.5f;
      // minChange makes sure that any change is treated as more than 0f
      change = change > 0f ? minChange + change : 0f; // TODO: turn this into format function for library
      change = saturate(change);

      filteredCopy = float4(localAvg, change);
    }

    void PreProcessingPSOld(
        float2 texcoord,
        PSMAATexture2D(colorGammaTex), // input color texture (C)
        out float4 filteredCopy,       // output current color (C)
        out float maxLocalLuma         // output maximum luma from all nine samples
    )
    {
      // NW N NE
      // W  C  E
      // SW S SE
      float3 NW = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(-1, -1)).rgb;
      float3 W = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(-1, 0)).rgb;
      float3 SW = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(-1, 1)).rgb;
      float3 N = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(0, -1)).rgb;
      float3 C = PSMAASampleLevelZero(colorGammaTex, texcoord).rgb;
      float3 S = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(0, 1)).rgb;
      float3 NE = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(1, -1)).rgb;
      float3 E = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(1, 0)).rgb;
      float3 SE = PSMAASampleLevelZeroOffset(colorGammaTex, texcoord, float2(1, 1)).rgb;

      float3 maxNeighbourColor = Functions::max(NW, W, SW, N, S, NE, E, SE);
      float3 maxLocalColor = max(maxNeighbourColor, C);
      // These make sure that Red and Blue don't count as much as Green,
      // without making all results darker when taking the greatest component
      static const float3 LumaCorrection = float3(.297, 1f, .101);
      float prelimMaxLocalLuma = Functions::max(maxLocalColor * LumaCorrection);

      float4 deltas;
      deltas.r = GetDelta(W, C);
      deltas.g = GetDelta(N, C);
      deltas.b = GetDelta(E, C);
      deltas.a = GetDelta(S, C);

      // Use detection factors for edge detection here too, so that the results of this pass scale proportionally to the needs of edge detection.
      float2 detectionFactors = lerp(PSMAA_EDGE_DETECTION_FACTORS_LOW_LUMA.xy, PSMAA_EDGE_DETECTION_FACTORS_HIGH_LUMA.xy, prelimMaxLocalLuma);
      // scale with multipliers specific to this pass
      detectionFactors *= float2(PSMAA_PRE_PROCESSING_THRESHOLD_MULTIPLIER, PSMAA_PRE_PROCESSING_CMAA_LCA_FACTOR_MULTIPLIER);
      // Minimum threshold to prevent blending in very dark areas
      float threshold = max(detectionFactors.x, PSMAA_THRESHOLD_FLOOR);
      float cmaaLCAFactor = detectionFactors.y;

      float4 maxLocalDeltas;
      maxLocalDeltas.r = Functions::max(deltas.gba);
      maxLocalDeltas.g = Functions::max(deltas.bar);
      maxLocalDeltas.b = Functions::max(deltas.arg);
      maxLocalDeltas.a = Functions::max(deltas.rgb);

      deltas -= maxLocalDeltas * cmaaLCAFactor;

      float4 edges = step(threshold, deltas);

      float3 localAvg = CalcLocalAvg(
          NW, N, NE, W, C, E, SW, S, SE,
          edges);

      // use result for local luma instead of the original color for more accurate results
      float3 finalMaxLocalColor = max(maxNeighbourColor, localAvg);
      maxLocalLuma = Functions::max(finalMaxLocalColor * LumaCorrection);

      filteredCopy = float4(localAvg, 0f);
    }

    void PreProcessingOutputPS(
        float2 texcoord,
        PSMAATexture2D(filteredCopyTex),
        PSMAATexture2D(colorTex),
        out float4 color)
    {
#if PSMAA_ALPHA_PASSTHROUGH

      float oldAlpha = PSMAASamplePoint(colorTex, texcoord).a;
      float3 filteredColor = PSMAASamplePoint(filteredCopyTex, texcoord).rgb;
      color = float4(filteredColor, oldAlpha);

#else

      color = PSMAASamplePoint(filteredCopyTex, texcoord);

#endif
    }

    /**
     * Calculates the offsets for the current pixel.
     * Decided to leave the offset as an array, because I'll likely need more values in the future.
     */
    void DeltaCalculationVS(float2 texcoord, out float4 offset[1])
    {
      offset[0] = mad(PSMAA_BUFFER_METRICS.xyxy, float4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy);
    }

    /**
     * Calculate the top and left deltas for the current pixel.
     */
    void DeltaCalculationPS(float2 texcoord, float4 offset[1], PSMAATexture2D(colorGammaTex), out float2 deltas)
    {
      float3 current = PSMAASamplePoint(colorGammaTex, texcoord).rgb;
      float3 left = PSMAASamplePoint(colorGammaTex, offset[0].xy).rgb;
      float3 top = PSMAASamplePoint(colorGammaTex, offset[0].zw).rgb;

      float rangeCurrent = Functions::max(current) - Functions::min(current);
      float rangeLeft = Functions::max(left) - Functions::min(left);
      float rangeTop = Functions::max(top) - Functions::min(top);

      deltas = GetDeltas(left, top, current, rangeLeft, rangeTop, rangeCurrent);
    }

    void EdgeDetectionVS(float2 texcoord, out float4 offset[2])
    {
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
        out float2 edgesOutput)
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
      if (dot(edges, float2(1.0, 1.0)) == 0f)
        discard;

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

    void ShapeEdgeDetectionPS(
        float2 texcoord,
        float4 offset[2],
        PSMAATexture2D(colorGammaTex),
        out float2 edgesOutput)
    {
      // NW N NE
      // W  C  E
      // SW S SE
      float3 NW = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(-1, -1)).rgb;
      float3 W = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(-1, 0)).rgb;
      float3 SW = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(-1, 1)).rgb;
      float3 N = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(0, -1)).rgb;
      float3 C = PSMAASamplePoint(colorGammaTex, texcoord).rgb;
      float3 S = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(0, 1)).rgb;
      float3 NE = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(1, -1)).rgb;
      float3 E = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(1, 0)).rgb;
      float3 SE = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(1, 1)).rgb;

      // TODO: optimize by calculating all ranges once and passing them to GetDelta
      float4 circumDeltas;
      circumDeltas.r = GetDelta(W, C);
      circumDeltas.g = GetDelta(N, C);
      circumDeltas.b = GetDelta(E, C);
      circumDeltas.a = GetDelta(S, C);

      float4 horzDeltas;
      horzDeltas.r = GetDelta(NW, N);
      horzDeltas.g = GetDelta(NE, N);
      horzDeltas.b = GetDelta(SW, S);
      horzDeltas.a = GetDelta(SE, S);

      float4 vertDeltas;
      vertDeltas.r = GetDelta(SW, W);
      vertDeltas.g = GetDelta(NW, W);
      vertDeltas.b = GetDelta(SE, E);
      vertDeltas.a = GetDelta(NE, E);

      // r NW - NE g
      //   -  -  -
      // b SW - SE a
      float4 maxCornerDeltas = max(horzDeltas.rgba, vertDeltas.garb) * 0.6f;

      float discourageStrength = 0.8f;

      //      r   b
      //   NW | N | NE
      // g ---+---+---
      //    W | C | E
      // a ---+---+---
      //   SW | S | SE
      float4 lines = min(circumDeltas.rgba, maxCornerDeltas.rrga, maxCornerDeltas.bgab);
      float2 lineBalance = lines.rg - max(lines.gr, lines.ab) * discourageStrength;
      // lineBalance /= 3f;
      // float4 straightLines = min(circumDeltas.rgba, float4(horzDeltas.r, vertDeltas.g, horzDeltas.g, vertDeltas.b), float4(horzDeltas.b, vertDeltas.a, horzDeltas.a, vertDeltas.r));

      //   _         _|       _    |_ 
      // r: |_ , g: |  , b: _| , a:  |
      float4 repairs = min(float4(vertDeltas.g, horzDeltas.g, vertDeltas.r, horzDeltas.r), circumDeltas.argb, circumDeltas.rgrg);
      float4 repairBalance = repairs.rgba - repairs.barg * discourageStrength * 2f;

      // r: facing top-left, g: facing top-right, b: facing bottom-right, a: facing bottom-left
      float4 diagonals = min(circumDeltas.rgba, circumDeltas.gbar, maxCornerDeltas.brbr, maxCornerDeltas.gaga);
      // float4 diagonals = min(circumDeltas.rgba, circumDeltas.gbar * horzDeltas.grba * vertDeltas.rbag, 1f/4f); // TODO: try expanding into all options
      float4 diagBalance = diagonals.rgba - max(diagonals.argb, diagonals.gbar) * discourageStrength * .8;
      // diagBalance /= 4f;

      // r: protruding from right side to left delta
      // g: protruding from bottom side to top delta
      // b: protruding from left side to right delta
      // a: protruding from top side to bottom delta
      float4 protrusions = min(circumDeltas.argb, circumDeltas.rgba, circumDeltas.gbar, maxCornerDeltas.gabr, maxCornerDeltas.abrg);
      float2 protrusionBalance = protrusions.rg - max(protrusions.ar, protrusions.gb) * discourageStrength;
      // protrusionBalance /= 5f;

      // max encouraging shapes: r = left, g = top
      // max discouraging shape: b = left, a = top
      // Get maximum encouraging shapes to check if deltas fit pattern consistent with an edge being there
      float2 maxEncouraging = Functions::max(lineBalance, diagBalance.ar, diagBalance.rg, protrusionBalance, repairBalance.rg, repairBalance.ba);
      // float2 maxDiscouraging = Functions::min(lines.gr, lines.ab, protrusions.ar, protrusions.gb);
      float maxLocalDelta = Functions::max(Functions::max(circumDeltas), Functions::max(horzDeltas), Functions::max(vertDeltas));
      maxLocalDelta = max(saturate(maxLocalDelta * 3f), 0.10); // prevent ridiculous increase in very low contrast areas

      // Subtract discouraging shapes from encouraging shapes to get the "winner"
      // Then divide by maxLocalDelta to compensate for local contrast differences
      float2 balance = saturate(maxEncouraging) / maxLocalDelta;
      float2 edges = step(PSMAA_EDGE_DETECTION_SHAPE_BASED_FACTORS.xx / discourageStrength, balance); // Temporarily return only the remaining shape deltas, for testing purposes
      // edgesOutput = edges;

      if (edges.r == -edges.g)
        discard;

      // Get extremes for SMAA LCA
      float3 WW = PSMAASamplePoint(colorGammaTex, offset[1].xy).rgb;
      float3 NN = PSMAASamplePoint(colorGammaTex, offset[1].zw).rgb;
      float2 extremesDeltas = float2(
          GetDelta(WW, W), // leftLeftDelta
          GetDelta(NN, N)  // topTopDelta
      ); 

      // [   ] [    ] [    ]
      // [e.x] [cd.r] [cd.b]
      // [   ] [    ] [    ]
      float3 vertDeltas2 = float3(circumDeltas.b, circumDeltas.r, extremesDeltas.x);
      // [  ] [e.y ] [  ]
      // [  ] [cd.g] [  ]
      // [  ] [cd.a] [  ]
      float3 horzDeltas2 = float3(circumDeltas.a, circumDeltas.g, extremesDeltas.y);

      edgesOutput = ApplySMAALCA(edges, horzDeltas2, vertDeltas2, float2(PSMAA_EDGE_DETECTION_SHAPE_BASED_FACTORS.y, 0f), 0f);
    }

    void ShapeEdgeDetectionPSOld(
        float2 texcoord,
        float4 offset[2],
        PSMAATexture2D(colorGammaTex),
        out float2 edgesOutput)
    {
      // NW N NE
      // W  C  E
      // SW S SE
      float3 NW = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(-1, -1)).rgb;
      float3 W = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(-1, 0)).rgb;
      float3 SW = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(-1, 1)).rgb;
      float3 N = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(0, -1)).rgb;
      float3 C = PSMAASamplePoint(colorGammaTex, texcoord).rgb;
      float3 S = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(0, 1)).rgb;
      float3 NE = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(1, -1)).rgb;
      float3 E = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(1, 0)).rgb;
      float3 SE = PSMAASamplePointOffset(colorGammaTex, texcoord, float2(1, 1)).rgb;

      // TODO: optimize by calculating all ranges once and passing them to GetDelta
      float4 circumDeltas;
      circumDeltas.r = GetDelta(W, C);
      circumDeltas.g = GetDelta(N, C);
      circumDeltas.b = GetDelta(E, C);
      circumDeltas.a = GetDelta(S, C);

      float4 horzDeltas;
      horzDeltas.r = GetDelta(NW, N);
      horzDeltas.g = GetDelta(NE, N);
      horzDeltas.b = GetDelta(SW, S);
      horzDeltas.a = GetDelta(SE, S);

      float4 vertDeltas;
      vertDeltas.r = GetDelta(SW, W);
      vertDeltas.g = GetDelta(NW, W);
      vertDeltas.b = GetDelta(SE, E);
      vertDeltas.a = GetDelta(NE, E);

      // r NW - NE g
      //   -  -  -
      // b SW - SE a
      float4 maxCornerDeltas = max(horzDeltas.rgba, vertDeltas.garb) * 0.6f;

      float discourageStrength = 0.8f;

      //      r   b
      //   NW | N | NE
      // g ---+---+---
      //    W | C | E
      // a ---+---+---
      //   SW | S | SE
      float4 lines = min(circumDeltas.rgba, maxCornerDeltas.rrga, maxCornerDeltas.bgab);
      float2 lineBalance = lines.rg - max(lines.gr, lines.ab) * discourageStrength;
      // lineBalance /= 3f;
      // float4 straightLines = min(circumDeltas.rgba, float4(horzDeltas.r, vertDeltas.g, horzDeltas.g, vertDeltas.b), float4(horzDeltas.b, vertDeltas.a, horzDeltas.a, vertDeltas.r));

      //   _         _|       _    |_ 
      // r: |_ , g: |  , b: _| , a:  |
      float4 repairs = min(float4(vertDeltas.g, horzDeltas.g, vertDeltas.r, horzDeltas.r), circumDeltas.argb, circumDeltas.rgrg);
      float4 repairBalance = repairs.rgba - repairs.barg * discourageStrength * 2f;

      // r: facing top-left, g: facing top-right, b: facing bottom-right, a: facing bottom-left
      float4 diagonals = min(circumDeltas.rgba, circumDeltas.gbar, maxCornerDeltas.brbr, maxCornerDeltas.gaga);
      // float4 diagonals = min(circumDeltas.rgba, circumDeltas.gbar * horzDeltas.grba * vertDeltas.rbag, 1f/4f); // TODO: try expanding into all options
      float4 diagBalance = diagonals.rgba - max(diagonals.argb, diagonals.gbar) * discourageStrength * .8;
      // diagBalance /= 4f;

      // r: protruding from right side to left delta
      // g: protruding from bottom side to top delta
      // b: protruding from left side to right delta
      // a: protruding from top side to bottom delta
      float4 protrusions = min(circumDeltas.argb, circumDeltas.rgba, circumDeltas.gbar, maxCornerDeltas.gabr, maxCornerDeltas.abrg);
      float2 protrusionBalance = protrusions.rg - max(protrusions.ar, protrusions.gb) * discourageStrength;
      // protrusionBalance /= 5f;

      // max encouraging shapes: r = left, g = top
      // max discouraging shape: b = left, a = top
      // Get maximum encouraging shapes to check if deltas fit pattern consistent with an edge being there
      float2 maxEncouraging = Functions::max(lineBalance, diagBalance.ar, diagBalance.rg, protrusionBalance, repairBalance.rg, repairBalance.ba);
      // float2 maxDiscouraging = Functions::min(lines.gr, lines.ab, protrusions.ar, protrusions.gb);
      float maxLocalDelta = Functions::max(Functions::max(circumDeltas), Functions::max(horzDeltas), Functions::max(vertDeltas));
      maxLocalDelta = max(saturate(maxLocalDelta * 3f), 0.10); // prevent ridiculous increase in very low contrast areas

      // Subtract discouraging shapes from encouraging shapes to get the "winner"
      // Then divide by maxLocalDelta to compensate for local contrast differences
      float2 balance = saturate(maxEncouraging) / maxLocalDelta;
      float2 edges = step(PSMAA_EDGE_DETECTION_SHAPE_BASED_FACTORS.xx / discourageStrength, balance); // Temporarily return only the remaining shape deltas, for testing purposes
      // edgesOutput = edges;

      if (edges.r == -edges.g)
        discard;

      // Get extremes for SMAA LCA
      float3 WW = PSMAASamplePoint(colorGammaTex, offset[1].xy).rgb;
      float3 NN = PSMAASamplePoint(colorGammaTex, offset[1].zw).rgb;
      float2 extremesDeltas = float2(
          GetDelta(WW, W), // leftLeftDelta
          GetDelta(NN, N)  // topTopDelta
      ); 

      // [   ] [    ] [    ]
      // [e.x] [cd.r] [cd.b]
      // [   ] [    ] [    ]
      float3 vertDeltas2 = float3(circumDeltas.b, circumDeltas.r, extremesDeltas.x);
      // [  ] [e.y ] [  ]
      // [  ] [cd.g] [  ]
      // [  ] [cd.a] [  ]
      float3 horzDeltas2 = float3(circumDeltas.a, circumDeltas.g, extremesDeltas.y);

      edgesOutput = ApplySMAALCA(edges, horzDeltas2, vertDeltas2, float2(PSMAA_EDGE_DETECTION_SHAPE_BASED_FACTORS.y, 0f), 0f);
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
        out float2 edgesOutput)
    {
      // Calculate color deltas:
      float4 delta;
      float4 colorRange;

      float3 C = PSMAASamplePoint(colorTex, texcoord).rgb;
      float midRange = Functions::max(C) - Functions::min(C);

      float3 Cleft = PSMAASamplePoint(colorTex, offset[0].xy).rgb;
      float rangeLeft = Functions::max(Cleft) - Functions::min(Cleft);
      float colorfulness = max(midRange, rangeLeft);
      float3 t = abs(C - Cleft);
      delta.x = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t));

      float3 Ctop = PSMAASamplePoint(colorTex, offset[0].zw).rgb;
      float rangeTop = Functions::max(Ctop) - Functions::min(Ctop);
      colorfulness = max(midRange, rangeTop);
      t = abs(C - Ctop);
      delta.y = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t));

      // We do the usual threshold:
      float2 edges = step(threshold, delta.xy);

      // Early return if there is no edge:
      if (edges.x == -edges.y)
        discard;

      // Calculate right and bottom deltas:
      float3 Cright = PSMAASamplePoint(colorTex, offset[1].xy).rgb;
      t = abs(C - Cright);
      float rangeRight = Functions::max(Cright) - Functions::min(Cright);
      colorfulness = max(midRange, rangeRight);
      delta.z = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t));

      float3 Cbottom = PSMAASamplePoint(colorTex, offset[1].zw).rgb;
      t = abs(C - Cbottom);
      float rangeBottom = Functions::max(Cright) - Functions::min(Cright);
      colorfulness = max(midRange, rangeBottom);
      delta.w = (colorfulness * Functions::max(t)) + ((1.0 - colorfulness) * Color::luma(t));

      // Calculate the maximum delta in the direct neighborhood:
      float2 maxDelta = max(delta.xy, delta.zw);

      // Calculate left-left and top-top deltas:
      float3 Cleftleft = PSMAASamplePoint(colorTex, offset[2].xy).rgb;
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