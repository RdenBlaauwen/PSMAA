# TODO

- Smoothing:
  - Replace hard threshold with a smoothstepped threshold where everything between the lower and upper bounds has a lower maxblending and nr of iterations than everything >= the upper bound.
  - Make depth-based threshold growth and usage of SMAA weights, optional in both the module and PSMAA.
- Filtering:
  - Test functionality where pixels neighbouring pixels with high filter strengths are also treated. Helps preserve detail, but at a higher perf cost.
  - Come up with way to improve luma preservation
    - artificial boost with some saturation control?
    - LordBean's hysteresis?
    - Something that takes the original pixel luma into consideration?
  - Test if returning a float3 without explicit alpha passthrough overwrites the original alpha or not, and if it even matters or you can just use gathers.
- Sharpening:
  - optimise texel sampling of CasWrapper()
- Update libraries:
  - Build solution for calculating luminosity from color, and weighting components for luma in shared library.
  - make standard 'nullish' function check for vals close, but not equal, to 0.
    - Use the discard in PSMAA.fxh's Smoothing pass to figure out what it should be for a given input type.
- Find a way to prevent smoothing on texels with low-ish deltas but high-ish neighbouring deltas to prevent blur en performance overhead.
- Implement new contrast adaptation system which arranges local deltas into "shapes" just like in "Bean softening".
  - needs more than jsut the basic 4 circumferential deltas to work.
  - if good shapes "win": number will be > 0.
  - if bad shapes "win": number will be < 0.
  - Can be used for both pre-processing's edge detection and the normal one, though both will need differetn shapes, and different of the result.
- Turn alpha passthrough on by default, or come up with better solution.
- Replace maxLocalLuma by avgLocalLuma and test the difference.
- Test performance difference between edge detection (with CMAA2's local contrast adaptation) when delta pass is used vs when it is calculated directly.
- Consider adding modifier to delta deetction which boosts luma weights, just like in Marty's SMAA:
  - `dot(abs(A - B), float3(0.229, 0.587, 0.114) * 1.33);`
- Test difference between `SMAASampleLevelZeroOffset` and `SMAASampleOffset`
- Test perf difference between using Offset sample methods (LordBean) vs using pre-calculated offsets calculated in a VS (native SMAA)
- Try to optimise delta calculation's colorfulness min and max calculation to use 3 float2 calcs instead of 4 float calcs.
  - every float2 contains a component from both colors, instead of processing separately.

# Testing

## sRGB textures

Only RGBA8 textures can be written to using sRGB passes. And only RGBA8 textures can be used in sRGB (aka linear) samplers. And the backbuffer of course.

I originally wanted to use RGB10A2 textures for the filtered copies, but after seeing the blending pass wouldn't be able to write to them or samples from them, I decided to let that go and settle for RGBA8.

I tried to make a workaround by sampling with a normal sampler and then correcting to linear space manually. But that didn't work at all.

Alternatively I could just add extra passes before and after the blending let all three of them write to and read from one or two zwischen passes or the backbuffer, buf that would've come with a lot of overhead and extram complexity. RGBA8 seems like the best solution.

## Separate delta calc vs unified edge calc

Testing reveals very few differences when using a separate delta and edge calculation pass vs using a more conventional unified edge calc pass. It is however slightly inferior, with a few missing edges so here and there in the resulting buffer.

Slightly raising the SMAA Local contrast adaptation factor (by .1f) and lowering the threshold (by .01f) compensates for these issues, but also creates other issues.

This result may be acceptable, provided using depth edges in the delta pass combined with the soon to be introduced contrast adaptation from CMAA2 actually improves image quality.

## using 8 bit delta buffer instead of 16 it

### fit half in RG8

Tried seeing how many detlas would go above a value of 1/2 using a quickly built debug option. Turns out it's quite a bit, and some of the most important deltas too. This dashed my hopes of using an RG8 buffer, doubling all deltas before putting them in the buffer, and the halving them again after sampling.

### Just use RG8

Fortunately, it wasn't necessary. Testing showed that just using an RG8 buffer, without any hoops and special cramming methods, produced a virtually indistinguishable result from using RG16f. So I'm just using RG8 from now on.

### Have the blending pass sample the filteredcopy instead of the backbuffer.

This way you can delete the extra output pass after the precprocessing pass and you may turn the blending pass into a computeshader too.

This doesn't work. filteredcopy is in gamma space and needs to stay that way for edge detection to work. the blending pass is in linear space and has to stay that way for the blending to work. No solution to this.

## Smoothing in color space vs gamma space

Running smoothing in color space kinda works, but causes it to no longer make edges which have already been blended by SMAA, smoother. It also causes some random artifacts along some edges. I supposed the algo really has been made to run in gamma, and fixing this is above my paygrade. For now I just created the option to switch betwene color and gamma, depending on preferences.

## Luma preservation in Smoothing

Tried to adjsut the result of smoothing pass according to the change in luma such that e.g. if the luma of the original pixel is 1.2x higher than that of the result, the result is multiplied by 1.2. But this just completely undid the results of the smoothing pass, so I gave up on this approach.
