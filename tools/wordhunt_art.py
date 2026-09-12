#!/usr/bin/env python3
"""Generate Word Hunt art against docs/WordSearch/ArtContract.md.

Reads the sheet and word tables out of AI/WordSearchWordBank.swift, calls the
OpenAI Images API (key from $OPENAI_API_KEY — never stored here), and writes
each result as an image set into Resources/Assets.xcassets under the contract
name, so the game picks it up with no code change.

    tools/wordhunt_art.py --sheet 7                 # one sheet end to end
    tools/wordhunt_art.py --sheet 7 --only mascot   # mascot | scene | words
    tools/wordhunt_art.py --sheet 7 --dry-run       # print prompts only

Existing image sets are skipped unless --force. Outputs also land in
tools/art-out/ so they can be inspected before the catalog is committed.
"""

import argparse, base64, json, os, re, sys, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "AI" / "WordSearchWordBank.swift"
CATALOG = ROOT / "Resources" / "Assets.xcassets"
OUT = ROOT / "tools" / "art-out"

STYLE = (
    "Children's educational game illustration, ages 4-7. Soft rounded shapes, "
    "friendly big eyes, warm flat colours with gentle shading, clean edges, "
    "no text, no letters, no watermark. Same art style as a premium picture book."
)

MASCOT_SUGGESTION = {
    1: "a friendly bunny gardener with a little watering can", 2: "a cute calf",
    3: "a happy dolphin", 4: "a baby triceratops", 5: "a young astronaut in a puffy suit",
    6: "a friendly monkey explorer with a safari hat", 7: "a friendly fox",
    8: "a smiling city bus with a face", 25: "a cute little round robot",
    29: "a friendly young wizard", 30: "a cute small dragon", 40: "a bunny in a party hat",
}

STATE_POSE = {
    "Idle": "standing relaxed, gentle smile, facing slightly to the left",
    "Celebrate": "jumping for joy with both arms up, big happy grin",
    "Hint": "leaning forward and pointing to the left with one hand, curious face",
    "Encourage": "kind reassuring smile, one hand raised in a friendly wave",
    "WordFound": "hopping happily, eyes closed with delight",
}
# The five states the game requests today; Look/Point/Happy are reserved.


def parse_bank():
    text = BANK.read_text()
    sheets = []
    for m in re.finditer(
        r'number: (\d+), title: "([^"]+)", emoji: "([^"]+)", mascot: "([^"]+)", '
        r'palette: \.(\w+), words: \[(.*?)\]\),', text, re.S):
        n, title, emoji, mascot, palette, body = m.groups()
        words = re.findall(r'\.init\("([A-Z]+)", "([^"]+)"\)', body)
        sheets.append(dict(number=int(n), title=title, emoji=emoji, mascot=mascot,
                           palette=palette, words=words))
    return sheets


def mascot_prompt(sheet, state):
    who = MASCOT_SUGGESTION.get(sheet["number"], f"a cute {describe_emoji(sheet['mascot'])} character")
    return (f"{STYLE} A single full-body cartoon character: {who}, the mascot of a "
            f"'{sheet['title']}' page. {STATE_POSE[state]}. Centered, isolated on a plain "
            f"solid white background, nothing else in frame.")


def scene_prompt(sheet):
    return (f"{STYLE} A wide background scene for a '{sheet['title']}' themed page: "
            f"the environment only, no characters, no people, no text. The centre of the "
            f"image must stay calm and uncluttered (a panel will sit there); the interesting "
            f"detail lives at the edges: framing foliage, objects and sky. Portrait orientation.")


def word_prompt(word, emoji):
    return (f"{STYLE} A single simple icon-style picture of: {word.lower()} ({describe_emoji(emoji)}). "
            f"One object only, readable when tiny, centered, isolated on a plain solid white background.")


def describe_emoji(e):
    # The emoji is the art director's note; the model reads it fine as text.
    return e


def generate(prompt, size, out_path, dry_run):
    if dry_run:
        print(f"  [dry-run] {out_path.name}: {prompt[:110]}…")
        return None
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        sys.exit("OPENAI_API_KEY is not set in this shell")
    body = json.dumps({"model": "gpt-image-1", "prompt": prompt, "size": size,
                       "n": 1, "quality": "medium", "output_format": "png",
                       "background": "transparent" if size == "1024x1024" else "opaque"}).encode()
    req = urllib.request.Request("https://api.openai.com/v1/images/generations", data=body,
                                 headers={"Authorization": f"Bearer {key}",
                                          "Content-Type": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.load(r)
            break
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:300]
            if e.code in (429, 500, 502, 503) and attempt < 2:
                time.sleep(5 * (attempt + 1)); continue
            sys.exit(f"API error {e.code}: {msg}")
    png = base64.b64decode(data["data"][0]["b64_json"])
    out_path.write_bytes(png)
    return out_path


def write_imageset(name, png_path):
    folder = CATALOG / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{name}.png").write_bytes(png_path.read_bytes())
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "wordhunt_art.py", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }, indent=2) + "\n")
    return folder


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", type=int, required=True)
    ap.add_argument("--only", choices=["mascot", "scene", "words"])
    ap.add_argument("--states", default="Idle,Celebrate,Hint,Encourage,WordFound")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    sheet = next((s for s in parse_bank() if s["number"] == args.sheet), None)
    if not sheet:
        sys.exit(f"no sheet {args.sheet}")
    OUT.mkdir(exist_ok=True)
    nn = f"{sheet['number']:02d}"
    jobs = []
    if args.only in (None, "mascot"):
        for state in args.states.split(","):
            jobs.append((f"WS_CHAR_{nn}_{state}", mascot_prompt(sheet, state), "1024x1024"))
    if args.only in (None, "scene"):
        jobs.append((f"WS_ENV_{nn}", scene_prompt(sheet), "1024x1536"))
    if args.only in (None, "words"):
        for word, emoji in sheet["words"]:
            jobs.append((f"WS_WORD_{word}", word_prompt(word, emoji), "1024x1024"))

    print(f"Sheet {nn} {sheet['title']}: {len(jobs)} assets")
    for name, prompt, size in jobs:
        target = CATALOG / f"{name}.imageset"
        if target.exists() and not args.force and not args.dry_run:
            print(f"  skip {name} (exists)"); continue
        print(f"  {name} …", flush=True)
        png = generate(prompt, size, OUT / f"{name}.png", args.dry_run)
        if png:
            write_imageset(name, png)
    print("done")


if __name__ == "__main__":
    main()
