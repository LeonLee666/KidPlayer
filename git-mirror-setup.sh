#!/bin/bash
git config --global url."https://github.com/videolan/dav1d".insteadOf "https://code.videolan.org/videolan/dav1d"
git config --global url."https://github.com/FFmpeg/FFmpeg".insteadOf "https://git.ffmpeg.org/ffmpeg.git"
git config --global http.postBuffer 524288000
echo "=== git 重写规则: ==="
git config --global --get-regexp insteadOf
