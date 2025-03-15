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
}