import boto3
import sys
import os
import random
import logging
import argparse
from dataclasses import dataclass
from mastodon import Mastodon


@dataclass
class Locale:
    name: str
    flag: str

# Define some constants
SOUND_LIST_FILE = 'data/sound-list.txt'

# S3 bucket where we can find the sounds
SOUND_S3_BUCKET = os.environ.get('SOUND_S3_BUCKET')

# Mastodon credentials
MASTODON_ACCESS_TOKEN = os.environ.get('MASTODON_ACCESS_TOKEN')
MASTODON_INSTANCE = os.environ.get('MASTODON_INSTANCE')

# Mapping of the locales
LOCALES = {
    'en': Locale('US English', '🇺🇸'),
    'en_GB': Locale('British English', '🇬🇧'),
    'en_NZ': Locale('New Zealand English', '🇳🇿'),
    'en_AU': Locale('Australian English', '🇦🇺'),
}

# Set up the logging subsystem
logger = logging.getLogger()
logger.setLevel(logging.INFO)
stdout_handler = logging.StreamHandler(sys.stderr)
stdout_handler.setFormatter(logging.Formatter('%(levelname)s: %(message)s'))
logger.addHandler(stdout_handler)

# Log setup
logger.info('🤖 Asterisk Sound Bot Startup')
logger.info('+ Mastodon instance: %s', MASTODON_INSTANCE)
logger.info('+ S3 bucket: %s', SOUND_S3_BUCKET)

# Parse argments
parser = argparse.ArgumentParser()
parser.add_argument('--dry-run', action='store_true', help='Do not post to Mastodon, just pick a sound and print it')
args = parser.parse_args()

def lambda_handler(event, context):
    """
    Handle the invokation of the Lambda function.
    This function is invoked by EventBridge on a schedule.
    """
    
    # Check that the sounds list file is available
    if not os.path.exists(SOUND_LIST_FILE):
        logger.error(f'{SOUND_LIST_FILE} not found - exiting')
        return
    
    # Read the list of sounds
    with open(SOUND_LIST_FILE, 'r') as f:
        sounds = f.readlines()

        # Pick a random sound
        sound_line = random.choice(sounds).strip()

        # Extract the sound name and locale
        sound_line_parts = sound_line.split('\t')
        path = sound_line_parts[0]

        # Try to extract the package name like 'asterisk-extra-sounds'
        package_name_parts = path.split('-')
        package_name = '-'.join(package_name_parts[0:3]) if len(package_name_parts) > 2 else os.path.dirname(path)

        # Just the sound file name
        sound_name = os.path.basename(path)

        # The locale & transcription
        locale_name = sound_line_parts[1]
        transcription = ''.join(sound_line_parts[2:])

        # Known locale?
        if locale_name not in LOCALES:
            logger.error(f'Sound has an unknown locale: {locale_name}')
            return

        # Log the sound
        locale = LOCALES[locale_name]
        logger.info(f'Selected sound: {sound_name} from package {package_name} with locale {locale.name} with transcription "{transcription}"')
        logger.info(f'File name: {path}')


        # Download the sound
        s3 = boto3.client('s3')
        sound_data = s3.get_object(Bucket=SOUND_S3_BUCKET, Key=path)['Body'].read()
        logger.info(f'Downloaded {len(sound_data)} bytes of sound data')

        # Dry run?
        if args.dry_run:
            logger.info('Dry run - not posting to Mastodon')
            return

        # Authenticate
        mastodon = Mastodon(
            version_check_mode="none",
            access_token=MASTODON_ACCESS_TOKEN,
            api_base_url=MASTODON_INSTANCE,
            user_agent='asterisk-sound-bot'
        )

        # Create a media upload
        logger.info('Uploading media file... This may time out if the processing takes too long')
        media_upload = mastodon.media_post(sound_data, 'audio/wav', synchronous=True)

        # Wait for the post
        logger.info('Media uploaded: %s', media_upload)

        # Update the alt-text
        alt_text = f'A telephone interactive voice response (IVR) system saying "{transcription}" in {locale.name}'
        mastodon.media_update(media_upload, description=alt_text)

        # Gah - we converted the wavs in the original archives to mp3s, so change the name for display purposes
        if sound_name.endswith('.mp3'):
            sound_name = sound_name[:-4] + '.wav'

        # Post the sound
        mastodon.status_post(
            f'"{transcription}"\n\n' +
            f'*️⃣ Asterisk sound \'{sound_name}\'\n' +
            f'📦 From package \'{package_name}\'\n' +
            f'{locale.flag} Spoken in {locale.name}', media_ids=[media_upload], visibility='public'
        )

        logger.info('✅ Posted to Mastodon')

# If we're run from the command line, invoke the handler
if __name__ == '__main__':
    lambda_handler(None, None)
