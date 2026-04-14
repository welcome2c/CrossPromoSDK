#!/usr/bin/env python3
"""
Cross-Promotion SDK - App Registration Script

Usage:
    # Play Store only
    python add_app.py "https://play.google.com/store/apps/details?id=kr.dev.hoony.voda"

    # App Store only
    python add_app.py "https://apps.apple.com/kr/app/voda/id1234567890"

    # Both stores
    python add_app.py \
        "https://play.google.com/store/apps/details?id=kr.dev.hoony.voda" \
        "https://apps.apple.com/kr/app/voda/id1234567890"

Environment Variables:
    GEMINI_API_KEY: Google Gemini API key
    GOOGLE_APPLICATION_CREDENTIALS: Path to Firebase service account key JSON
        (or place service-account-key.json in the same directory as this script)
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime
from urllib.parse import urlparse, parse_qs

import requests
from bs4 import BeautifulSoup
from google import genai
import firebase_admin
from firebase_admin import credentials, firestore


# --- Constants ---

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SERVICE_ACCOUNT_PATH = os.path.join(SCRIPT_DIR, "service-account-key.json")
COLLECTION_NAME = "cross_promo_apps"
CONFIG_COLLECTION = "cross_promo_config"

GEMINI_PROMPT = """다음은 모바일 앱의 스토어 페이지 정보입니다.
이 앱을 다른 앱 안에서 크로스 프로모션할 때 사용할 한국어 한줄 소개를 만들어주세요.
- 20자 이내로 간결하게
- 앱의 핵심 가치를 전달
- 설치를 유도하는 매력적인 문구
- 한줄 소개 텍스트만 출력하세요 (따옴표, 설명 없이)

앱 이름: {app_name}
스토어 설명: {store_description}"""


# --- URL Parsing ---

def parse_play_store_url(url: str) -> dict:
    """Extract package ID from Play Store URL."""
    parsed = urlparse(url)
    if "play.google.com" not in parsed.netloc:
        return {}
    params = parse_qs(parsed.query)
    app_id = params.get("id", [None])[0]
    if not app_id:
        return {}
    return {"platform": "android", "appId": app_id, "storeUrl": url}


def parse_app_store_url(url: str) -> dict:
    """Extract app store ID and bundle info from App Store URL."""
    parsed = urlparse(url)
    if "apps.apple.com" not in parsed.netloc:
        return {}
    match = re.search(r"/id(\d+)", parsed.path)
    if not match:
        return {}
    return {
        "platform": "ios",
        "iosAppStoreId": match.group(1),
        "storeUrl": url,
    }


def parse_url(url: str) -> dict:
    """Detect platform and extract info from a store URL."""
    result = parse_play_store_url(url)
    if result:
        return result
    result = parse_app_store_url(url)
    if result:
        return result
    raise ValueError(f"Unrecognized store URL: {url}")


# --- Store Page Scraping ---

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "ko-KR,ko;q=0.9,en;q=0.8",
}


def scrape_play_store(url: str) -> dict:
    """Scrape app info from Google Play Store page."""
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")

    # App name - try og:title meta tag first
    app_name = ""
    og_title = soup.find("meta", property="og:title")
    if og_title and og_title.get("content"):
        app_name = og_title["content"].split(" - ")[0].strip()
    if not app_name:
        title_tag = soup.find("title")
        if title_tag:
            app_name = title_tag.text.split(" - ")[0].strip()

    # Description - og:description
    description = ""
    og_desc = soup.find("meta", property="og:description")
    if og_desc and og_desc.get("content"):
        description = og_desc["content"]

    # Icon URL - og:image
    icon_url = ""
    og_image = soup.find("meta", property="og:image")
    if og_image and og_image.get("content"):
        icon_url = og_image["content"]

    return {
        "appName": app_name,
        "description": description,
        "iconUrl": icon_url,
    }


def scrape_app_store(url: str, app_store_id: str) -> dict:
    """Scrape app info from Apple App Store using iTunes Lookup API."""
    lookup_url = f"https://itunes.apple.com/lookup?id={app_store_id}&country=kr"
    resp = requests.get(lookup_url, timeout=15)
    resp.raise_for_status()
    data = resp.json()

    if data.get("resultCount", 0) == 0:
        # Fallback to HTML scraping
        return scrape_app_store_html(url)

    result = data["results"][0]
    return {
        "appName": result.get("trackName", ""),
        "description": result.get("description", ""),
        "iconUrl": result.get("artworkUrl512", result.get("artworkUrl100", "")),
        "bundleId": result.get("bundleId", ""),
    }


def scrape_app_store_html(url: str) -> dict:
    """Fallback: scrape App Store page HTML."""
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")

    app_name = ""
    og_title = soup.find("meta", property="og:title")
    if og_title and og_title.get("content"):
        app_name = og_title["content"].split(" on the")[0].strip()

    description = ""
    og_desc = soup.find("meta", property="og:description")
    if og_desc and og_desc.get("content"):
        description = og_desc["content"]

    icon_url = ""
    og_image = soup.find("meta", property="og:image")
    if og_image and og_image.get("content"):
        icon_url = og_image["content"]

    return {
        "appName": app_name,
        "description": description,
        "iconUrl": icon_url,
    }


# --- Gemini API ---

def generate_short_description(app_name: str, store_description: str) -> str:
    """Use Gemini API to generate a short Korean promo description."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("   WARNING: GEMINI_API_KEY not set.")
        return ""

    try:
        client = genai.Client(api_key=api_key)
        prompt = GEMINI_PROMPT.format(
            app_name=app_name,
            store_description=store_description[:1000],
        )
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        return response.text.strip().strip('"').strip("'")
    except Exception as e:
        print(f"   WARNING: Gemini API failed: {e}")
        return ""


