#!/usr/bin/env python3
"""Generate app icon for ClashDash - matches authenticator format."""
import subprocess, os, json

OUTPUT = "/Users/linuxfish/playground/vibecoding/ClashDash/ClashDash/Assets.xcassets/AppIcon.appiconset"
SIZE = 1024
C = SIZE // 2
R = 360
cr = 32

png = os.path.join(OUTPUT, "AppIcon.png")
os.makedirs(OUTPUT, exist_ok=True)

def magick(*args):
    cmd = ["magick"] + list(args)
    subprocess.run(cmd, check=True)

import math
h1 = int(R * 0.866 - 80)
h2 = int(R * 0.5 - 60)

magick(
    "-size", f"{SIZE}x{SIZE}",
    "radial-gradient:#A0A8D0-#6A78B0-#4A5898",

    # Outer glow rings
    "(", "-size", f"{SIZE}x{SIZE}", "xc:transparent",
        "-fill", "none",
        "-stroke", "rgba(60,80,160,0.25)",
        "-strokewidth", "3",
        f"-draw", f"circle {C},{C} {C},{C-R}",
        "-stroke", "rgba(60,80,160,0.15)",
        "-strokewidth", "2",
        f"-draw", f"circle {C},{C} {C},{C-R-50}",
    ")", "-composite",

    # Connection network
    "(", "-size", f"{SIZE}x{SIZE}", "xc:transparent",
        "-fill", "none",
        "-stroke", "rgba(40,60,140,0.55)",
        "-strokewidth", "6",
        f"-draw", f"line {C},{C} {C},{C-R+80}",
        f"-draw", f"line {C},{C} {C+h1},{C+h2}",
        f"-draw", f"line {C},{C} {C+h1},{C-h2}",
        f"-draw", f"line {C},{C} {C-h1},{C+h2}",
        f"-draw", f"line {C},{C} {C-h1},{C-h2}",

        # Hexagon ring
        "-stroke", "rgba(40,60,140,0.35)",
        "-strokewidth", "4",
        f"-draw", f"line {C},{C-R+80} {C+h1},{C-h2}",
        f"-draw", f"line {C+h1},{C-h2} {C+h1},{C+h2}",
        f"-draw", f"line {C+h1},{C+h2} {C-h1},{C+h2}",
        f"-draw", f"line {C-h1},{C+h2} {C-h1},{C-h2}",
        f"-draw", f"line {C-h1},{C-h2} {C},{C-R+80}",

        # Outer nodes
        "-fill", "rgba(40,60,150,0.85)",
        "-stroke", "rgba(30,50,130,0.7)",
        "-strokewidth", "4",
        f"-draw", f"circle {C},{C-R+80} {C},{C-R+80-cr}",
        f"-draw", f"circle {C+h1},{C+h2} {C+h1},{C+h2-cr}",
        f"-draw", f"circle {C+h1},{C-h2} {C+h1},{C-h2-cr}",
        f"-draw", f"circle {C-h1},{C+h2} {C-h1},{C+h2-cr}",
        f"-draw", f"circle {C-h1},{C-h2} {C-h1},{C-h2-cr}",
    ")", "-composite",

    # Center hub
    "(", "-size", f"{SIZE}x{SIZE}", "xc:transparent",
        "-fill", "radial-gradient:rgba(50,70,160,0.35)-rgba(50,70,160,0)",
        f"-draw", f"circle {C},{C} {C},{C-220}",
        "-fill", "radial-gradient:rgba(40,60,150,0.9)-rgb(20,40,120)",
        f"-draw", f"circle {C},{C} {C},{C-85}",
        "-fill", "rgba(100,140,220,0.9)",
        f"-draw", f"circle {C},{C} {C},{C-40}",
        "-fill", "rgba(160,190,240,0.8)",
        f"-draw", f"circle {C},{C} {C},{C-16}",
    ")", "-composite",

    # DO NOT apply rounded rect mask - iOS handles this
    "-strip",
    png
)

# Use the same format as authenticator
contents = {
    "images": [
        {
            "filename": "AppIcon.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024"
        }
    ],
    "info": {"author": "xcode", "version": 1}
}

with open(os.path.join(OUTPUT, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

print(f"Generated {png} ({os.path.getsize(png)} bytes)")
print("Contents.json updated to match authenticator format")
