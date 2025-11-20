// MACROS
// The following preprocessor variables should be defined in the main file.
// The values are defaults and can be changed as needed:
// #define APB_LUMA_PRESERVATION_BIAS .5
// #define APB_LUMA_PRESERVATION_STRENGTH 1f
// #define APB_MIN_FILTER_STRENGTH .15
// #define APB_FILTER_STRENGTH_DELTA_WEIGHTS float4(.15, .25, .25, .5)

// DEPENDENCIES
// #include "Functions.fxh"
// #include "Color.fxh"

namespace AnomalousPixelBlending
{
  float4 applyLCA(float4 deltas, float lcaFactor)
  {
    float4 maxLocalDeltas = Functions::max(deltas.gbar, deltas.barg, deltas.argb);

    return mad(maxLocalDeltas, -lcaFactor, deltas);
  }

  float4 applyCornerCorrection(float4 deltas)
  {
    float2 greatestCornerDeltas = max(deltas.rg, deltas.ba);
    float avgGreatestCornerDelta = (greatestCornerDeltas.x + greatestCornerDeltas.y) / 2f;
    // taking the square, then dividing by the average greatest corner delta diminishes smaller deltas
    // and preserves the deltas of the largest corner
    return (deltas * deltas) / avgGreatestCornerDelta;
  }

  bool checkIfCorner(float4 deltas, float cornerCorrectionStrength, float edgeThreshold)
  {
    float4 correctedDeltas = applyCornerCorrection(deltas);
    correctedDeltas = lerp(deltas, correctedDeltas, cornerCorrectionStrength);

    float4 correctedEdges = step(edgeThreshold, correctedDeltas);
    float cornerNumber = (correctedEdges.r + correctedEdges.b) * (correctedEdges.g + correctedEdges.a);
    return cornerNumber == 1f;
  }

  float calcBlendingStrength(float4 deltas, float threshold, float marginFactor)
  {
    float4 edges = smoothstep(threshold / marginFactor, threshold * marginFactor, deltas);
    // redo to get normal deltas, use that to calc filter strength
    float cornerAmount = (edges.r + edges.b) * (edges.g + edges.a);
    // Determine filter strength based on the number of corners detected
    return max(cornerAmount / 4f, APB_MIN_FILTER_STRENGTH);
  }

  /**
   * Calculates a weighted average of a 9 tap pattern of pixels.
   * returns float3 localavg
   */
  float3 CalcLocalAvg(
      float3 NW, float3 N, float3 NE,
      float3 W, float3 C, float3 E,
      float3 SW, float3 S, float3 SE,
      float strength)
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
    float direction = APB_LUMA_PRESERVATION_BIAS + origLuma - localLuma;
    direction = saturate(mad(direction, APB_LUMA_PRESERVATION_STRENGTH, .5));
    float mod = lerp(weaken, boost, direction);
    localavg *= 1f + mod; // add to 1, because the operation must increase the local avg, not take fraction of it

    return lerp(C, localavg, strength);
  }
}