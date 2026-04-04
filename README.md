PSMAA (Progressive Subpixel Morphological Anti Aliasing) is a variation on SMAA 1x which aims to push the technique to the limits of what it can do.

**Note:** This shader is still in beta. It is *mostly* feature complete, but it still needs optimisations, a user-friendly UI and some polishing. It's in a usable state, but it's not yet in its final form.

# Features

Compared to SMAA 1x, PSMAA has the following additions and improvements:
- It fixes the issue of SMAA not detecting and eliminating jaggies in low-contrast areas. It also no longer needs access to the depth buffer to improve detection, which makes it usable in a wider variety of games.
- It mitigates or eliminates various aliasing artifacts which SMAA mostly leaves untouched.
- It is slightly less prone to artifacting.

It also has some optional functions:
- Make the jaggies even smoother than normal SMAA, but at the cost of image sharpness.
- A specially integrated sharpening pass, which can sharpen the image without bringing back jaggies and pixelation. It can also sharpen heavily blended pixels more.

## Image comparison

These screenshots may give you some idea of how PSMAA performs (at fairly aggressive settings) versus SMAA. Unfortunately the comparison websites blur the screenshots so much that a lot of the details and differences are lost. So keep in mind that they don't fully represent how these AA algorithms really perform.

- Fine details:  [Diffchecker](https://www.diffchecker.com/image-compare/ApOWef9k/) | [ImgSlider](https://imgslider.com/a93a755d-ef1a-4fbb-925e-a861f704d83f)
- Low-contrast environment:  [Diffchecker](https://www.diffchecker.com/image-compare/TjwS6MAg/) | [ImgSlider](https://imgslider.com/9af4186c-7568-444d-8744-4335384c6ea5)
- Foliage: [Diffchecker](https://www.diffchecker.com/image-compare/oA11GJVr/) | [ImgSlider](https://imgslider.com/5791be1a-1862-4baa-a57f-c3522b23bdc6)


# Installation

The recommended way to install this shader is to download the latest release for this repo. Then make sure you have a (preferably dedicated) folder for my shaders in the `reshade-shaders\Shaders\` directory, and dump the release's contents into it. Also make sure you have ReShade's standard SMAA implementation installed, as PSMAA needs its `AreaTex.png` and `SearchTex.png` textures.

If you decide to download the PSMAA files directly from the repo, make sure to also download the contents of the [`reshade-shared`](https://github.com/RdenBlaauwen/reshade-shared) repo and put it into a folder with the name name, in the same folder which contains the PSMAA files. It should look something like:
```
reshade-shared/
PSMAA.fx
PSMAA.fxh
// etc...
```
# Usage 

The UI has explanations on how to configure and use the effect.

PSMAA should be applied *before* any sharpening, blur, and other effects which affect pixel morphology and clarity. I don't recommend combining it with any other forms of AA.

If the game you're using it on has sharpening, make sure to *turn it off*. Use the built-in sharpening instead, or just use a ReShade sharpening effect that you like. Same with in-game blur effects. Bloom probably won't cause issues, but if you see weird artifacts you can try turning that off too.

# Credits
Runs on ReShade by Crosire.

Special thanks to Lordbean for his Smoothing algorithm.
