const elements = {
  apiOrigin: document.querySelector("#admin-api-origin"),
  token: document.querySelector("#admin-token"),
  load: document.querySelector("#load-admin-queue"),
  login: document.querySelector("#admin-login"),
  queue: document.querySelector("#admin-queue"),
  queueItems: document.querySelector("#admin-queue-items"),
  refresh: document.querySelector("#refresh-admin-queue"),
  review: document.querySelector("#admin-review"),
  detail: document.querySelector("#admin-review-detail"),
  reason: document.querySelector("#moderation-reason"),
  status: document.querySelector("#admin-status"),
};

elements.apiOrigin.value = document
  .querySelector('meta[name="tec-discovery-api"]')
  ?.content?.replace(/\/$/, "") || "";
let adminToken = "";
let suggestions = [];
let selectedSuggestion = null;
let map = null;

elements.load.addEventListener("click", () => {
  adminToken = elements.token.value;
  elements.token.value = "";
  loadQueue();
});
elements.refresh.addEventListener("click", loadQueue);
document.querySelectorAll("[data-moderation]").forEach((button) => {
  button.addEventListener("click", () => moderate(button.dataset.moderation));
});

async function loadQueue() {
  setStatus("Loading private queue…");
  try {
    const response = await adminFetch("/api/v1/admin/discovery/suggestions");
    if (!response.ok) throw new Error(`Queue request failed (${response.status})`);
    suggestions = (await response.json()).suggestions;
    elements.login.hidden = true;
    elements.queue.hidden = false;
    renderQueue();
    setStatus("");
  } catch (error) {
    elements.login.hidden = false;
    setStatus(error.message, true);
  }
}

function renderQueue() {
  elements.queueItems.replaceChildren();
  if (!suggestions.length) {
    const empty = document.createElement("p");
    empty.textContent = "No pending suggestions.";
    elements.queueItems.append(empty);
    elements.review.hidden = true;
    return;
  }
  for (const suggestion of suggestions) {
    const button = document.createElement("button");
    button.className = "admin-queue-item";
    button.type = "button";
    button.innerHTML = `<strong></strong><span></span>`;
    button.querySelector("strong").textContent = suggestion.name;
    button.querySelector("span").textContent = `${suggestion.action} · ${suggestion.category.replaceAll("_", " ")}`;
    button.addEventListener("click", () => selectSuggestion(suggestion));
    elements.queueItems.append(button);
  }
}

function selectSuggestion(suggestion) {
  selectedSuggestion = suggestion;
  elements.review.hidden = false;
  elements.reason.value = "";
  elements.detail.replaceChildren();
  const title = document.createElement("h2");
  title.textContent = suggestion.name;
  const reason = document.createElement("p");
  reason.textContent = suggestion.reason;
  const metadata = document.createElement("p");
  metadata.textContent = `${suggestion.action} · ${suggestion.category.replaceAll("_", " ")} · submitted ${new Date(suggestion.submittedAt).toLocaleString()}`;
  elements.detail.append(title, metadata, reason);
  if (suggestion.evidenceUrl) {
    const evidence = document.createElement("a");
    evidence.href = suggestion.evidenceUrl;
    evidence.target = "_blank";
    evidence.rel = "noreferrer";
    evidence.textContent = "Open submitted evidence";
    elements.detail.append(evidence);
  }
  showGeometry(suggestion.geometry);
  findPossibleDuplicates(suggestion);
}

function showGeometry(geometry) {
  const points = geometry.type === "Point" ? [geometry.coordinates] : geometry.coordinates;
  const center = points[Math.floor(points.length / 2)];
  if (!map) {
    map = new maplibregl.Map({
      container: "admin-map",
      style: "https://tiles.openfreemap.org/styles/liberty",
      center,
      zoom: 12,
      attributionControl: true,
    });
    map.on("load", () => {
      map.addSource("candidate", { type: "geojson", data: candidateData(geometry) });
      map.addLayer({ id: "candidate-line", type: "line", source: "candidate", paint: { "line-color": "#f97316", "line-width": 6 } });
      map.addLayer({ id: "candidate-point", type: "circle", source: "candidate", paint: { "circle-color": "#f97316", "circle-radius": 9, "circle-stroke-color": "#171823", "circle-stroke-width": 3 } });
    });
  } else {
    map.getSource("candidate")?.setData(candidateData(geometry));
    map.easeTo({ center, zoom: 12 });
  }
}

async function findPossibleDuplicates(suggestion) {
  const points = suggestion.geometry.type === "Point" ? [suggestion.geometry.coordinates] : suggestion.geometry.coordinates;
  const [longitude, latitude] = points[Math.floor(points.length / 2)];
  const query = new URLSearchParams({
    west: longitude - 0.08,
    south: latitude - 0.05,
    east: longitude + 0.08,
    north: latitude + 0.05,
    categories: "twisty_highlight,mountain_pass,good_biking_road,biker_stop",
  });
  try {
    const response = await fetch(`${apiOrigin()}/api/v1/discovery/features?${query}`);
    if (!response.ok) return;
    const matches = (await response.json()).features;
    const note = document.createElement("p");
    note.className = "suggestion-nearby";
    note.textContent = matches.length
      ? `${matches.length} approved catalogue ${matches.length === 1 ? "entry is" : "entries are"} nearby; check for a duplicate before approval.`
      : "No approved community entries were found nearby.";
    elements.detail.append(note);
  } catch {
    // Duplicate assistance is advisory; moderation remains available.
  }
}

async function moderate(action) {
  if (!selectedSuggestion || elements.reason.value.trim().length < 3) {
    setStatus("Enter a moderation reason first.", true);
    return;
  }
  setStatus("Saving moderation decision…");
  const response = await adminFetch(
    `/api/v1/admin/discovery/suggestions/${selectedSuggestion.id}:moderate`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ action, reason: elements.reason.value.trim() }),
    },
  );
  if (!response.ok) {
    setStatus(`Moderation failed (${response.status}).`, true);
    return;
  }
  selectedSuggestion = null;
  elements.review.hidden = true;
  await loadQueue();
}

function adminFetch(path, options = {}) {
  const headers = new Headers(options.headers || {});
  headers.set("authorization", `Bearer ${adminToken}`);
  headers.set("accept", "application/json");
  return fetch(`${apiOrigin()}${path}`, { ...options, headers });
}

function apiOrigin() {
  return elements.apiOrigin.value.trim().replace(/\/$/, "");
}

function candidateData(geometry) {
  return { type: "Feature", properties: {}, geometry };
}

function setStatus(message, error = false) {
  elements.status.textContent = message;
  elements.status.classList.toggle("is-error", error);
}
