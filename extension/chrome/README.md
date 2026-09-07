# DayTrace Chrome Technical Spike

This unpacked Manifest V3 extension requires only `tabs` and `nativeMessaging`.
It sends a sanitized hostname, `Browser Internal`, `Local File`, or `Unknown`.
It never sends the full URL, path, query string, title, or page content.

Load this directory from `chrome://extensions` with Developer mode enabled. The
current development profile ID is:

```text
mmnoopahcchjobiajnhembdlipkhbjgo
```

Install the Native Messaging manifest with
`scripts/spike/install-native-host.sh`; the installer rejects other IDs so a
stale profile identity cannot silently become the allowed origin.
