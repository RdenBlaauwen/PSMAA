/////////////////////////////////// CREDITS ///////////////////////////////////
// Do not distribute without giving credit to the original author(s).
/*               TSMAA for ReShade 3.1.1+
 *
 *    (Temporal Subpixel Morphological Anti-Aliasing)
 *
 *
 *     Experimental multi-frame SMAA implementation
 *
 *                     by lordbean
 *
 */
/**
 * This shader contains components taken and/or adapted from Lordbean's TSMAA.
 * https://github.com/lordbean-git/reshade-shaders/blob/main/Shaders/TSMAA.fx
 *
 * All code attributed to "Lordbean" is copyright (c) Derek Brush (derekbrush@gmail.com)
 */
/*------------------------------------------------------------------------------
 * THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *-------------------------------------------------------------------------------*/

// This code needs code from the SMAA shader. Make sure to include it before this file.
// It also needs some of the same pre-processor definitions as the SMAA shader,
// so make sure to include this file after any relevant SMAA pre-processor definitions.

// #define SMOOTHING_STRENGTH_MOD
// #define EDGE_THRESHOLD_MOD
// #define SMOOTHING_THRESHOLD
// #define SMOOTHING_SATURATION_DIVISOR_FLOOR // This is used to prevent division by zero in the saturation function
// #define SMOOTHING_MIN_ITERATIONS
// #define SMOOTHING_MAX_ITERATIONS
// #define SMOOTHING_LUMA_WEIGHTS
// #define SMOOTHING_BUFFER_RCP_HEIGHT
// #define SMOOTHING_BUFFER_RCP_WIDTH
// #define SMOOTHING_DEBUG
// #define SMOOTHING_DELTA_WEIGHT_DEBUG
// #define SMOOTHING_USE_CORNER_WEIGHT
// #define SMOOTHING_DELTA_WEIGHT_FLOOR
// #define SMOOTHING_MIN_DELTA_WEIGHT
// #define SMOOTHING_MAX_DELTA_WEIGHT
// #define SMOOTHING_DELTA_WEIGHT_PREDICATION_FACTOR

// #define SmoothingTexture2D(tex)
// #define SmoothingSamplePoint(tex, coord)
// #define SmoothingSampleLevelZero(tex, coord)

// examples
// #define SMOOTHING_STRENGTH_MOD 1f
// #define EDGE_THRESHOLD_MOD 0.35
// #define SMOOTHING_THRESHOLD 0.05
// #define SMOOTHING_SATURATION_DIVISOR_FLOOR 0.01
// #define SMOOTHING_MIN_ITERATIONS 3f
// #define SMOOTHING_MAX_ITERATIONS 15f
// #define SMOOTHING_LUMA_WEIGHTS float3(0.299, 0.587, 0.114)
// #define SMOOTHING_BUFFER_RCP_HEIGHT BUFFER_RCP_HEIGHT
// #define SMOOTHING_BUFFER_RCP_WIDTH BUFFER_RCP_WIDTH
// #define SMOOTHING_DEBUG false
// #define SMOOTHING_DELTA_WEIGHT_DEBUG false
// #define SMOOTHING_USE_CORNER_WEIGHT 0f
// #define SMOOTHING_DELTA_WEIGHT_FLOOR .06
// #define SMOOTHING_MIN_DELTA_WEIGHT .02
// #define SMOOTHING_MAX_DELTA_WEIGHT .25
// #define SMOOTHING_DELTA_WEIGHT_PREDICATION_FACTOR .8

// #define SmoothingTexture2D(tex) sampler tex
// #define SmoothingSamplePoint(tex, coord) tex2D(tex, coord)
// #define SmoothingSampleLevelZero(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
// #define SmoothingGatherLeftDeltas(tex, coord) tex2Dgather(tex, texcoord, 0);
// #define SmoothingGatherTopDeltas(tex, coord) tex2Dgather(tex, texcoord, 1);

namespace BeanSmoothing
{
  float GetDelta(float3 colA, float3 colB){
    float3 delta = abs(colA - colB);
    return Color::luma(delta);
  }

