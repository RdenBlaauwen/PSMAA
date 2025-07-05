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
// #define THRESHOLD
// #define SMOOTHING_SATURATION_DIVISOR_FLOOR // This is used to prevent division by zero in the saturation function
// #define SMOOTHING_MAX_ITERATIONS
// #define SMOOTHING_LUMA_WEIGHTS
// #define SMOOTHING_BUFFER_RCP_HEIGHT
// #define SMOOTHING_BUFFER_RCP_WIDTH
// #define SMOOTHING_DEBUG

// #define SmoothingTexture2D(tex)

// examples
// #define SMOOTHING_STRENGTH_MOD 1f
// #define EDGE_THRESHOLD_MOD 0.35
// #define THRESHOLD 0.05
// #define SMOOTHING_SATURATION_DIVISOR_FLOOR 0.01
// #define SMOOTHING_MAX_ITERATIONS 15
// #define SMOOTHING_LUMA_WEIGHTS float3(0.299, 0.587, 0.114)
// #define SMOOTHING_BUFFER_RCP_HEIGHT BUFFER_RCP_HEIGHT
// #define SMOOTHING_BUFFER_RCP_WIDTH BUFFER_RCP_WIDTH
// #define SMOOTHING_DEBUG false

// #define SmoothingTexture2D(tex) sampler tex

namespace BeanSmoothing
{
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
  float3 smooth(float2 texcoord, float4 offset, SmoothingTexture2D(colorTex), SmoothingTexture2D(blendSampler), float threshold) : SV_Target
  {
    const float3 debugColorNoHits = float3(0.0, 0.0, 0.0);
    const float3 debugColorSmallHit = float3(0.0, 0.0, 1.0);
    const float3 debugColorBigHit = float3(1.0, 0.0, 0.0);

    float3 mid = SMAASampleLevelZero(colorTex, texcoord).rgb;
    float3 original = mid;

    float lumaM = Color::luma(mid);
    float chromaM = saturation(mid);
    bool useluma = lumaM > chromaM;
    if (!useluma)
      lumaM = 0.0;

    float lumaS = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(0, 1)).rgb, useluma);
    float lumaE = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(1, 0)).rgb, useluma);
    float lumaN = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(0, -1)).rgb, useluma);
    float lumaW = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(-1, 0)).rgb, useluma);

    float rangeMax = Functions::max(lumaS, lumaE, lumaN, lumaW, lumaM);
    float rangeMin = Functions::min(lumaS, lumaE, lumaN, lumaW, lumaM);

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
      return original;
    }
    // If debug, early return. Return hit colors to signify that smoothing takes place here
    if (SMOOTHING_DEBUG)
    {
      // The further the range is above the threshold, the bigger the "hit"
      float strength = smoothstep(threshold, 1.0, range);
      return lerp(debugColorSmallHit, debugColorBigHit, strength);
    }

    float lumaNW = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(-1, -1)).rgb, useluma);
    float lumaSE = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(1, 1)).rgb, useluma);
    float lumaNE = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(1, -1)).rgb, useluma);
    float lumaSW = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(-1, 1)).rgb, useluma);

    // These vals serve as caches, so they can be used later without having to redo them
    // It's just an optimisation thing, though the difference it makes is so small it could just be statistical noise.
    float lumaNWSW = lumaNW + lumaSW;
    float lumaNS = lumaN + lumaS;
    float lumaNESE = lumaNE + lumaSE;
    float lumaSWSE = lumaSW + lumaSE;
    float lumaWE = lumaW + lumaE;
    float lumaNWNE = lumaNW + lumaNE;

    bool horzSpan = (abs(mad(-2.0, lumaW, lumaNWSW)) + mad(2.0, abs(mad(-2.0, lumaM, lumaNS)), abs(mad(-2.0, lumaE, lumaNESE)))) >= (abs(mad(-2.0, lumaS, lumaSWSE)) + mad(2.0, abs(mad(-2.0, lumaM, lumaWE)), abs(mad(-2.0, lumaN, lumaNWNE))));
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

    float2 lumaNP = float2(lumaN, lumaS);
    SMAAMovc(bool(!horzSpan).xx, lumaNP, float2(lumaW, lumaE));

    float gradientN = lumaNP.x - lumaM;
    float gradientS = lumaNP.y - lumaM;
    float lumaNN = lumaNP.x + lumaM;

    if (abs(gradientN) >= abs(gradientS))
      lengthSign = -lengthSign;
    else
      lumaNN = lumaNP.y + lumaM;

    float2 posB = texcoord;

    float texelsize = 0.5;

    float2 offNP = float2(0.0, SMOOTHING_BUFFER_RCP_HEIGHT * texelsize);
    SMAAMovc(bool(horzSpan).xx, offNP, float2(SMOOTHING_BUFFER_RCP_WIDTH * texelsize, 0.0));
    SMAAMovc(bool2(!horzSpan, horzSpan), posB, float2(posB.x + lengthSign / 2.0, posB.y + lengthSign / 2.0));

    float2 posN = posB - offNP;
    float2 posP = posB + offNP;

    float lumaEndN = dotweight(mid, SMAASampleLevelZero(colorTex, posN).rgb, useluma);
    float lumaEndP = dotweight(mid, SMAASampleLevelZero(colorTex, posP).rgb, useluma);

    float gradientScaled = max(abs(gradientN), abs(gradientS)) * 0.25;
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
      // scan distance
      uint maxiterations = SMOOTHING_MAX_ITERATIONS;

      [loop] while (iterations < maxiterations)
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

    // TODO: consider turning this into a preprocessor value
    maxblending = maxblending * SMOOTHING_STRENGTH_MOD;

    bool goodSpan = (dstNP.x < dstNP.y) ? ((lumaEndN < 0.0) != lumaMLTZero) : ((lumaEndP < 0.0) != lumaMLTZero);
    float pixelOffset = mad(-rcp(dstNP.y + dstNP.x), min(dstNP.x, dstNP.y), 0.5);
    float subpixOut = pixelOffset * maxblending;

    [branch] if (!goodSpan)
    {
      subpixOut = mad(mad(2.0, lumaNS + lumaWE, lumaNWSW + lumaNESE), 0.083333, -lumaM) * rcp(range);                  // ABC
      subpixOut = pow(saturate(mad(-2.0, subpixOut, 3.0) * (subpixOut * subpixOut)), 2.0) * maxblending * pixelOffset; // DEFGH
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
    SmoothingTexture2D(edgesTex),
    SmoothingTexture2D(blendSampler),
    SmoothingTexture2D(colorTex),
    out float3 color
  )
  {
    float threshold = THRESHOLD;

    // Predicate threshold based on edge data. AKA If an edge is present, lower the threshold.
    float4 edgeData;
#if __RENDERER__ >= 0xa000 // if DX10 or above
    // get edge data from the bottom (x), bottom-right (y), right (z),
    // and current pixels (w), in that order.
    float4 leftEdges = tex2Dgather(edgesTex, texcoord, 0); // TODO: make macros
    float4 topEdges = tex2Dgather(edgesTex, texcoord, 1);
    edgeData = float4(
        leftEdges.w,
        topEdges.w,
        leftEdges.z,
        topEdges.x);
#else // if DX9
    edgeData = float4(
        SMAASampleLevelZero(edgesTex, texcoord).rg,
        SMAASampleLevelZero(edgesTex, offset.xy).r,
        SMAASampleLevelZero(edgesTex, offset.zw).g);
#endif

    // If there is an edge, lower threshold by multiplying with EdgeThresholdModifier
    // Else leave uchanged by multiplying by 1.0
    bool edgePresent = any(edgeData); // TODO: check if 'any' works as expected
    threshold *= edgePresent ? EDGE_THRESHOLD_MOD : 1.0;

    color = smooth(texcoord, offset, colorTex, blendSampler, threshold);
  }
}

