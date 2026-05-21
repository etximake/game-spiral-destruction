# Output folder
Video clips được export vào đây bởi Godot Movie Writer.

## Cách record:
```
godot --write-movie output/clip.avi
```

## Encode sang MP4 cho Shorts:
```
ffmpeg -i output/clip.avi -vcodec libx264 -crf 18 -preset slow -vf "scale=1080:1920" output/clip_shorts.mp4
```