  // Calculate the maximum number of iterations based on the mod value
  uint calculateMaxIterations(float mod)
  {
    return (uint)(lerp(SMOOTHING_MIN_ITERATIONS, SMOOTHING_MAX_ITERATIONS, mod) + .5);
  }

  float dotweight(float3 middle, float3 neighbor, bool useluma)
  {
    if (useluma)
      return Color::luma(neighbor);
    else
      return Color::luma(abs(middle - neighbor));
  }

  float saturation(float3 rgb)
  {
    float maxComp = max(Functions::max(rgb), SMOOTHING_SATURATION_DIVISOR_FLOOR);
    return Functions::min(rgb) / maxComp;
  }

  float GetIterationsMod(float4 deltas, float maxLocalLuma)
  {
    float2 maxDeltaCorner = max(deltas.rb, deltas.ga);
    // Use pythagorean theorem to calculate the "weight" of the contrast of the biggest corner
    float deltaWeight = sqrt(Functions::sum(maxDeltaCorner * maxDeltaCorner));

    float2 thresholds = float2(SMOOTHING_MIN_DELTA_WEIGHT, SMOOTHING_MAX_DELTA_WEIGHT);
    thresholds *= mad(1f - maxLocalLuma, -SMOOTHING_DELTA_WEIGHT_PREDICATION_FACTOR, 1f);
    thresholds = max(thresholds, SMOOTHING_DELTA_WEIGHT_FLOOR);
    return smoothstep(thresholds.x, thresholds.y, deltaWeight);
  }