# --- Firestore ---

def init_firestore():
    """Initialize Firebase Admin SDK and return Firestore client."""
    if firebase_admin._apps:
        return firestore.client()

    cred_path = os.environ.get(
        "GOOGLE_APPLICATION_CREDENTIALS", DEFAULT_SERVICE_ACCOUNT_PATH
    )
    if not os.path.exists(cred_path):
        print(f"ERROR: Service account key not found at: {cred_path}")
        print("Please either:")
        print(f"  1. Place service-account-key.json in {SCRIPT_DIR}")
        print("  2. Set GOOGLE_APPLICATION_CREDENTIALS environment variable")
        sys.exit(1)

    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
    return firestore.client()


def check_existing_doc(db, doc_id: str) -> bool:
    """Check if a document already exists in the collection."""
    doc = db.collection(COLLECTION_NAME).document(doc_id).get()
    return doc.exists


def upload_to_firestore(db, doc_id: str, data: dict):
    """Upload app data to Firestore."""
    db.collection(COLLECTION_NAME).document(doc_id).set(data)


def ensure_config_exists(db):
    """Create default config document if it doesn't exist."""
    config_ref = db.collection(CONFIG_COLLECTION).document("settings")
    if not config_ref.get().exists:
        config_ref.set({
            "enabled": True,
            "selectionMode": "weighted_random",
            "minAppOpenCount": 3,
            "popupTitle": "\uac1c\ubc1c\uc790\uc758 \ub2e4\ub978 \uc571",
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })
        print("Created default config: cross_promo_config/settings")


# --- Main Logic ---

def build_app_document(parsed_urls: list, scraped_data: dict, short_desc: str) -> dict:
    """Build the Firestore document from collected data."""
    platforms = []
    store_links = {}
    app_id = ""
    ios_app_store_id = ""

    for p in parsed_urls:
        platforms.append(p["platform"])
        if p["platform"] == "android":
            app_id = p["appId"]
            store_links["android"] = p["storeUrl"]
        elif p["platform"] == "ios":
            store_links["ios"] = p["storeUrl"]
            ios_app_store_id = p.get("iosAppStoreId", "")
            if not app_id and scraped_data.get("bundleId"):
                app_id = scraped_data["bundleId"]

    doc = {
        "appId": app_id,
        "appName": scraped_data.get("appName", ""),
        "shortDescription": short_desc,
        "iconUrl": scraped_data.get("iconUrl", ""),
        "platforms": sorted(set(platforms)),
        "storeLinks": store_links,
        "priority": 10,
        "enabled": True,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }

    if ios_app_store_id:
        doc["iosAppStoreId"] = ios_app_store_id

    return doc


def make_doc_id(app_name: str, app_id: str) -> str:
    """Generate a Firestore document ID from the app name or ID."""
    # Try to use the last part of the app ID (e.g., "voda" from "kr.dev.hoony.voda")
    if app_id:
        parts = app_id.split(".")
        return parts[-1].lower()
    # Fallback to app name
    return re.sub(r"[^a-z0-9]", "", app_name.lower())


