const SERVER_BASE = "http://localhost:6789";
const MENU_ID = "sdm-download-link";
const STORAGE_KEY = "autoCaptureDownloads";
const HEALTH_ALARM = "sdm-health-ping";
const HEALTH_PING_FAST_MS = 4000;
const HEALTH_PING_SLOW_MS = 15000;
const BADGE_CONNECTED_COLOR = "#34C759";
const BADGE_OFFLINE_COLOR = "#8E8E93";

let healthPingTimer = null;
let appReachable = false;

function setupContextMenu() {
  chrome.contextMenus.remove(MENU_ID, () => {
    chrome.contextMenus.create({
      id: MENU_ID,
      title: "Download with Swift Download Manager",
      contexts: ["link"],
    });
  });
}

chrome.runtime.onInstalled.addListener(() => {
  setupContextMenu();

  updateConnectionBadge(false);
  scheduleHealthPing(0);
  chrome.alarms.create(HEALTH_ALARM, { delayInMinutes: 0.5 });
});

chrome.runtime.onStartup.addListener(() => {
  setupContextMenu();
  updateConnectionBadge(false);
  scheduleHealthPing(0);
  chrome.alarms.create(HEALTH_ALARM, { delayInMinutes: 0.5 });
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name !== HEALTH_ALARM) {
    return;
  }

  pingApp().then((ok) => {
    chrome.alarms.create(HEALTH_ALARM, { delayInMinutes: ok ? 1 : 0.5 });
  });
});

chrome.contextMenus.onClicked.addListener(async (info) => {
  if (info.menuItemId !== MENU_ID || !info.linkUrl) {
    return;
  }

  await sendToApp(info.linkUrl, undefined, {
    referrer: info.pageUrl,
    silentOnSuccess: false,
  });
});

chrome.downloads.onCreated.addListener(async (downloadItem) => {
  const enabled = await isAutoCaptureEnabled();
  if (!enabled) {
    return;
  }

  const url = downloadItem.url;
  if (!isHttpUrl(url)) {
    return;
  }

  const filename = downloadItem.filename || undefined;
  const result = await sendToApp(url, filename, {
    referrer: downloadItem.referrer,
    silentOnSuccess: true,
  });

  if (!result.ok) {
    return;
  }

  try {
    await chrome.downloads.cancel(downloadItem.id);
  } catch {
    // Download may already be finished or cancelled.
  }
});

scheduleHealthPing(0);
chrome.alarms.create(HEALTH_ALARM, { delayInMinutes: 0.5 });
updateConnectionBadge(false);
setupContextMenu();

function updateConnectionBadge(reachable) {
  if (reachable) {
    chrome.action.setBadgeText({ text: "✓" });
    chrome.action.setBadgeBackgroundColor({ color: BADGE_CONNECTED_COLOR });
    chrome.action.setTitle({ title: "Swift Download Manager — App connected" });
    return;
  }

  chrome.action.setBadgeText({ text: "–" });
  chrome.action.setBadgeBackgroundColor({ color: BADGE_OFFLINE_COLOR });
  chrome.action.setTitle({ title: "Swift Download Manager — App not reachable" });
}

function scheduleHealthPing(delayMs) {
  clearTimeout(healthPingTimer);
  healthPingTimer = setTimeout(async () => {
    await pingApp();
    scheduleHealthPing(appReachable ? HEALTH_PING_SLOW_MS : HEALTH_PING_FAST_MS);
  }, delayMs);
}

async function pingApp() {
  try {
    const response = await fetch(`${SERVER_BASE}/ping`, {
      method: "GET",
      cache: "no-store",
      headers: { "X-SDM-Handshake": "extension" },
    });
    appReachable = response.ok;
    updateConnectionBadge(appReachable);
    return appReachable;
  } catch {
    appReachable = false;
    updateConnectionBadge(false);
    return false;
  }
}

async function isAutoCaptureEnabled() {
  const result = await chrome.storage.sync.get({ [STORAGE_KEY]: false });
  return result[STORAGE_KEY] === true;
}

function isHttpUrl(url) {
  const lower = url.toLowerCase();
  return lower.startsWith("http://") || lower.startsWith("https://");
}

async function buildBrowserHeaders(url) {
  const headers = {};

  try {
    const cookies = await chrome.cookies.getAll({ url });
    if (cookies.length > 0) {
      headers.Cookie = cookies.map((c) => `${c.name}=${c.value}`).join("; ");
    }
  } catch {
    // Cookie access may be unavailable for some URLs.
  }

  return headers;
}

async function sendToApp(url, filename, { referrer, silentOnSuccess = false } = {}) {
  await pingApp();

  const body = { url };
  if (filename) {
    body.filename = filename;
  }
  if (referrer) {
    body.referrer = referrer;
  }

  const browserHeaders = await buildBrowserHeaders(url);
  if (Object.keys(browserHeaders).length > 0) {
    body.headers = browserHeaders;
  }

  try {
    const response = await fetch(`${SERVER_BASE}/add`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (response.ok) {
      appReachable = true;
      updateConnectionBadge(true);
      const payload = await response.json().catch(() => ({}));
      if (!silentOnSuccess) {
        const title = payload.started ? "Download started" : "Download sent for confirmation";
        const message = payload.started
          ? truncate(url)
          : "Confirm the download in Swift Download Manager.";
        notify(title, message);
      }
      return { ok: true };
    }

    const payload = await response.json().catch(() => ({}));
    notify("Download failed", payload.error || `Server error (${response.status})`);
    return { ok: false, error: payload.error };
  } catch {
    appReachable = false;
    updateConnectionBadge(false);
    notify(
      "Swift Download Manager is not running",
      "Launch the app and try again."
    );
    return { ok: false, error: "app_not_running" };
  }
}

function notify(title, message) {
  chrome.notifications.create({
    type: "basic",
    iconUrl: "icons/icon128.png",
    title,
    message,
  });
}

function truncate(text, max = 120) {
  return text.length > max ? `${text.slice(0, max)}…` : text;
}
