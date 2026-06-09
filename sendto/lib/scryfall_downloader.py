# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests"
# ]
# ///

# Authors: Kimi-2.6🧙‍♂️, GLM-5🧙‍♂️, scillidan🤡

import requests
import time
import os
import json
import argparse
from datetime import datetime, timedelta


SEARCH_QUERY = 'date>=soi (c:c or c>=w or c>=g) (r:uncommon or r:rare or r:mythic)'
DEFAULT_OUTPUT_DIR = './scryfall_cards'
CACHE_DIR = './cache'
CARDS_CACHE_FILE = os.path.join(CACHE_DIR, 'cards_cache.json')
BULK_DATA_FILE = os.path.join(CACHE_DIR, 'bulk_data.json')
DELAY_BETWEEN_DOWNLOADS = 0.25
MAX_RETRIES = 3
IMAGE_FORMAT = 'png'
ONLY_FRONT_FACE = True
BULK_DATA_TYPE = 'oracle_cards'


headers = {
    'User-Agent': 'ScryfallBatchDownloader/1.0',
    'Accept': 'application/json'
}

def safe_filename(name):
    """Generate a safe filename by removing invalid characters."""
    invalid_chars = '<>:"/\\|?*'
    for char in invalid_chars:
        name = name.replace(char, '_')
    return name.strip()

def download_file(url, filepath, desc='file'):
    """Download a file from URL."""
    for attempt in range(MAX_RETRIES):
        try:
            resp = requests.get(url, headers=headers, timeout=60, stream=True)
            if resp.status_code == 429:
                print(f'  Rate limited, waiting 5 seconds...')
                time.sleep(5)
                continue
            resp.raise_for_status()
            with open(filepath, 'wb') as f:
                for chunk in resp.iter_content(chunk_size=8192):
                    f.write(chunk)
            print(f'  Downloaded {desc}: {os.path.basename(filepath)}')
            return True
        except Exception as e:
            print(f'  Download failed (attempt {attempt+1}/{MAX_RETRIES}): {e}')
            time.sleep(2)
    return False

def download_image(url, filepath):
    """Download a single image from URL."""
    for attempt in range(MAX_RETRIES):
        try:
            resp = requests.get(url, headers=headers, timeout=30)
            if resp.status_code == 429:
                print(f'    Rate limited, waiting 3 seconds...')
                time.sleep(3)
                continue
            resp.raise_for_status()
            with open(filepath, 'wb') as f:
                f.write(resp.content)
            return True
        except Exception as e:
            print(f'    Download failed (attempt {attempt+1}/{MAX_RETRIES}): {e}')
            time.sleep(1)
    return False

