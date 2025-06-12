#!/bin/bash
cd "FocusAI/FocusAI/Assets.xcassets/AppIcon.appiconset"

# Resize 16x16 icons
sips -z 16 16 icon_16x16.png
sips -z 32 32 icon_16x16@2x.png

# Resize 32x32 icons
sips -z 32 32 icon_32x32.png
sips -z 64 64 icon_32x32@2x.png

# Resize 128x128 icons
sips -z 128 128 icon_128x128.png
sips -z 256 256 icon_128x128@2x.png

# Resize 256x256 icons
sips -z 256 256 icon_256x256.png
sips -z 512 512 icon_256x256@2x.png

# Resize 512x512 icons
sips -z 512 512 icon_512x512.png
sips -z 1024 1024 icon_512x512@2x.png 