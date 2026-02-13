PSMAA (Progressive Subpixel Morphological Anti Aliasing) is a variation on SMAA 1x which aims to push the technique to the limits of what it can do.

# Features
Compared to SMAA 1x, PSMAA has the following additions and improvements:
- It fixes the issue of SMAA not detecting and eliminating jaggies in low-contrast areas. It also no longer needs access to the depth buffer to improve detection, which makes it usable in a wider variety of games.
- It mitigates or eliminates various aliasing artifacts which SMAA mostly leaves untouched.
- It is slightly less prone to artifacting.

It also has some optional functions:
- It can make the jaggies even smoother than …
- A sharpening pass, which has access to…
# Installation
Downloading the latest release is recommended. Make sure you have a (preferably dedicated) folder for my shaders in the <>, then dump the release's contents into it.

If you decide to download the PSMAA files directly from the repo, make sure to also download the contents of the [`reshade-shared`](https://github.com/RdenBlaauwen/reshade-shared) repo and put it into a folder with the name name, in the same folder which contains the PSMAA files. It should look something like:
```
reshade-shared/
PSMAA.fx
PSMAA.fxh
[What about license? readme? other unrelated files from other shaders?]
```
# Usage 
# Credits
Runs on ReShade by Crosire.

Special thanks to Lordbean for his Smoothing algorithm.
