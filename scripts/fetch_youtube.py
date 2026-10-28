"""채널별 최신 영상을 YouTube RSS에서 받아 data/videos.json으로 저장 (API 키 불필요)."""
import json, sys, urllib.request, xml.etree.ElementTree as ET
from datetime import datetime, timezone

CHANNELS = [
    {"key": "niche",    "name": "틈새의 과학",            "handle": "@niche_in_science",    "id": "UC4w85tYDUaWYBGkgnd4twQg"},
    {"key": "minister", "name": "쉿! 목사님 과학공부시간", "handle": "@scienceclass4minister", "id": "UCI9LwbjNiIBzEapfPrtWMRQ"},
    {"key": "kimjh",    "name": "김진호 박사의 창조론 강의", "handle": "@김진호박사",            "id": "UCP9FSuX8H-EhQCm_LfcRq4g"},
]
LIMIT = 3
NS = {"a": "http://www.w3.org/2005/Atom", "yt": "http://www.youtube.com/xml/schemas/2015"}

def fetch(cid):
    url = "https://www.youtube.com/feeds/videos.xml?channel_id=" + cid
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        root = ET.fromstring(r.read())
    out = []
    for e in root.findall("a:entry", NS)[:LIMIT]:
        vid = e.find("yt:videoId", NS).text
        out.append({
            "id": vid,
            "title": e.find("a:title", NS).text,
            "published": e.find("a:published", NS).text[:10],
        })
    return out

def main():
    try:
        old = json.load(open("data/videos.json", encoding="utf-8"))
        old_map = {c["key"]: c for c in old.get("channels", [])}
    except Exception:
        old_map = {}
    channels = []
    for ch in CHANNELS:
        try:
            vids = fetch(ch["id"])
        except Exception as ex:
            print("WARN", ch["key"], ex, file=sys.stderr)
            vids = old_map.get(ch["key"], {}).get("videos", [])
        channels.append({**ch, "url": "https://www.youtube.com/channel/" + ch["id"], "videos": vids})
    json.dump({"updated": datetime.now(timezone.utc).strftime("%Y-%m-%d"), "channels": channels},
              open("data/videos.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

main()
