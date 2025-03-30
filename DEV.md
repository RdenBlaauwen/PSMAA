# Testing

## Separate delta calc vs unified edge calc

Testing reveals very few differences when using a separate delta and edge calculation pass vs using a more conventional unified edge calc pass. It is however slightly inferior, with a few missing edges so here and there in the resulting buffer.

Slightly raising the SMAA Local contrast adaptation factor (by .1f) and lowering the threshold (by .01f) compensates for these issues, but also creates other issues.

This result may be acceptable, provided using depth edges in the delta pass combined with the soon to be introduced contrast adaptation from CMAA2 actually improves image quality.

# TODO

- Implement and test newly implemented edge detection function
- Test performance difference between edge detection (with CMAA2's local contrast adaptation) when delta pass is used vs when it is calculated directly.
- Consider adding modifier to delta deetction which boosts luma weights, just like in Marty's SMAA:
  - ```dot(abs(A - B), float3(0.229, 0.587, 0.114) * 1.33);```
- optimize delta calc to use lerp