  /**
   * Algorithm called 'smoothing', found in Lordbean's TSMAA.
   * Appears to fix inconsistencies at edges by nudging pixel values towards values of nearby pixels.
   * A little gem that combines well with SMAA, but causes a significant performance hit.
   *
   * Adapted from Lordbean's TSMAA shader.
   *
   * SmoothingTexture2D(colorTex): A texture2D sampler that contains the color data to be smoothed.
   *                               Must be a gamma sampler, as this shader works only in gamma space.
   */
  float3 smooth(float2 texcoord, float4 offset, SmoothingTexture2D(colorTex), SmoothingTexture2D(blendSampler), float threshold, uint maxIterations) : SV_Target
  {
    const float3 debugColorNoHits = float3(0.0, 0.0, 0.0);
    const float3 debugColorSmallHit = float3(0.0, 0.0, 1.0);
    const float3 debugColorBigHit = float3(1.0, 0.0, 0.0);

    float3 mid = SMAASampleLevelZero(colorTex, texcoord).rgb;

    float lumaM = Color::luma(mid);
    float chromaM = saturation(mid);
    bool useluma = lumaM > chromaM;
    if (!useluma)
      lumaM = 0.0;

    float4 lumas; // r = west, g = north, b = east, a = south
    lumas.r = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(-1, 0)).rgb, useluma);
    lumas.g = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(0, -1)).rgb, useluma);
    lumas.b = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(1, 0)).rgb, useluma);
    lumas.a = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(0, 1)).rgb, useluma);

    float rangeMax = Functions::max(lumas.a, lumas.b, lumas.g, lumas.r, lumaM);
    float rangeMin = Functions::min(lumas.a, lumas.b, lumas.g, lumas.r, lumaM);

    float range = rangeMax - rangeMin;

    // early exit check
    bool earlyExit = (range < threshold);
    if (earlyExit)
    {
      // If debug, return no hits color to signify no smoothing took place.
      if (SMOOTHING_DEBUG)
      {
        return debugColorNoHits;
      }
      return mid;
    }
    // If debug, early return. Return hit colors to signify that smoothing takes place here
    if (SMOOTHING_DEBUG)
    {
      // The further the range is above the threshold, the bigger the "hit"
      float strength = smoothstep(threshold, 1.0, range);
      return lerp(debugColorSmallHit, debugColorBigHit, strength);
    }

    float4 diagLumas; // r = northwest, g = northeast, b = southeast, a = southwest
    diagLumas.r = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(-1, -1)).rgb, useluma);
    diagLumas.g = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(1, -1)).rgb, useluma);
    diagLumas.b = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(1, 1)).rgb, useluma);
    diagLumas.a = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(-1, 1)).rgb, useluma);

    // These vals serve as caches, so they can be used later without having to redo them
    // It's just an optimisation thing, though the difference it makes is so small it could just be statistical noise.
    float3 vertLumas; // x = NWSW, y = NS, z = NESE
    vertLumas.xz = diagLumas.rg + diagLumas.ab;
    vertLumas.y = lumas.g + lumas.a;

    float3 horzLumas; // x = NWNE, y = WE, z = SWSE
    horzLumas.xz = diagLumas.ra + diagLumas.gb;
    horzLumas.y = lumas.r + lumas.b;

    float3 vertWeights = abs(mad(-2f, float3(lumas.r, lumaM, lumas.b), vertLumas.xyz));
    float3 horzWeights = abs(mad(-2f, float3(lumas.a, lumaM, lumas.g), horzLumas.zyx));

    bool horzSpan = (vertWeights.x + mad(2.0, vertWeights.y, vertWeights.z)) >= (horzWeights.x + mad(2.0, horzWeights.y, horzWeights.z));
    float lengthSign = horzSpan ? SMOOTHING_BUFFER_RCP_HEIGHT : SMOOTHING_BUFFER_RCP_WIDTH;

    float4 midWeights = float4(
        SMAASampleLevelZero(blendSampler, offset.xy).a,
        SMAASampleLevelZero(blendSampler, offset.zw).g,
        SMAASampleLevelZero(blendSampler, texcoord).zx);

    bool smaahoriz = max(midWeights.x, midWeights.z) > max(midWeights.y, midWeights.w);
    bool smaadata = any(midWeights);
    float maxWeight = Functions::max(midWeights.r, midWeights.g, midWeights.b, midWeights.a);
    float maxblending = 0.5 + (0.5 * maxWeight);

    if ((horzSpan && smaahoriz && smaadata) || (!horzSpan && !smaahoriz && smaadata))
    {
      maxblending *= 1.0 - maxWeight / 2.0;
    }
    else
    {
      maxblending = min(maxblending * 1.5, 1.0);
    };

    float2 lumaNP = lumas.ga;
    SMAAMovc(bool(!horzSpan).xx, lumaNP, lumas.rb);

    // x = north, y = south
    float2 gradients = abs(lumaNP - lumaM);
    float lumaNN;
    if (gradients.x >= gradients.y) {
      lengthSign = -lengthSign;
      lumaNN = lumaNP.x + lumaM;
    } else
      lumaNN = lumaNP.y + lumaM;

    float2 posB = texcoord;

    static const float texelsize = .5; // TODO: constant?

    float2 offNP = float2(0.0, SMOOTHING_BUFFER_RCP_HEIGHT * texelsize);
    SMAAMovc(bool(horzSpan).xx, offNP, float2(SMOOTHING_BUFFER_RCP_WIDTH * texelsize, 0.0));
    SMAAMovc(bool2(!horzSpan, horzSpan), posB, mad(.5, lengthSign, posB));

    float2 posN = posB - offNP;
    float2 posP = posB + offNP;

    float lumaEndN = dotweight(mid, SMAASampleLevelZero(colorTex, posN).rgb, useluma);
    float lumaEndP = dotweight(mid, SMAASampleLevelZero(colorTex, posP).rgb, useluma);

    float gradientScaled = max(gradients.x, gradients.y) * 0.25;
    bool lumaMLTZero = mad(0.5, -lumaNN, lumaM) < 0.0;

    lumaNN *= 0.5;

    lumaEndN -= lumaNN;
    lumaEndP -= lumaNN;

    bool doneN = abs(lumaEndN) >= gradientScaled;
    bool doneP = abs(lumaEndP) >= gradientScaled;
    bool doneNP = doneN && doneP;

    if (!doneNP)
    {
      uint iterations = 0;
      [loop] while (iterations < maxIterations)
      {
        doneNP = doneN && doneP;
        if (doneNP)
          break;
        if (!doneN)
        {
          posN -= offNP;
          lumaEndN = dotweight(mid, SMAASampleLevelZero(colorTex, posN).rgb, useluma);
          lumaEndN -= lumaNN;
          doneN = abs(lumaEndN) >= gradientScaled;
        }
        if (!doneP)
        {
          posP += offNP;
          lumaEndP = dotweight(mid, SMAASampleLevelZero(colorTex, posP).rgb, useluma);
          lumaEndP -= lumaNN;
          doneP = abs(lumaEndP) >= gradientScaled;
        }
        iterations++;
      }
    }

    float2 dstNP = float2(texcoord.y - posN.y, posP.y - texcoord.y);
    SMAAMovc(bool(horzSpan).xx, dstNP, float2(texcoord.x - posN.x, posP.x - texcoord.x));

    bool goodSpan = (dstNP.x < dstNP.y) ? ((lumaEndN < 0.0) != lumaMLTZero) : ((lumaEndP < 0.0) != lumaMLTZero);
    float pixelOffset = mad(-rcp(dstNP.y + dstNP.x), min(dstNP.x, dstNP.y), 0.5) * maxblending;

    float subpixOut;
    [branch] if (!goodSpan)
    {
      subpixOut = mad(mad(2.0, vertLumas.y + horzLumas.y, vertLumas.x + vertLumas.z), 0.083333, -lumaM) / range;  // ABC
      subpixOut = pow(saturate(mad(-2.0, subpixOut, 3.0) * (subpixOut * subpixOut)), 2.0) * pixelOffset; // DEFGH
    } else {
      subpixOut = pixelOffset;
    }

    float2 posM = texcoord;
    SMAAMovc(bool2(!horzSpan, horzSpan), posM, mad(lengthSign, subpixOut, posM));

    return SMAASampleLevelZero(colorTex, posM).rgb;
  }
  
  /**
   * Wrapper around BeanSmoothing
   */
  void SmoothingPS(
    float2 texcoord,
    float4 offset,
    SmoothingTexture2D(deltaTex),
    SmoothingTexture2D(blendSampler),
    SmoothingTexture2D(colorTex),
    SmoothingTexture2D(lumaTex),
    out float3 color
  )
  {
    float4 deltas;
#if __RENDERER__ >= 0xa000 // if DX10 or above
    // get edge data from the bottom (x), bottom-right (y), right (z),
    // and current pixels (w), in that order.
    float4 leftDeltas = SmoothingGatherLeftDeltas(deltaTex, texcoord);
    float4 topDeltas = SmoothingGatherTopDeltas(deltaTex, texcoord);
    deltas = float4(
        leftDeltas.w,
        topDeltas.w,
        leftDeltas.z,
        topDeltas.x);
#else // if DX9
    deltas = float4(
      SmoothingSampleLevelZero(deltaTex, texcoord).rg,
      SmoothingSampleLevelZero(deltaTex, offset.xy).r,
      SmoothingSampleLevelZero(deltaTex, offset.zw).g
    );
#endif

    float maxLocalLuma = SmoothingSamplePoint(lumaTex, texcoord).r;
    float mod = GetIterationsMod(deltas, maxLocalLuma);

    // TODO: consider turning into prepreocssor check for performance. 
    // Consider turning into func that can detect early returns too by checking delta between new and old color
    if(SMOOTHING_DELTA_WEIGHT_DEBUG){
      int maxIterations = calculateMaxIterations(mod);
      float3 result = smooth(texcoord, offset, colorTex, blendSampler, SMOOTHING_THRESHOLD, maxIterations);

      // Check if there's a diff between original and result
      // Helps to detect cases where smooth() did an early return and changed nothing
      float3 original = SmoothingSamplePoint(colorTex, texcoord).rgb;
      // increase the change to make it more visible, especially for small changes
      float change = saturate(sqrt(GetDelta(original, result) * 9f));
      color = float3(0f, change, mod);
      return;
    }

    // if close to 0f, discard. 
    if(mod < 1e-5f) discard; // TODO: make standard 'nullish' function check.

    uint maxIterations = calculateMaxIterations(mod);

    color = smooth(texcoord, offset, colorTex, blendSampler, SMOOTHING_THRESHOLD, maxIterations);
  }
}
