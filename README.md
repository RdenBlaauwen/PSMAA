PSMAA (Progressive Subpixel Morphological Anti Aliasing) is a variation on SMAA 1x which aims to push the technique to the limits of what it can do.

**Note:** This shader is still in beta. It is *mostly* feature complete, but it still needs optimisations, a user-friendly UI and some polishing. It's in a usable state, but it's not yet in its final form.

# Image comparison

The following examples show how PSMAA performs versus SMAA at fairly aggressive settings:

- Fine details: ImgSlider | [Diffchecker](https://www.diffchecker.com/image-compare/ApOWef9k/)
- Low-contrast environment: ImgSlider | [Diffchecker](https://www.diffchecker.com/image-compare/TjwS6MAg/)
- Foliage: ImgSlider | [Diffchecker](https://www.diffchecker.com/image-compare/oA11GJVr/)

For those who prefer more conservative AA, here are examples with light smoothing and filtering, and no sharpening:

- Versus SMAA: ImgSlider | Diffchecker
- Versus aggressive settings: ImgSlider | Diffchecker

# Features

Compared to SMAA 1x, PSMAA has the following additions and improvements:
- It fixes the issue of SMAA not detecting and eliminating jaggies in low-contrast areas. It also no longer needs access to the depth buffer to improve detection, which makes it usable in a wider variety of games.
- It mitigates or eliminates various aliasing artifacts which SMAA mostly leaves untouched.
- It is slightly less prone to artifacting.

It also has some optional functions:
- Make the jaggies even smoother than normal SMAA, but at the cost of image sharpness.
- A specially integrated sharpening pass, which can sharpen the image without bringing back jaggies and pixelation. It can also sharpen heavily blended pixels more.

# Installation

Downloading the latest release is recommended. Make sure you have a (preferably dedicated) folder for my shaders in the <>, then dump the release's contents into it.

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
