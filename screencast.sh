#!/bin/bash

# Original script is from http://okiebuntu.homelinux.com/blog/?p=175
# Modifications by brousch (Ben Rousch, brousch@gmail.com):
#     Upped it to 30 FPS capture
#     Added OpenShot-preferred codecs output section (mp4/mpeg4/faac)

# list of programs we depend on
progs="xdpyinfo grep head sed ffmpeg pacat parec sox"

# check for programs we depend on
result=0
for prog in $progs
do
  type -p $prog > /dev/null
  if (( $? != 0 )); then
    echo "Error: Cannot find required program '$prog'"
    result=1
  fi
done
if (( $result != 0 )); then
  exit 1
fi

screenSize="640x480" # default if we cant detect it
screenOffset="0,0" # default to top-left corner
frameRate="30" # default frame rate
baseName="capture" # default base filename for capture

# attempt to detect the dimension of the screen for the default
dimensions=`xdpyinfo | grep 'dimensions:' | head -1 | \
  sed -e 's/^.* \([0-9]\+x[0-9]\+\) pixels.*$/\1/'`
if [[ "$dimensions" =~ [0-9]+x[0-9]+ ]]; then
  screenSize=$dimensions
fi

# collect command line settings
while getopts 'hs:o:t:p' param ; do
  case $param in
    s)
      screenSize="$OPTARG"
      ;;
    o)
      screenOffset="$OPTARG"
      ;;
    t)
      timeToRecord="$OPTARG"
      ;;
    *)
      echo ""
      echo "$0 - records screencast"
      echo ""
      echo "$0 [options] [base-filename]"
      echo ""
      echo "options:"
      echo "	-h            show brief help"
      echo "	-s <size>     screensize to record as <width>x<height>"
      echo "	-o <offset>   offset off recording area as <xoffset>,<yoffset>"
      echo "	-t <time>     time to record (in seconds)"
      echo ""
      exit 0
      ;;
  esac
done

shift $(( $OPTIND - 1 ))

# determine basename of files
if [ -n "$1" ] ; then
  baseName="$1"
fi

echo ""
echo "Size = $screenSize"
echo "Offset = $screenOffset"
echo "Rate = $frameRate"
echo "Filename = $baseName"

# get ready to start recording
echo ""
if [ -n "$timeToRecord" ]; then
  echo "Preparing to capture for $timeToRecord seconds."
else
  echo "Preparing to capture."
  echo "Press ENTER when finished capturing."
fi
sleep 3
echo ""

# start playing silence to make sure there is always audio flowing
pacat /dev/zero &
pidSilence=$!

# starts recording video using x11grab to make mpeg2video
ffmpeg -y -an \
  -s "$screenSize" -r "$frameRate" -f x11grab -i :0.0+"$screenOffset" \
  -s "$screenSize" -r "$frameRate" -aspect 4:3 -vcodec mpeg2video -sameq \
  -f mpeg2video "$baseName.mpeg" &
pidVideo=$!

# starts recording raw audio
parec --format=s16le --rate=44100 --channels=2 $baseName.raw &
pidAudio=$!

echo ""
echo "Video recording started with process ID $pidVideo"
echo "Audio recording started with process ID $pidAudio"
echo ""

# wait for recording to be done, either by timer or user hitting enter
if [ -n "$timeToRecord" ]; then
  sleep "$timeToRecord"
else
  read nothing
fi

# stop recordings
echo ""
echo "Terminating recordings ..."
kill -15 $pidVideo $pidAudio 
kill -15 $pidSilence
wait

# filter and normalize the audio
echo "" 
echo "Filtering and normalizing sound ..." 
sox --norm -s -b 16 -L -r 44100 -c 2 "$baseName.raw" "$baseName.wav"  highpass 65 lowpass 12k

# encode video and audio into avi file
#echo "" 
#echo "Encoding to final avi ..." 
#ffmpeg -isync -i "$baseName.wav" -i "$baseName.mpeg" -acodec mp2 -ab 192k -vcodec copy "$baseName.avi"

# convert to ogg - to turn on uncomment next three lines
#echo""
#echo "convert to theora"
#ffmpeg2theora "$baseName.avi" -o "$baseName.ogv"

# convert avi to flv - to turn on uncomment next three lines
#echo""
#echo "convert to theora"
# ffmpeg -i "$baseNamee.avi" -ab 56 -ar 44100 -b 200 -r 15 -s 320x240 -f flv  "$baseNamee.flv"

# convert video and audio to mp4 with mpeg4 video and libfaac audio
echo ""
echo "Encoding to final mp4 with MPEG4 and FAAC ..."
ffmpeg -isync -i "$baseName.wav" -i "$baseName.mpeg" -acodec libfaac -ab 192k -vcodec mpeg4 -sameq "$baseName.mp4"

echo ""
echo "DONE! Final media written in file $baseName.mp4"

echo ""
exit 0

