//==============================================================================================================================
// Call to setup required constant values (works on CPU or GPU).
A_STATIC void CasSetup(
    outAU4 const1,
    AF1 sharpness, // 0 := default (lower ringing), 1 := maximum (higest ringing)
    AF1 inputSizeInPixelsX,
    AF1 inputSizeInPixelsY,
    AF1 outputSizeInPixelsX,
    AF1 outputSizeInPixelsY)
{
  // Sharpness value.
  AF1 sharp = -ARcpF1(ALerpF1(8.0, 5.0, ASatF1(sharpness)));
  varAF2(hSharp) = initAF2(sharp, 0.0);
  const1[0] = AU1_AF1(sharp);
  const1[1] = AU1_AH2_AF2(hSharp);
  const1[2] = AU1_AF1(AF1_(8.0) * inputSizeInPixelsX * ARcpF1(outputSizeInPixelsX));
  const1[3] = 0;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//_____________________________________________________________/\_______________________________________________________________
//==============================================================================================================================
//                                                     NON-PACKED VERSION
//==============================================================================================================================
#ifdef A_GPU
#ifdef CAS_PACKED_ONLY
// Avoid compiler error.
AF3 CasLoad(ASU2 p) { return AF3(0.0, 0.0, 0.0); }
void CasInput(inout AF1 r, inout AF1 g, inout AF1 b) {}
#endif
//------------------------------------------------------------------------------------------------------------------------------
void CasFilter(
    out AF1 pixR, // Output values, non-vector so port between CasFilter() and CasFilterH() is easy.
    out AF1 pixG,
    out AF1 pixB,
    AU2 ip, // Integer pixel position in output.
    AU4 const1,
    AP1 noScaling)
{ // Must be a compile-time literal value, true = sharpen only (no resize).
  //------------------------------------------------------------------------------------------------------------------------------
  // Debug a checker pattern of on/off tiles for visual inspection.
#ifdef CAS_DEBUG_CHECKER
  if ((((ip.x ^ ip.y) >> 8u) & 1u) == 0u)
  {
    AF3 pix0 = CasLoad(ASU2(ip));
    pixR = pix0.r;
    pixG = pix0.g;
    pixB = pix0.b;
    CasInput(pixR, pixG, pixB);
    return;
  }
#endif
  // a b c
  // d e f
  // g h i
  ASU2 sp = ASU2(ip);
  AF3 a = CasLoad(sp + ASU2(-1, -1));
  AF3 b = CasLoad(sp + ASU2(0, -1));
  AF3 c = CasLoad(sp + ASU2(1, -1));
  AF3 d = CasLoad(sp + ASU2(-1, 0));
  AF3 e = CasLoad(sp);
  AF3 f = CasLoad(sp + ASU2(1, 0));
  AF3 g = CasLoad(sp + ASU2(-1, 1));
  AF3 h = CasLoad(sp + ASU2(0, 1));
  AF3 i = CasLoad(sp + ASU2(1, 1));
  // Run optional input transform.
  CasInput(a.r, a.g, a.b);
  CasInput(b.r, b.g, b.b);
  CasInput(c.r, c.g, c.b);
  CasInput(d.r, d.g, d.b);
  CasInput(e.r, e.g, e.b);
  CasInput(f.r, f.g, f.b);
  CasInput(g.r, g.g, g.b);
  CasInput(h.r, h.g, h.b);
  CasInput(i.r, i.g, i.b);
  // Soft min and max.
  //  a b c             b
  //  d e f * 0.5  +  d e f * 0.5
  //  g h i             h
  // These are 2.0x bigger (factored out the extra multiply).
  AF1 mnR = AMin3F1(AMin3F1(d.r, e.r, f.r), b.r, h.r);
  AF1 mnG = AMin3F1(AMin3F1(d.g, e.g, f.g), b.g, h.g);
  AF1 mnB = AMin3F1(AMin3F1(d.b, e.b, f.b), b.b, h.b);

  AF1 mnR2 = AMin3F1(AMin3F1(mnR, a.r, c.r), g.r, i.r);
  AF1 mnG2 = AMin3F1(AMin3F1(mnG, a.g, c.g), g.g, i.g);
  AF1 mnB2 = AMin3F1(AMin3F1(mnB, a.b, c.b), g.b, i.b);
  mnR = mnR + mnR2;
  mnG = mnG + mnG2;
  mnB = mnB + mnB2;

  AF1 mxR = AMax3F1(AMax3F1(d.r, e.r, f.r), b.r, h.r);
  AF1 mxG = AMax3F1(AMax3F1(d.g, e.g, f.g), b.g, h.g);
  AF1 mxB = AMax3F1(AMax3F1(d.b, e.b, f.b), b.b, h.b);

  AF1 mxR2 = AMax3F1(AMax3F1(mxR, a.r, c.r), g.r, i.r);
  AF1 mxG2 = AMax3F1(AMax3F1(mxG, a.g, c.g), g.g, i.g);
  AF1 mxB2 = AMax3F1(AMax3F1(mxB, a.b, c.b), g.b, i.b);
  mxR = mxR + mxR2;
  mxG = mxG + mxG2;
  mxB = mxB + mxB2;

  // Smooth minimum distance to signal limit divided by smooth max.
  AF1 rcpMR = ARcpF1(mxR);
  AF1 rcpMG = ARcpF1(mxG);
  AF1 rcpMB = ARcpF1(mxB);

  AF1 ampR = ASatF1(min(mnR, AF1_(2.0) - mxR) * rcpMR);
  AF1 ampG = ASatF1(min(mnG, AF1_(2.0) - mxG) * rcpMG);
  AF1 ampB = ASatF1(min(mnB, AF1_(2.0) - mxB) * rcpMB);

  AF1 ampR = ASatF1(min(mnR, AF1_(1.0) - mxR) * rcpMR);
  AF1 ampG = ASatF1(min(mnG, AF1_(1.0) - mxG) * rcpMG);
  AF1 ampB = ASatF1(min(mnB, AF1_(1.0) - mxB) * rcpMB);

  // Shaping amount of sharpening.
  ampR = sqrt(ampR);
  ampG = sqrt(ampG);
  ampB = sqrt(ampB);
  // Filter shape.
  //  0 w 0
  //  w 1 w
  //  0 w 0
  AF1 peak = AF1_AU1(const1.x);
  AF1 wR = ampR * peak;
  AF1 wG = ampG * peak;
  AF1 wB = ampB * peak;
  // Filter.
  AF1 rcpWeightR = ARcpF1(AF1_(1.0) + AF1_(4.0) * wR);
  AF1 rcpWeightG = ARcpF1(AF1_(1.0) + AF1_(4.0) * wG);
  AF1 rcpWeightB = ARcpF1(AF1_(1.0) + AF1_(4.0) * wB);
  pixR = ASatF1((b.r * wR + d.r * wR + f.r * wR + h.r * wR + e.r) * rcpWeightR);
  pixG = ASatF1((b.g * wG + d.g * wG + f.g * wG + h.g * wG + e.g) * rcpWeightG);
  pixB = ASatF1((b.b * wB + d.b * wB + f.b * wB + h.b * wB + e.b) * rcpWeightB);
}
#endif
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//_____________________________________________________________/\_______________________________________________________________
//==============================================================================================================================
//                                                       PACKED VERSION
//==============================================================================================================================
#if defined(A_GPU) && defined(A_HALF)
// Missing a way to do packed re-interpetation, so must disable approximation optimizations.
#ifdef A_HLSL
#ifndef CAS_GO_SLOWER
#define CAS_GO_SLOWER 1
#endif
#endif
//==============================================================================================================================
// Can be used to convert from packed SOA to AOS for store.
void CasDepack(out AH4 pix0, out AH4 pix1, AH2 pixR, AH2 pixG, AH2 pixB)
{
#ifdef A_HLSL
  // Invoke a slower path for DX only, since it won't allow uninitialized values.
  pix0.a = pix1.a = 0.0;
#endif
  pix0.rgb = AH3(pixR.x, pixG.x, pixB.x);
  pix1.rgb = AH3(pixR.y, pixG.y, pixB.y);
}
//==============================================================================================================================
