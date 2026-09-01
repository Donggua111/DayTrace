const HOST_NAME = "com.daytrace.spike";
let nativePort = null;

function ensureNativePort() {
  if (nativePort) return nativePort;
  try {
    nativePort = chrome.runtime.connectNative(HOST_NAME);
    nativePort.onDisconnect.addListener(() => {
      nativePort = null;
    });
  } catch (_) {
    nativePort = null;
  }
  return nativePort;
}

function sanitizeUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== "string") return "Unknown";
  if (/^(chrome|chrome-extension|devtools|view-source):/i.test(rawUrl)) return "Browser Internal";
  if (/^file:/i.test(rawUrl)) return "Local File";

  try {
    const parsed = new URL(rawUrl);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return "Browser Internal";
    const hostname = parsed.hostname.toLowerCase().replace(/\.$/, "");
    if (!hostname || hostname.includes("/") || hostname.includes(":")) return "Unknown";
    return hostname;
  } catch (_) {
    return "Unknown";
  }
}

async function reportActiveDomain() {
  const tabs = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  const domain = sanitizeUrl(tabs[0] && tabs[0].url);
  const port = ensureNativePort();
  if (!port) return;
  port.postMessage({ schemaVersion: 1, type: "activeDomainChanged", domain });
}

chrome.tabs.onActivated.addListener(() => reportActiveDomain());
chrome.tabs.onUpdated.addListener((_tabId, changeInfo) => {
  if (changeInfo.status === "complete" || changeInfo.url) reportActiveDomain();
});
chrome.windows.onFocusChanged.addListener(() => reportActiveDomain());
chrome.runtime.onStartup.addListener(() => reportActiveDomain());
reportActiveDomain();
