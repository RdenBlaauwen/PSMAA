
// TODO: replace this with language-specific values in te future
// reshade-specific definition should eventually go into the main file, not here
#define PSMAA_BUFFER_METRICS float4(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
#define PSMAATexture2D(texture) sampler2D 
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

    void DeltaCalculationPS(float2 texcoord, float4 offset[1], PSMAATexture2D(colorTex), out float2 deltas) {
      float3 current = PSMAASamplePoint(colorTex, texcoord).rgb;
      float3 left = PSMAASamplePoint(colorTex, offset[0].xy).rgb;
      float3 top = PSMAASamplePoint(colorTex, offset[0].zw).rgb;

      float rangeCurrent = Functions::max(current) - Functions::min(current);
      float rangeLeft = Functions::max(left) - Functions::min(left);
      float rangeTop = Functions::max(top) - Functions::min(top);

      deltas = GetDeltas(left, top, current, rangeLeft, rangeTop, rangeCurrent);
    }
  }
}