namespace BeanSmoothing
{
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
  float3 smooth(float2 texcoord, float4 offset, SmoothingTexture2D(colorTex), SmoothingTexture2D(blendSampler), float threshold) : SV_Target
  {
    const float3 debugColorNoHits = float3(0.0, 0.0, 0.0);
    const float3 debugColorSmallHit = float3(0.0, 0.0, 1.0);
    const float3 debugColorBigHit = float3(1.0, 0.0, 0.0);

    float3 mid = SMAASampleLevelZero(colorTex, texcoord).rgb;
    float3 original = mid;

    float lumaM = Color::luma(mid);
    float chromaM = saturation(mid);
    bool useluma = lumaM > chromaM;
    if (!useluma)
      lumaM = 0.0;

    float lumaS = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(0, 1)).rgb, useluma);
    float lumaE = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(1, 0)).rgb, useluma);
    float lumaN = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(0, -1)).rgb, useluma);
    float lumaW = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(-1, 0)).rgb, useluma);

    float rangeMax = Functions::max(lumaS, lumaE, lumaN, lumaW, lumaM);
    float rangeMin = Functions::min(lumaS, lumaE, lumaN, lumaW, lumaM);

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
      return original;
    }
    // If debug, early return. Return hit colors to signify that smoothing takes place here
    if (SMOOTHING_DEBUG)
    {
      // The further the range is above the threshold, the bigger the "hit"
      float strength = smoothstep(threshold, 1.0, range);
      return lerp(debugColorSmallHit, debugColorBigHit, strength);
    }

    float lumaNW = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(-1, -1)).rgb, useluma);
    float lumaSE = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(1, 1)).rgb, useluma);
    float lumaNE = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(1, -1)).rgb, useluma);
    float lumaSW = dotweight(mid, SMAASampleLevelZeroOffset(colorTex, texcoord, int2(-1, 1)).rgb, useluma);

    // These vals serve as caches, so they can be used later without having to redo them
    // It's just an optimisation thing, though the difference it makes is so small it could just be statistical noise.
    float lumaNWSW = lumaNW + lumaSW;
    float lumaNS = lumaN + lumaS;
    float lumaNESE = lumaNE + lumaSE;
    float lumaSWSE = lumaSW + lumaSE;
    float lumaWE = lumaW + lumaE;
    float lumaNWNE = lumaNW + lumaNE;

    bool horzSpan = (abs(mad(-2.0, lumaW, lumaNWSW)) + mad(2.0, abs(mad(-2.0, lumaM, lumaNS)), abs(mad(-2.0, lumaE, lumaNESE)))) >= (abs(mad(-2.0, lumaS, lumaSWSE)) + mad(2.0, abs(mad(-2.0, lumaM, lumaWE)), abs(mad(-2.0, lumaN, lumaNWNE))));
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

    float2 lumaNP = float2(lumaN, lumaS);
    SMAAMovc(bool(!horzSpan).xx, lumaNP, float2(lumaW, lumaE));

    float gradientN = lumaNP.x - lumaM;
    float gradientS = lumaNP.y - lumaM;
    float lumaNN = lumaNP.x + lumaM;

    if (abs(gradientN) >= abs(gradientS))
      lengthSign = -lengthSign;
    else
      lumaNN = lumaNP.y + lumaM;

    float2 posB = texcoord;

    float texelsize = 0.5;

    float2 offNP = float2(0.0, SMOOTHING_BUFFER_RCP_HEIGHT * texelsize);
    SMAAMovc(bool(horzSpan).xx, offNP, float2(SMOOTHING_BUFFER_RCP_WIDTH * texelsize, 0.0));
    SMAAMovc(bool2(!horzSpan, horzSpan), posB, float2(posB.x + lengthSign / 2.0, posB.y + lengthSign / 2.0));

    float2 posN = posB - offNP;
    float2 posP = posB + offNP;

    float lumaEndN = dotweight(mid, SMAASampleLevelZero(colorTex, posN).rgb, useluma);
    float lumaEndP = dotweight(mid, SMAASampleLevelZero(colorTex, posP).rgb, useluma);

    float gradientScaled = max(abs(gradientN), abs(gradientS)) * 0.25;
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
      // scan distance
      uint maxiterations = SMOOTHING_MAX_ITERATIONS;

      [loop] while (iterations < maxiterations)
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

    // TODO: consider turning this into a preprocessor value
    maxblending = maxblending * SMOOTHING_STRENGTH_MOD;

    bool goodSpan = (dstNP.x < dstNP.y) ? ((lumaEndN < 0.0) != lumaMLTZero) : ((lumaEndP < 0.0) != lumaMLTZero);
    float pixelOffset = mad(-rcp(dstNP.y + dstNP.x), min(dstNP.x, dstNP.y), 0.5);
    float subpixOut = pixelOffset * maxblending;

    [branch] if (!goodSpan)
    {
      subpixOut = mad(mad(2.0, lumaNS + lumaWE, lumaNWSW + lumaNESE), 0.083333, -lumaM) * rcp(range);                  // ABC
      subpixOut = pow(saturate(mad(-2.0, subpixOut, 3.0) * (subpixOut * subpixOut)), 2.0) * maxblending * pixelOffset; // DEFGH
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
    SmoothingTexture2D(edgesTex),
    SmoothingTexture2D(blendSampler),
    SmoothingTexture2D(colorTex),
    out float3 color
  )
  {
    float threshold = THRESHOLD;

    // Predicate threshold based on edge data. AKA If an edge is present, lower the threshold.
    float4 edgeData;
#if __RENDERER__ >= 0xa000 // if DX10 or above
    // get edge data from the bottom (x), bottom-right (y), right (z),
    // and current pixels (w), in that order.
    float4 leftEdges = tex2Dgather(edgesTex, texcoord, 0); // TODO: make macros
    float4 topEdges = tex2Dgather(edgesTex, texcoord, 1);
    edgeData = float4(
        leftEdges.w,
        topEdges.w,
        leftEdges.z,
        topEdges.x);
#else // if DX9
    edgeData = float4(
        SMAASampleLevelZero(edgesTex, texcoord).rg,
        SMAASampleLevelZero(edgesTex, offset.xy).r,
        SMAASampleLevelZero(edgesTex, offset.zw).g);
#endif

    // If there is an edge, lower threshold by multiplying with EdgeThresholdModifier
    // Else leave uchanged by multiplying by 1.0
    bool edgePresent = any(edgeData); // TODO: check if 'any' works as expected
    threshold *= edgePresent ? EDGE_THRESHOLD_MOD : 1.0;

    color = smooth(texcoord, offset, colorTex, blendSampler, threshold);
  }
}