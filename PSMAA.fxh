namespace PSMAA {
  // /**
  // * Get the luma weighted delta between two vectors
  // */
  // float GetDelta(float3 a, float3 b) {
  //   // TODO: replace by library function
  //   float3 comp_delta = abs(a - b);
  //   return dot(comp_delta, float3(0.299, 0.587, 0.114));
  // }

  float luma(float3 color){
      // TODO: replace by library function
      return dot(color, float3(0.299, 0.587, 0.114));
  }

  /**
  * Get the luma weighted delta between two vectors
  */
  float GetDelta(float3 cA, float3 cB, float rangeA, float rangeB) {
    float colorfulness = max(rangeA, rangeB)
    float3 cDelta = abs(cA - cB);

    float colorDelta = colorfulness * max(cDelta.x, max(cDelta.y, cDelta.z)); // TODO: replace by library function
    float euclidianDelta = (1f - colorfulness) * luma(colorDelta)
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