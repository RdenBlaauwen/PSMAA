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

static void CasSetup(
    // out uint const1,
    out float const1,
    float sharpness // 0 := default (lower ringing), 1 := maximum (higest ringing)
)
{
  // float sharp = -rcp(lerp(8.0, 5.0, saturate(sharpness)));
  // const1 = AU1_AF1(sharp);

  // Sharpness value
  const1 = -rcp(lerp(8f, 5f, saturate(sharpness)));
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//_____________________________________________________________/\_______________________________________________________________
//==============================================================================================================================
//                                                     NON-PACKED VERSION
//==============================================================================================================================
void CasFilter(
    out float3 pix, // Output values, non-vector so port between CasFilter() and CasFilterH() is easy.
    AU2 ip,         // Integer pixel position in output.
    // AU4 const1,
    float const1)
{
  // Debug a checker pattern of on/off tiles for visual inspection.
  // #ifdef CAS_DEBUG_CHECKER
  //   if ((((ip.x ^ ip.y) >> 8u) & 1u) == 0u)
  //   {
  //     float3 pix0 = CasLoad(ASU2(ip));
  //     pixR = pix0.r;
  //     pixG = pix0.g;
  //     pixB = pix0.b;
  //     return;
  //   }
  // #endif
  // a b c
  // d e f
  // g h i
  ASU2 sp = ASU2(ip);
  float3 a = CasLoad(sp + ASU2(-1, -1));
  float3 b = CasLoad(sp + ASU2(0, -1));
  float3 c = CasLoad(sp + ASU2(1, -1));
  float3 d = CasLoad(sp + ASU2(-1, 0));
  float3 e = CasLoad(sp);
  float3 f = CasLoad(sp + ASU2(1, 0));
  float3 g = CasLoad(sp + ASU2(-1, 1));
  float3 h = CasLoad(sp + ASU2(0, 1));
  float3 i = CasLoad(sp + ASU2(1, 1));

  // Soft min and max.
  //  a b c             b
  //  d e f * 0.5  +  d e f * 0.5
  //  g h i             h
  // These are 2.0x bigger (factored out the extra multiply)
  float3 mn = Functions::min(d, e, f, b, h);
  float3 mn2 = Functions::min(mn, a, c, g, i);
  mn = mn + mn2;

  float3 mx = Functions::max(d, e, f, b, h);
  float3 mx2 = Functions::max(mx, a, c, g, i);
  mx = mx + mx2;

  // Smooth minimum distance to signal limit divided by smooth max
  float3 rcpM = rcp(mx);

  float3 amp = sat(min(mn, 2f - mx) * rcpM);

  // Shaping amount of sharpening
  amp = sqrt(amp);

  // Filter shape.
  //  0 w 0
  //  w 1 w
  //  0 w 0
  // float peak = AF1_AU1(const1.x);
  float peak = const1;
  float3 w = amp * peak;
  // Filter
  float3 rcpWeight = rcp(1f + 4f * w);
  pix = sat((b * w + d * w + f * w + h * w + e) * rcpWeight);
}
