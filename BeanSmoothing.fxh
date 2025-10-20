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
/**
 *                  _______  ___  ___       ___           ___
 *                 /       ||   \/   |     /   \         /   \
 *                |   (---- |  \  /  |    /  ^  \       /  ^  \
 *                 \   \    |  |\/|  |   /  /_\  \     /  /_\  \
 *              ----)   |   |  |  |  |  /  _____  \   /  _____  \
 *             |_______/    |__|  |__| /__/     \__\ /__/     \__\
 *
 *                               E N H A N C E D
 *       S U B P I X E L   M O R P H O L O G I C A L   A N T I A L I A S I N G
 *
 *                         http://www.iryoku.com/smaa/
 *
 * Copyright (C) 2013 Jorge Jimenez (jorge@iryoku.com)
 * Copyright (C) 2013 Jose I. Echevarria (joseignacioechevarria@gmail.com)
 * Copyright (C) 2013 Belen Masia (bmasia@unizar.es)
 * Copyright (C) 2013 Fernando Navarro (fernandn@microsoft.com)
 * Copyright (C) 2013 Diego Gutierrez (diegog@unizar.es)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is furnished to
 * do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software. As clarification, there
 * is no requirement that the copyright notice and permission be included in
 * binary distributions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

// MACROS
// #define SMOOTHING_SATURATION_DIVISOR_FLOOR 0.01
// #define SMOOTHING_BUFFER_RCP_HEIGHT BUFFER_RCP_HEIGHT
// #define SMOOTHING_BUFFER_RCP_WIDTH BUFFER_RCP_WIDTH
// #define SMOOTHING_DEBUG false
// #define SMOOTHING_MIN_ITERATIONS 3f
// #define SMOOTHING_MAX_ITERATIONS 15f

// Shorthands for sampling
// #define SmoothingSampleLevelZero(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
// #define SmoothingSampleLevelZeroOffset(tex, coord, offset) tex2Dlodoffset(tex, float4(coord, coord), offset)
// #define SmoothingGatherLeftDeltas(tex, coord) tex2Dgather(tex, texcoord, 0);
// #define SmoothingGatherTopDeltas(tex, coord) tex2Dgather(tex, texcoord, 1);

namespace BeanSmoothing
{
  namespace SMAA
  {
    // All code in the SMAA namespace originates from the original SMAA shader,
    // and is subject to the SMAA license included in the beginning of this file.
    /**
     * Conditional move:
     */
    void Movc(bool2 cond, inout float2 variable, float2 value)
    {
      [flatten] if (cond.x) variable.x = value.x;
      [flatten] if (cond.y) variable.y = value.y;
    }

    void Movc(bool4 cond, inout float4 variable, float4 value)
    {
      Movc(cond.xy, variable.xy, value.xy);
      Movc(cond.zw, variable.zw, value.zw);
    }
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

  // Calculate the maximum number of iterations based on the mod value that the smoothing algorithm may perform
  uint calcMaxSmoothingIterations(float mod)
  {
    return (uint)(lerp(SMOOTHING_MIN_ITERATIONS, SMOOTHING_MAX_ITERATIONS, mod) + .5);
  }

  /**
   * Algorithm called 'smoothing', found in Lordbean's TSMAA.
   * Appears to fix inconsistencies at edges by nudging pixel values towards values of nearby pixels.
   * A little gem that combines well with SMAA, but causes a significant performance hit.
   *
   * Adapted from Lordbean's TSMAA shader.
   *
   * sampler colorTex: A texture2D sampler that contains the color data to be smoothed.
   *                               Must be a gamma sampler, as this shader works only in gamma space.
   */
  float3 smooth(float2 texcoord, float4 offset, sampler colorTex, sampler blendSampler, float threshold, uint maxIterations) : SV_Target
  {
    const float3 debugColorNoHits = float3(0.0, 0.0, 0.0);
    const float3 debugColorSmallHit = float3(0.0, 0.0, 1.0);
    const float3 debugColorBigHit = float3(1.0, 0.0, 0.0);

    float3 mid = SmoothingSampleLevelZero(colorTex, texcoord).rgb;

    float lumaM = Color::luma(mid);
    float chromaM = saturation(mid);
    bool useluma = lumaM > chromaM;
    if (!useluma)
      lumaM = 0.0;

    float4 lumas; // r = west, g = north, b = east, a = south
    lumas.r = dotweight(mid, SmoothingSampleLevelZeroOffset(colorTex, texcoord, int2(-1, 0)).rgb, useluma);
    lumas.g = dotweight(mid, SmoothingSampleLevelZeroOffset(colorTex, texcoord, int2(0, -1)).rgb, useluma);
    lumas.b = dotweight(mid, SmoothingSampleLevelZeroOffset(colorTex, texcoord, int2(1, 0)).rgb, useluma);
    lumas.a = dotweight(mid, SmoothingSampleLevelZeroOffset(colorTex, texcoord, int2(0, 1)).rgb, useluma);

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
    diagLumas.r = dotweight(mid, SmoothingSampleLevelZeroOffset(colorTex, texcoord, int2(-1, -1)).rgb, useluma);
    diagLumas.g = dotweight(mid, SmoothingSampleLevelZeroOffset(colorTex, texcoord, int2(1, -1)).rgb, useluma);
    diagLumas.b = dotweight(mid, SmoothingSampleLevelZeroOffset(colorTex, texcoord, int2(1, 1)).rgb, useluma);
    diagLumas.a = dotweight(mid, SmoothingSampleLevelZeroOffset(colorTex, texcoord, int2(-1, 1)).rgb, useluma);

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
        SmoothingSampleLevelZero(blendSampler, offset.xy).a,
        SmoothingSampleLevelZero(blendSampler, offset.zw).g,
        SmoothingSampleLevelZero(blendSampler, texcoord).zx);

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
    SMAA::Movc(bool(!horzSpan).xx, lumaNP, lumas.rb);

    // x = north, y = south
    float2 gradients = abs(lumaNP - lumaM);
    float lumaNN;
    if (gradients.x >= gradients.y)
    {
      lengthSign = -lengthSign;
      lumaNN = lumaNP.x + lumaM;
    }
    else
      lumaNN = lumaNP.y + lumaM;

    float2 posB = texcoord;

    static const float texelsize = .5; // TODO: constant?

    float2 offNP = float2(0.0, SMOOTHING_BUFFER_RCP_HEIGHT * texelsize);
    SMAA::Movc(bool(horzSpan).xx, offNP, float2(SMOOTHING_BUFFER_RCP_WIDTH * texelsize, 0.0));
    SMAA::Movc(bool2(!horzSpan, horzSpan), posB, mad(.5, lengthSign, posB));

    float2 posN = posB - offNP;
    float2 posP = posB + offNP;

    float lumaEndN = dotweight(mid, SmoothingSampleLevelZero(colorTex, posN).rgb, useluma);
    float lumaEndP = dotweight(mid, SmoothingSampleLevelZero(colorTex, posP).rgb, useluma);

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
          lumaEndN = dotweight(mid, SmoothingSampleLevelZero(colorTex, posN).rgb, useluma);
          lumaEndN -= lumaNN;
          doneN = abs(lumaEndN) >= gradientScaled;
        }
        if (!doneP)
        {
          posP += offNP;
          lumaEndP = dotweight(mid, SmoothingSampleLevelZero(colorTex, posP).rgb, useluma);
          lumaEndP -= lumaNN;
          doneP = abs(lumaEndP) >= gradientScaled;
        }
        iterations++;
      }
    }

    float2 dstNP = float2(texcoord.y - posN.y, posP.y - texcoord.y);
    SMAA::Movc(bool(horzSpan).xx, dstNP, float2(texcoord.x - posN.x, posP.x - texcoord.x));

    bool goodSpan = (dstNP.x < dstNP.y) ? ((lumaEndN < 0.0) != lumaMLTZero) : ((lumaEndP < 0.0) != lumaMLTZero);
    float pixelOffset = mad(-rcp(dstNP.y + dstNP.x), min(dstNP.x, dstNP.y), 0.5) * maxblending;

    float subpixOut;
    [branch] if (!goodSpan)
    {
      subpixOut = mad(mad(2.0, vertLumas.y + horzLumas.y, vertLumas.x + vertLumas.z), 0.083333, -lumaM) / range; // ABC
      subpixOut = pow(saturate(mad(-2.0, subpixOut, 3.0) * (subpixOut * subpixOut)), 2.0) * pixelOffset;         // DEFGH
    }
    else
    {
      subpixOut = pixelOffset;
    }

    float2 posM = texcoord;
    SMAA::Movc(bool2(!horzSpan, horzSpan), posM, mad(lengthSign, subpixOut, posM));

    return SmoothingSampleLevelZero(colorTex, posM).rgb;
  }
}
