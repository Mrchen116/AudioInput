# AudioInput (macOS Voice Input)

A native macOS menu-bar voice input app using Volcengine ASR.

## Behavior

- Hold `Right Command` to record.
- Release `Right Command` to transcribe and paste text into the focused input.
- Press `Esc` while recording to cancel (no transcription, no insertion).

## Config

Set values in `.env` (or shell env):

```bash
APP_ID="your_app_id"
ACCESS_TOKEN="your_access_token"
RESOURCE_ID="volc.bigasr.auc_turbo"
ASR_URL="https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash"
ASR_LANGUAGE="auto"
MAX_RECORD_SECONDS="180"
MIN_RECORD_MS="180"
```

## Run

```bash
swift run AudioInput
```

## Required macOS Permissions

- Microphone
- Accessibility
- Input Monitoring (depending on macOS version)
- Notifications (optional but recommended)

Without Accessibility/Input Monitoring permissions, global hotkeys and simulated paste may not work.
