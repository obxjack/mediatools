#!/bin/bash

wrkdir=$PWD
converteddir="/Volumes/BigDisk/Converted"

tmpjson="/Volumes/BigDisk/tmp/remove-audio.json"

	echo "=========================================================================================="

	OIFS="$IFS" ## needed for spaces in filenames 
	IFS=$'\n'


	#  Variable to keep a count of the number of files processed
	((processed=0))

	# Let's loop through the current directory and process all files
	for x in $(ls -1 ${wrkdir}); do # | sed 's/\.[a-z]*//g'); do
		#wrkfname="${wrkdir}/${x}"
		wrkfname=$x
		# Using ffprobe to pull details of the streams in the video file
		ffprobe -i "${wrkfname}" -v quiet -print_format json -show_streams -show_private_data > $tmpjson
		
		found=0
		codec_type="dummy"
		((streamcount=0))
		((audiostreams=0))
		audioidx=()
		
		until [ $codec_type == "null" ]; do
			codec_type=$(cat $tmpjson | jq -r --argjson count "$streamcount" '.streams | .[$count] | .codec_type')
			
			if [[ $codec_type == "video" ]]; then
				videoidx=$streamcount
			fi
			
			if [[ ${codec_type} == "audio" ]]; then
				# I found an audio stream -- checking if this stream is English audio
				((audiostreams++))
				language=$(cat $tmpjson | jq -r --argjson count "$streamcount" '.streams | .[$count] | .tags.language')

				if [[ ${language} == "eng" ]]; then
					# I found an audio stream -- adding to audioidx array

					audioidx+=($streamcount)
				fi
			fi
			
			((streamcount++))
		done
				
		if [[ $audiostreams -gt 1 ]]; then
			# I found a video with more than one audio stream -- time to remove non-english audio

			filesize=$(stat -f%z "$wrkfname")
			((processed++))
			#outfname="`basename ${wkrfname}`"

			echo "Input  File     : ${wrkfname}"
			echo "Output File     : ${converteddir}/${wrkfname}"
			echo "Source Filesize : ${filesize}"
			echo "Video Index     : ${videoidx}"
			echo "Audio Index     : ${audioidx[@]}"
			echo "Audio Index     : ${audioidx[0]}"
			ffmpeg -hide_banner -loglevel quiet -i $wrkfname -map 0:${videoidx} -map 0:${audioidx[0]} -vcodec copy -acodec copy "${converteddir}/${wrkfname}"
			
			filesize=$(stat -f%z "${converteddir}/${wrkfname}")
			echo "Output Filesize : ${filesize}"
			echo "==============="
		fi
		datevar=$(date +'%d-%b-%Y %H:%M:%S')
	done
	echo "Videos Processed: ${processed}"

	IFS="$OIFS" # Done with this guy