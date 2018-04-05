#!/bin/bash -e

function finish
{
  rm -rf "$tmpdir"
}
trap finish EXIT

tmpdir=$(mktemp -d)

if [ "$#" -lt 1 ]; then
  echo "Use: $0 path/to/video.mp4"
  exit
fi

tmpdir=$(mktemp -d)

concat_str="concat:"

processed_first_arg=false
for i; do
  mkfifo "$tmpdir/$i.tmp"
  ffmpeg -hide_banner -y -i "$i" -c copy -bsf:v h264_mp4toannexb -f mpegts "$tmpdir/$i.tmp" 2>/dev/null &
  if [ "$processed_first_arg" = true ]; then
    concat_str+="|"
  fi
    concat_str+="$tmpdir/$i.tmp"
    processed_first_arg=true
done

ffmpeg -hide_banner -f mpegts -i "$concat_str" -c copy -bsf:a aac_adtstoasc output.mp4