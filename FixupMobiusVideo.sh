#!/bin/bash -e

# Mobius Action Cam 2 videos have audio streams that are longer than the video streams.
# The audio streams are the correct length. The presentation time stamps on the video streams
# are incorrect. This script re-muxes the video after discarding the original presentation
# time stamps, and has the muxer generate new ones based on a scaled video frame rate.

if [ "$#" -lt 1 ]; then
  echo "Use: $0 path/to/video.mp4 [path/to/video2.mp4] ..."
  exit
fi

for arg; do
  video_duration_in_frames=$(ffprobe -hide_banner -i "$arg" -show_streams -select_streams v|grep nb_frames=|cut -f2 -d=)
  audio_duration_in_sec=$(ffprobe -hide_banner -i "$arg" -show_streams -select_streams a|grep duration=|cut -f2 -d=)

  new_frame_rate=$(bc -l <<< "$video_duration_in_frames/$audio_duration_in_sec")

  ffmpeg -i "$arg" -r $new_frame_rate -codec copy -vsync drop "$(echo "$arg"|sed 's,\(.*\)\.\([^\.]*\),\1_FIXED.\2,g')"
done
