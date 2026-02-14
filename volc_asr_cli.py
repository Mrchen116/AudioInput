#!/usr/bin/env python3
import argparse
import base64
import json
import os
import sys
import uuid
import subprocess
import tempfile
from urllib import request, error
import dotenv

dotenv.load_dotenv()
APP_ID = os.getenv("APP_ID")
ACCESS_TOKEN = os.getenv("ACCESS_TOKEN")

RECOGNIZE_URL = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash"
RESOURCE_ID = "volc.bigasr.auc_turbo"


def eprint(*args):
    print(*args, file=sys.stderr)


def http_post(url, headers, body_obj):
    data = json.dumps(body_obj).encode("utf-8")
    req = request.Request(url, data=data, headers=headers, method="POST")
    try:
        with request.urlopen(req, timeout=60) as resp:
            resp_headers = dict(resp.headers)
            resp_body = resp.read()
            return resp_headers, resp_body
    except error.HTTPError as e:
        return dict(e.headers), e.read()


def convert_caf_to_wav(src_path):
    # Convert CAF (iMessage voice) to 16k mono WAV using macOS afconvert
    out_fd, out_path = tempfile.mkstemp(suffix=".wav")
    os.close(out_fd)
    cmd = [
        "/usr/bin/afconvert",
        "-f", "WAVE",
        "-d", "LEI16@16000",
        "-c", "1",
        src_path,
        out_path,
    ]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"afconvert failed: {proc.stderr.strip() or proc.stdout.strip()}")
    return out_path


def main():
    ap = argparse.ArgumentParser(description="Volcengine AUC Turbo ASR CLI for OpenClaw")
    ap.add_argument("--file", required=True, help="Local audio file path")
    ap.add_argument("--language", help="Optional language code")
    ap.add_argument("--format", help="Audio format: wav|mp3|ogg|opus (optional)")
    args = ap.parse_args()

    src_path = args.file
    tmp_path = None
    # iMessage voice notes are typically CAF; convert to WAV before upload
    if src_path.lower().endswith(".caf"):
        try:
            tmp_path = convert_caf_to_wav(src_path)
            src_path = tmp_path
            if not args.format:
                args.format = "wav"
        except Exception as exc:
            eprint(str(exc))
            return 2

    try:
        with open(src_path, "rb") as f:
            raw = f.read()
    except Exception as exc:
        eprint(f"Failed to read file: {exc}")
        return 2
    finally:
        # clean temp wav if created
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass

    audio_b64 = base64.b64encode(raw).decode("utf-8")

    headers = {
        "Content-Type": "application/json",
        "X-Api-App-Key": APP_ID,
        "X-Api-Access-Key": ACCESS_TOKEN,
        "X-Api-Resource-Id": RESOURCE_ID,
        "X-Api-Request-Id": str(uuid.uuid4()),
        "X-Api-Sequence": "-1",
    }

    audio_obj = {"data": audio_b64}
    if args.language:
        audio_obj["language"] = args.language
    if args.format:
        audio_obj["format"] = args.format

    body = {
        "user": {"uid": APP_ID},
        "audio": audio_obj,
        "request": {
            "model_name": "bigmodel",
            "enable_itn": True,
            "enable_punc": True,
        },
    }

    resp_headers, resp_body = http_post(RECOGNIZE_URL, headers, body)
    code = resp_headers.get("X-Api-Status-Code")
    if code != "20000000":
        eprint(f"Recognize failed: status={code} msg={resp_headers.get('X-Api-Message')}")
        return 1

    try:
        payload = json.loads(resp_body.decode("utf-8")) if resp_body else {}
    except Exception:
        payload = {}

    text = None
    if isinstance(payload, dict):
        result = payload.get("result") or {}
        if isinstance(result, dict):
            text = result.get("text")

    if not text:
        eprint("No transcription text returned")
        return 1

    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
