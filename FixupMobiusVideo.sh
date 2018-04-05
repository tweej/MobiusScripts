#!/bin/bash -e

# Mobius Action Cam 2 videos have audio streams that are longer than the video streams.
# This script demuxes the video, truncates the audio stream to the length of the video stream, and then remuxes the streams to allow for glitch-free video concatenation without encoding.

function finish
{
  rm -rf "$tmpdir"
}
trap finish EXIT

if [ "$#" -lt 1 ]; then
  echo "Use: $0 path/to/video.mp4 [path/to/video2.mp4] ..."
  exit
fi

for arg; do
  tmpdir=$(mktemp -d)

  # Demux the video
  ffmpeg -hide_banner -i "$arg" -c:v copy -map 0:0 "$tmpdir/video.m4v" -c:a copy -map 0:1 "$tmpdir/audio.m4a"

  # Get video duration
  video_duration_in_sec=$(ffprobe -hide_banner -i "$tmpdir/video.m4v" -show_streams|grep duration=|cut -f2 -d=)

  # Truncate audio to video duration
  # This will cut the audio to the closest boundary to the time specified, but may be up to a frame length past it.
  ffmpeg -hide_banner -i "$tmpdir/audio.m4a" -t $video_duration_in_sec -c:a copy "$tmpdir/audio_trunc.m4a"

  # If the audio duration is still longer than the video duration, remove the last frame from the audio
  audio_trunc_duration_in_sec=$(ffprobe -hide_banner -i "$tmpdir/audio_trunc.m4a" -show_streams|grep duration=|cut -f2 -d=)
  if [[ "$audio_trunc_duration_in_sec" > "$video_duration_in_sec" ]]; then
    echo "Still need to remove a frame"
    audio_trunc_frames=$(ffprobe -hide_banner -i "$tmpdir/audio_trunc.m4a" -show_streams|grep nb_frames|cut -f2 -d=)
    target_frame_count=$(echo $(( audio_trunc_frames - 1 )))
    target_audio_duration=$(bc -l <<< $audio_trunc_duration_in_sec*$target_frame_count/$audio_trunc_frames)
    ffmpeg -hide_banner -y -i "$tmpdir/audio.m4a" -t $target_audio_duration -c:a copy "$tmpdir/audio_trunc.m4a"
  fi

  ffmpeg -i "$tmpdir/video.m4v" -i "$tmpdir/audio_trunc.m4a" -c:v copy -c:a copy "$(echo "$arg"|sed 's,\(.*\)\.\([^\.]*\),\1_FIXED.\2,g')"
done
