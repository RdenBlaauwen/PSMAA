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

# TODO

- Test performance difference between edge detection (with CMAA2's local contrast adaptation) when delta pass is used vs when it is calculated directly.
- Consider adding modifier to delta deetction which boosts luma weights, just like in Marty's SMAA:
  - `dot(abs(A - B), float3(0.229, 0.587, 0.114) * 1.33);`
- Test difference between `SMAASampleLevelZeroOffset` and `SMAASampleOffset`
- Test perf difference between using Offset sample methods (LordBean) vs using pre-calculated offsets calculated in a VS (native SMAA)
- Try optimizing the library so that it's the max functions can be used