def main():
    parser = argparse.ArgumentParser(
        description="Register an app for cross-promotion via store URL"
    )
    parser.add_argument(
        "urls",
        nargs="+",
        help="Play Store and/or App Store URL(s)",
    )
    parser.add_argument(
        "--priority",
        type=int,
        default=10,
        help="Priority weight for selection (default: 10)",
    )
    parser.add_argument(
        "--description",
        type=str,
        default=None,
        help="Short description to use (skips Gemini API)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be uploaded without actually uploading",
    )
    args = parser.parse_args()

    # 1. Parse URLs
    print("\n1. URL parsing...")
    parsed_urls = []
    for url in args.urls:
        try:
            parsed = parse_url(url.strip())
            parsed_urls.append(parsed)
            print(f"   {parsed['platform']}: {url}")
        except ValueError as e:
            print(f"   ERROR: {e}")
            sys.exit(1)

    # 2. Scrape store pages
    print("\n2. Scraping store pages...")
    scraped_data = {}
    for p in parsed_urls:
        if p["platform"] == "android":
            data = scrape_play_store(p["storeUrl"])
            scraped_data.update(data)
            print(f"   Play Store: {data.get('appName', 'N/A')}")
        elif p["platform"] == "ios":
            data = scrape_app_store(p["storeUrl"], p.get("iosAppStoreId", ""))
            # iOS data takes precedence for shared fields only if Android didn't provide them
            for k, v in data.items():
                if v and not scraped_data.get(k):
                    scraped_data[k] = v
            print(f"   App Store: {data.get('appName', 'N/A')}")

    if not scraped_data.get("appName"):
        print("   ERROR: Could not extract app name from store page")
        sys.exit(1)

    # 3. Generate short description
    if args.description:
        short_desc = args.description
        print(f'\n3. Using provided description: "{short_desc}"')
    else:
        print("\n3. Generating short description via Gemini...")
        short_desc = generate_short_description(
            scraped_data["appName"],
            scraped_data.get("description", ""),
        )
        if short_desc:
            print(f'   "{short_desc}"')
        else:
            print("   Gemini unavailable. Use --description flag to provide manually.")
            sys.exit(1)

    # 4. Build document
    doc = build_app_document(parsed_urls, scraped_data, short_desc)
    doc["priority"] = args.priority
    doc_id = make_doc_id(scraped_data["appName"], doc["appId"])

    # 5. Display summary
    print("\n" + "=" * 50)
    print("App Info Summary")
    print("=" * 50)
    print(f"  Document ID : {doc_id}")
    print(f"  App Name    : {doc['appName']}")
    print(f"  App ID      : {doc['appId']}")
    print(f"  Platforms   : {doc['platforms']}")
    print(f"  Description : {doc['shortDescription']}")
    print(f"  Icon URL    : {doc['iconUrl'][:80]}..." if len(doc.get("iconUrl", "")) > 80 else f"  Icon URL    : {doc.get('iconUrl', '')}")
    print(f"  Store Links : {json.dumps(doc['storeLinks'], indent=2, ensure_ascii=False)}")
    print(f"  Priority    : {doc['priority']}")
    if doc.get("iosAppStoreId"):
        print(f"  iOS Store ID: {doc['iosAppStoreId']}")
    print("=" * 50)

    if args.dry_run:
        print("\n[DRY RUN] Document preview (not uploaded):")
        preview = {k: v for k, v in doc.items() if k not in ("createdAt", "updatedAt")}
        print(json.dumps(preview, indent=2, ensure_ascii=False))
        return

    # 6. Upload to Firestore
    confirm = input("\nUpload to Firestore? (y/n): ").strip().lower()
    if confirm != "y":
        print("Cancelled.")
        return

    db = init_firestore()

    # Check for existing document
    if check_existing_doc(db, doc_id):
        overwrite = input(
            f"Document '{doc_id}' already exists. Overwrite? (y/n): "
        ).strip().lower()
        if overwrite != "y":
            print("Cancelled.")
            return
        # Keep original createdAt on update
        doc.pop("createdAt", None)

    upload_to_firestore(db, doc_id, doc)
    ensure_config_exists(db)
    print(f"\nDone! {COLLECTION_NAME}/{doc_id} uploaded successfully.")


if __name__ == "__main__":
    main()
