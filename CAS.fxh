//_____________________________________________________________/\_______________________________________________________________
//==============================================================================================================================
//
//                                 [CAS] FIDELITY FX - CONSTRAST ADAPTIVE SHARPENING 1.20190610
//
//==============================================================================================================================
// LICENSE
// =======
// Copyright (c) 2017-2019 Advanced Micro Devices, Inc. All rights reserved.
// -------
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// -------
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
// -------
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//==============================================================================================================================

// DEPENDENCIES
// This shader needs:
// - Functions.fxh

// MACROS
// #define CAS_BETTER_DIAGONALS
//
// examples
// #define CAS_BETTER_DIAGONALS 1

namespace CAS {
  void CasSetup(
      // out uint const1,
      out float const1,
      float sharpness // 0 := default (lower ringing), 1 := maximum (higest ringing)
  )
  {
    // Sharpness value
    const1 = -rcp(8f - 3f * sharpness);
  }

  void CasFilter(
      float2 texcoord,
      float const1,
      sampler colorLinearSampler,
      out float3 pix
  )
  {
    // a b c
    // d e f
    // g h i
    float3 a = tex2Doffset(colorLinearSampler, texcoord, float2(-1, -1));
    float3 b = tex2Doffset(colorLinearSampler, texcoord, float2(0, -1));
    float3 c = tex2Doffset(colorLinearSampler, texcoord, float2(1, -1));
    float3 d = tex2Doffset(colorLinearSampler, texcoord, float2(-1, 0));
    float3 e = tex2D(colorLinearSampler, texcoord);
    float3 f = tex2Doffset(colorLinearSampler, texcoord, float2(1, 0));
    float3 g = tex2Doffset(colorLinearSampler, texcoord, float2(-1, 1));
    float3 h = tex2Doffset(colorLinearSampler, texcoord, float2(0, 1));
    float3 i = tex2Doffset(colorLinearSampler, texcoord, float2(1, 1));

    // Soft min and max.
    //  a b c             b
    //  d e f * 0.5  +  d e f * 0.5
    //  g h i             h
    // These are 2.0x bigger (factored out the extra multiply)
    float3 mn = Functions::min(d, e, f, b, h);

    #if CAS_BETTER_DIAGONALS
      float3 mn2 = Functions::min(mn, a, c, g, i);
      mn = mn + mn2;
    #endif

    float3 mx = Functions::max(d, e, f, b, h);

    #if CAS_BETTER_DIAGONALS
      float3 mx2 = Functions::max(mx, a, c, g, i);
      mx = mx + mx2;
    #endif

    // Smooth minimum distance to signal limit divided by smooth max
    float3 rcpM = rcp(mx);

    #if CAS_BETTER_DIAGONALS
      float3 amp = saturate(min(mn, 2f - mx) * rcpM);
    #else
      float3 amp = saturate(min(mn, 1f - mx) * rcpM);
    #endif

    // Shaping amount of sharpening
    amp = sqrt(amp);

    // Filter shape.
    //  0 w 0
    //  w 1 w
    //  0 w 0
    float peak = const1;
    float3 w = amp * peak;
    // Filter
    float3 rcpWeight = rcp(1f + 4f * w);
    pix = saturate(((b + d + f + h) * w + e) * rcpWeight);
  }

  // Generic PS
  void CASPS(
      float2 texcoord, // Integer pixel position in output.
      sampler colorLinearSampler,
      out float3 pix
  )
  {
    float const1;
    CasSetup(const1, 1f);
    CasFilter(texcoord, const1, colorLinearSampler, pix);
  }
}
