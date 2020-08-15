#!/bin/bash

##############################################################
## Loops through the current directory and using ffprobe    ##
## identifies which stream(s) have a language type of       ##
## English. We then use ffmpeg to copy only the video       ##
## and the English audio streams to the converted directory ##
##############################################################
	wrkdir=$PWD
	converteddir=$(cat `dirname ${0}`/config.json | jq -r '.converteddir')
	tmpjson=$(cat `dirname ${0}`/config.json | jq -r '.tmpjson')

	OIFS="$IFS" ## needed for spaces in filenames 
	IFS=$'\n'

	# Variable to keep a count of the number of files processed
	((processed=0))

	# Let's loop through the current directory and process all files
#	for x in $(ls -1 ${wrkdir}); do
	for x in $(find $wrkdir -type f | grep -v ".DS_Store"); do
		wrkfname=$x

		# Use ffprobe to pull details of the streams in the video file
		ffprobe -i "${wrkfname}" -v quiet -print_format json -show_streams -show_private_data > $tmpjson
		
		found=0
		codec_type="dummy"
		((streamcount=0))
		((audiostreams=0))
		audioidx=()
		filesize=$(stat -f%z "$wrkfname")

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
					# I found an english audio stream -- adding to audioidx array

					audioidx+=($streamcount)
				fi
			fi
			
			((streamcount++))
		done
				
		if [[ $audiostreams -gt 1 ]]; then
			# I found a video with more than one audio stream -- time to remove non-english audio
						
			english_streams=${#audioidx[@]}

			audio_map=""
			if [[ ${english_streams} -gt 1 && ${english_streams} != ${audiostreams} ]]; then

				for x in ${!audioidx[@]}; do
					audio_map="${audio_map} -map 0:${audioidx[x]} "
				done
				outfname="${converteddir}/`basename ${wrkfname}`"

				echo "==================================================================================================================="
				echo "Input  File     : ${wrkfname}"
				echo "Source Filesize : ${filesize}"
				echo "Output File     : ${outfname}"
				echo "Audio Map       : ${audio_map}"

				cmdline="ffmpeg -hide_banner -loglevel quiet -i \"${wrkfname}\" -map 0:${videoidx}${audio_map} -vcodec copy -acodec copy \"${outfname}\""
				
				eval $cmdline
				echo ""
				
				#ffmpeg $cmdline
				#ffmpeg -hide_banner -loglevel quiet -i $wrkfname -map 0:v:${videoidx} ${audio_map} -vcodec copy -acodec copy "${converteddir}/`basename ${wrkfname}`"
				#ffmpeg $wrkfname -map 0:${videoidx} ${audio_map} -vcodec copy -acodec copy "${outfname}"
				((processed++))

				filesize=$(stat -f%z "${converteddir}/`basename ${wrkfname}`")
				echo "Output Filesize : ${filesize}"
				echo ""

			else
				echo "==================================================================================================================="
				echo "Input  File     : ${wrkfname}"
				echo "The media file contains more than one audio streams (${audiostreams}) however all of them are English... skipping."
			fi 			
		fi
		datevar=$(date +'%d-%b-%Y %H:%M:%S')
		#echo ""
	done
	echo "Videos Processed: ${processed}"

	IFS="$OIFS" # Done with this guy