def save_cards_cache(cards, query, source='bulk'):
    """Save filtered card data to cache file."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    cache_data = {
        'query': query,
        'source': source,
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'total_cards': len(cards),
        'cards': cards
    }
    with open(CARDS_CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache_data, f, ensure_ascii=False, indent=2)
    print(f'Cards cache saved: {CARDS_CACHE_FILE}')

def load_cards_cache():
    """Load card data from cache file."""
    if not os.path.exists(CARDS_CACHE_FILE):
        return None
    try:
        with open(CARDS_CACHE_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f'Failed to load cards cache: {e}')
        return None

def get_bulk_data_info():
    """Get bulk data info from Scryfall API."""
    url = 'https://api.scryfall.com/bulk-data'
    try:
        resp = requests.get(url, headers=headers, timeout=30)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        print(f'Failed to get bulk data info: {e}')
        return None

def load_bulk_data():
    """Load bulk data from cache file."""
    if not os.path.exists(BULK_DATA_FILE):
        return None
    try:
        print(f'Loading bulk data from cache...')
        with open(BULK_DATA_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f'Failed to load bulk data: {e}')
        return None

def filter_cards_by_query(cards, query):
    """Filter cards matching the search query conditions."""
    rarity_map = {'common': 'c', 'uncommon': 'u', 'rare': 'r', 'mythic': 'm', 'special': 's', 'bonus': 'b'}

    filtered = []
    for card in cards:
        rarity = card.get('rarity', 'common')
        rarity_code = rarity_map.get(rarity, 'c')

        if rarity_code not in ['u', 'r', 'm']:
            continue

        colors = card.get('colors', [])
        color_identity = card.get('color_identity', [])

        has_colorless = 'C' in colors or len(colors) == 0
        has_white = 'W' in color_identity
        has_green = 'G' in color_identity

        if not (has_colorless or has_white or has_green):
            continue

        released_at = card.get('released_at', '')
        if released_at < '2016-04-08':
            continue

        filtered.append(card)

    return filtered

def fetch_bulk_data():
    """Fetch bulk data from Scryfall."""
    print(f'Fetching bulk data info (type: {BULK_DATA_TYPE})...')
    bulk_info_response = get_bulk_data_info()
    if not bulk_info_response:
        print('Failed to get bulk data info.')
        return None

    target_data = None
    for item in bulk_info_response.get('data', []):
        if item.get('type') == BULK_DATA_TYPE:
            target_data = item
            break

    if not target_data:
        print(f'Bulk data type "{BULK_DATA_TYPE}" not found.')
        return None

    download_url = target_data.get('download_uri')
    if not download_url:
        print('No download URL found.')
        return None

    print(f'Bulk data updated at: {target_data.get("updated_at", "unknown")}')
    print(f'Size: {target_data.get("compressed_size", "unknown")}')
    print(f'Downloading bulk data...')

    os.makedirs(CACHE_DIR, exist_ok=True)
    if download_file(download_url, BULK_DATA_FILE, 'bulk data'):
        return load_bulk_data()
    return None

def main():
    parser = argparse.ArgumentParser(description='Download Scryfall card images')
    parser.add_argument('-o', '--output', type=str, default=DEFAULT_OUTPUT_DIR,
                        help=f'Output directory for downloaded images (default: {DEFAULT_OUTPUT_DIR})')
    parser.add_argument('--update', action='store_true',
                        help='Update bulk data from Scryfall')
    args = parser.parse_args()

    output_dir = args.output
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(CACHE_DIR, exist_ok=True)

    print(f'Search query: {SEARCH_QUERY}')
    print(f'Output directory: {output_dir}')
    print(f'Image format: {IMAGE_FORMAT}')
    print(f'Bulk data type: {BULK_DATA_TYPE}')
    print('=' * 50)

    all_cards = []

    if args.update:
        print('Mode: Updating bulk data (--update)')
        bulk_data = fetch_bulk_data()
        if not bulk_data:
            print('Failed to fetch bulk data.')
            return
        print(f'Loaded {len(bulk_data)} cards from bulk data')
        print('Filtering cards by query...')
        all_cards = filter_cards_by_query(bulk_data, SEARCH_QUERY)
        print(f'Filtered to {len(all_cards)} matching cards')
        save_cards_cache(all_cards, SEARCH_QUERY, BULK_DATA_TYPE)
    else:
        cache_data = load_cards_cache()
        if cache_data:
            print(f'Loaded cache from: {cache_data.get("timestamp", "unknown")}')
            print(f'Cache source: {cache_data.get("source", "unknown")}')
            all_cards = cache_data.get('cards', [])
            print(f'Found {len(all_cards)} cards in cache')
        else:
            print('No cards cache found. Running with --update first...')
            bulk_data = load_bulk_data()
            if bulk_data:
                print(f'Loaded {len(bulk_data)} cards from cached bulk data')
                print('Filtering cards by query...')
                all_cards = filter_cards_by_query(bulk_data, SEARCH_QUERY)
                print(f'Filtered to {len(all_cards)} matching cards')
                save_cards_cache(all_cards, SEARCH_QUERY, BULK_DATA_TYPE)
            else:
                print('No bulk data cache found. Use --update to download bulk data.')
                return

    print(f'\nCollected {len(all_cards)} cards. Starting download...')
    print('=' * 50)

    success_count = 0
    fail_count = 0
    skipped_count = 0

    for idx, card in enumerate(all_cards, 1):
        card_name = card.get('name', 'unknown')
        set_code = card.get('set', 'unknown')
        collector_number = card.get('collector_number', '0')

        faces = []
        if 'card_faces' in card and card.get('layout') in ['transform', 'modal_dfc', 'double_faced_token', 'reversible_card']:
            for face_idx, face in enumerate(card['card_faces']):
                if 'image_uris' in face and IMAGE_FORMAT in face['image_uris']:
                    face_name = face.get('name', card_name)
                    suffix = f'_face{face_idx+1}' if len(card['card_faces']) > 1 else ''
                    faces.append((face['image_uris'][IMAGE_FORMAT], face_name, suffix))
        elif 'image_uris' in card and IMAGE_FORMAT in card['image_uris']:
            faces.append((card['image_uris'][IMAGE_FORMAT], card_name, ''))
        else:
            print(f'[{idx}/{len(all_cards)}] ⚠️ {card_name} - No {IMAGE_FORMAT} image available')
            skipped_count += 1
            continue

        for img_url, face_name, suffix in faces:
            if ONLY_FRONT_FACE and suffix == '_face2':
                skipped_count += 1
                continue

            safe_name = safe_filename(face_name)
            filename = f"{safe_name}_{set_code}_{collector_number}{suffix}.{IMAGE_FORMAT}"
            filepath = os.path.join(output_dir, filename)

            if os.path.exists(filepath):
                print(f'[{idx}/{len(all_cards)}] ⏭️ Already exists: {filename}')
                success_count += 1
                continue

            print(f'[{idx}/{len(all_cards)}] ⬇️ Downloading: {filename}')
            if download_image(img_url, filepath):
                success_count += 1
            else:
                fail_count += 1

            time.sleep(DELAY_BETWEEN_DOWNLOADS)

    print('\n' + '=' * 50)
    print(f'Download complete!')
    print(f'  Success: {success_count}')
    print(f'  Failed: {fail_count}')
    print(f'  Skipped: {skipped_count}')
    print(f'  Total cards: {len(all_cards)}')
    print(f'\nFiles saved to: {os.path.abspath(output_dir)}')
    print(f'Cache directory: {os.path.abspath(CACHE_DIR)}')

if __name__ == '__main__':
    main()