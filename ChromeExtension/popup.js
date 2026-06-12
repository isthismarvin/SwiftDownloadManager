const SERVER_BASE = "http://localhost:6789";
const STORAGE_KEY = "autoCaptureDownloads";

const toggle = document.getElementById("auto-capture");
const statusEl = document.getElementById("connection-status");
const statusLabel = statusEl.querySelector(".status-label");

document.addEventListener("DOMContentLoaded", async () => {
  await loadToggle();
  await checkConnection();
});

toggle.addEventListener("change", async () => {
  await chrome.storage.sync.set({ [STORAGE_KEY]: toggle.checked });
});

async function loadToggle() {
  const result = await chrome.storage.sync.get({ [STORAGE_KEY]: false });
  toggle.checked = result[STORAGE_KEY] === true;
}

async function checkConnection() {
  setStatus("checking", "Checking connection…");

  try {
    const response = await fetch(`${SERVER_BASE}/ping`, {
      method: "GET",
      cache: "no-store",
      headers: { "X-SDM-Handshake": "extension" },
    });
    if (!response.ok) {
      throw new Error("not ok");
    }

    setStatus("connected", "App connected");
  } catch {
    setStatus("disconnected", "App not reachable — launch the app");
  }
}

function setStatus(state, label) {
  statusEl.className = `status-pill status-${state}`;
  statusLabel.textContent = label;
}
