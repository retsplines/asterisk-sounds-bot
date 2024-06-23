#
# Download sound files from the Asterisk downloads site, filter out small ones, and dump them in data/
# Producing a data/sound-list.txt file that contains the file names, language, and what is said in each.
#
# Some of the transcriptions in the listings are broken, run onto multiple lines, or refer to the wrong file names.
# These will generate errors but won't stop the script from running or break the output.
#

# Define the minimum file size
# 15KB seems to be a good threshold
MIN_FILE_SIZE=15000

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

    url_data_filename=data/$(basename $url)
    if [ ! -f $url_data_filename ]; then
        echo "Downloading $url"
        wget -O $url_data_filename $url
    fi

    # Extract ze file under the filename directory
    directoryname=${url_data_filename%.tar.gz}
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

        # Extract the transcription part
        transcription=$(echo "$line" | awk -F ':' '{print $2}')
    
        # Check if the file is too small
        filesize=$(wc -c $directoryname/$filename | awk '{print $1}')

        # If the file is big enough, add it to the sound-list.txt file
        if [ $filesize -gt $MIN_FILE_SIZE ]; then
            echo "$directoryname/$filename $language $transcription" >> data/sound-list.txt
        else
            # Remove the file so we don't upload it
            rm $directoryname/$filename
        fi

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