#
# Download sound files from the Asterisk downloads site, filter out small ones, and dump them in data/
# Producing a data/sound-list.txt file that contains the file names, language, and what is said in each.
#
# Some of the transcriptions in the listings are broken, run onto multiple lines, or refer to the wrong file names.
# These will generate errors but won't stop the script from running or break the output.
#

# Define the minimum file size
# 20KB seems to be a good threshold for filtering out small/short files
MIN_FILE_SIZE=20000

# List the sound file archives we're interested in
SOUND_ARCHIVE_URLS=(
    # en
    "https://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-wav-current.tar.gz"
    "https://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-wav-current.tar.gz"
    # en-GB
    "https://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en_GB-wav-current.tar.gz"
    "https://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en_GB-wav-current.tar.gz"
    # en-AU
    "https://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en_AU-wav-current.tar.gz"
    # en-NZ
    "https://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en_NZ-wav-current.tar.gz"
)

# Create the data directory if it doesn't exist
mkdir -p data

# Remove the sound-list.txt file if it exists
rm -f data/sound-list.txt

# Download the sound files if needed
for url in "${SOUND_ARCHIVE_URLS[@]}"; do

    url_data_filename=$(basename $url)
    if [ ! -f $url_data_filename ]; then
        echo "Downloading $url"
        wget -O $url_data_filename $url
    fi

    # Extract ze file under the filename directory
    directoryname=data/${url_data_filename%.tar.gz}
    mkdir -p $directoryname
    tar -xzf $url_data_filename -C $directoryname

    name_parts=(${directoryname//-/ })
    
    # Extract the name parts
    collection=${name_parts[1]}
    language=${name_parts[3]}
    format=${name_parts[4]}

    # Process the listing file
    listingfile=$directoryname/$collection-sounds-$language.txt

    # Read each line in the listing file
    while read line; do

        # Ignore lines that begin with a comment
        if [[ $line == \;* ]]; then
            continue
        fi

        # Ignore empty lines
        if [ -z "$line" ]; then
            continue
        fi

        # Extract the filename part
        filename=$(echo "$line" | awk -F ':' '{print $1}').$format

        # If the file doesn't exist, skip it
        if [ ! -f $directoryname/$filename ]; then
            continue
        fi
        
        # If the line contains a :, it should contain the transcription
        if [[ $line != *:* ]]; then
            transcription=""
        else
            # Extract the transcription part, which is everything after the first colon
            transcription=$(echo "$line" | cut -d ':' -f 2-)

            # Remove leading and trailing whitespace
            transcription=$(echo "$transcription" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        fi

        # Check if the file is too small
        filesize=$(wc -c $directoryname/$filename | awk '{print $1}')

        # If the transcription ended up empty, set a default value
        if [ -z "$transcription" ]; then
            echo "Warning: No transcription for $filename."
            transcription="(Surprise! No transcription available)"
        fi

        # If the file is big enough, add it to the sound-list.txt file
        if [ $filesize -gt $MIN_FILE_SIZE ]; then

            # Remove data/ from the directory name
            s3_directoryname=${directoryname#data/}

            # Convert the wav file to mp3 format, GoToSocial doesn't support wav files :(
            # https://codeberg.org/superseriousbusiness/gotosocial/src/tag/v0.19.1/internal/media/ffmpeg.go#L334
            mp3_filename=$(basename "$filename" .wav).mp3
            echo "Converting $directoryname/$filename to $directoryname/$mp3_filename"
            ffmpeg -loglevel error -y -i "$directoryname/$filename" -acodec libmp3lame -ar 44100 -ac 2 -ab 192k -f mp3 "$directoryname/$mp3_filename"

            if [ $? -ne 0 ]; then
                echo "Error converting $filename to mp3 format, skipping."
                exit 1
            fi

            echo "$s3_directoryname/$mp3_filename\t$language\t$transcription" >> data/sound-list.txt

        else
            echo "Skipping $filename, file size $filesize is less than minimum size $MIN_FILE_SIZE bytes."
        fi

        # Remove the original file
        echo "Removing $directoryname/$filename"
        rm $directoryname/$filename

    done < $listingfile

    # Remove the archive
    rm $url_data_filename

    # Remove any arbitrary content
    rm -f $directoryname/CHANGES*
    rm -f $directoryname/README*
    rm -f $directoryname/LICENSE*
    rm -f $directoryname/CREDITS*
    rm -f $directoryname/*.txt

done