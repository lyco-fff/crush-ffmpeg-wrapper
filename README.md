# crush-ffmpeg-wrapper


**Batch Media Compressor**

A user-friendly .bat wrapper "**CRUSH**" for FFmpeg that automatically compresses videos and images directly from the command line. Everything runs 100% locally, leveraging your GPU's hardware encoding for fast, efficient processing.

**Compression Presets**

Choose from four built-in presets depending on your quality and file size needs:
• Super Compress: 10%–20% of original size (lossy)
• Balanced Compress: 50%–60% of original size (lossy — Recommended)
• Light Compress: 60%–85% of original size (lossy)
• Lossless Compress: 85%–95% of original size (lossless)

**Setup & Usage**
Prerequisite: You must download **ffmpeg-release-essentials.zip** separately from **https://www.gyan.dev/ffmpeg/builds/**
Extract **ffmpeg-release-essentials.zip** and pull out just the FFmpeg.exe file.

1. Download the .bat file (Compressor_H264.bat).
2. Place both the FFmpeg.exe and the Compressor_H264 file into the folder containing the media you want to compress.
3. Double click the .bat file and allow it to Run as administrator (administrator privileges are required).
4. Follow the on-screen prompts in the command window to select your preset and start the process.
5. Once finished, your compressed files will be saved in a new folder named "compressed" inside your target directory.

If at any point you wish to stop the compression, simply close the command window. Your compression speeds will also depend on your GPU since it runs completely locally. While in use, you should probably avoid running anything alongside it that will eat up VRAM.

DISCLAIMER: I built this tool for personal use, and since I am the only real-world tester, YOU may run into unforeseen edge cases before I do. For example, I've only used this for video files (Ex. .mp4 , .mov , .m4v), though it should work for other file types too. If you find a bug, please email me at peppereddd@gmail.com with the steps to reproduce the issue so I can test it and push a fix. 
