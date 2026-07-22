import {
  buildGpx,
  formatDistance,
  formatDuration,
  gpxFileName,
} from "./planner-core.mjs";

const MAP_STYLE_URL = "https://tiles.openfreemap.org/styles/liberty";
const ROUTING_URL = "https://router.project-osrm.org";
const SEARCH_URL = "https://nominatim.openstreetmap.org/search";
const MAX_STOPS = 50;
const SEARCH_CACHE_KEY = "tec-planner-search-v1";
const SEARCH_CACHE_MAX_AGE = 7 * 24 * 60 * 60 * 1000;

const elements = {
  clearRoute: document.querySelector("#clear-route"),
  distance: document.querySelector("#route-distance"),
  download: document.querySelector("#download-gpx"),
  duration: document.querySelector("#route-duration"),
  emptyStops: document.querySelector("#empty-stops"),
  expand: document.querySelector("#map-expand"),
  expandLabel: document.querySelector(".map-expand-label"),
  mapInstructions: document.querySelector("#map-instructions"),
  mapShell: document.querySelector("#map-shell"),
  placeQuery: document.querySelector("#place-query"),
  placeSearch: document.querySelector("#place-search"),
  rideName: document.querySelector("#ride-name"),
  searchResults: document.querySelector("#search-results"),
  status: document.querySelector("#route-status"),
  stopList: document.querySelector("#stop-list"),
};

let stops = [];
let routeCoordinates = [];
let routeRequest = null;
let routeRequestSequence = 0;
let searchRequest = null;
let lastSearchAt = 0;
let stopSequence = 0;

const map = new maplibregl.Map({
  container: "map",
  style: MAP_STYLE_URL,
  center: [-2.5, 54.4],
  zoom: 5.1,
  attributionControl: false,
});

map.addControl(
  new maplibregl.NavigationControl({ showCompass: false }),
  "bottom-left",
);
map.addControl(
  new maplibregl.AttributionControl({ compact: true }),
  "bottom-left",
);

map.on("load", () => {
  map.addSource("route-draft", emptyLineSource());
  map.addLayer({
    id: "route-draft-line",
    type: "line",
    source: "route-draft",
    layout: { "line-cap": "round", "line-join": "round" },
    paint: {
      "line-color": "#ffad81",
      "line-width": 3,
      "line-dasharray": [1.5, 2],
      "line-opacity": 0.8,
    },
  });
  map.addSource("road-route", emptyLineSource());
  map.addLayer({
    id: "road-route-casing",
    type: "line",
    source: "road-route",
    layout: { "line-cap": "round", "line-join": "round" },
    paint: {
      "line-color": "#ffffff",
      "line-width": 9,
      "line-opacity": 0.86,
    },
  });
  map.addLayer({
    id: "road-route-line",
    type: "line",
    source: "road-route",
    layout: { "line-cap": "round", "line-join": "round" },
    paint: {
      "line-color": "#6d2ee8",
      "line-width": 6,
    },
  });
  updateMapLines();
});

map.on("click", (event) => {
  if (event.originalEvent.target.closest(".maplibregl-marker, .maplibregl-ctrl")) {
    return;
  }
  addStop({
    longitude: event.lngLat.lng,
    latitude: event.lngLat.lat,
    name: `Stop ${stops.length + 1}`,
  });
});

map.on("error", (event) => {
  if (event?.error) {
    setStatus("The map tiles could not be loaded. Check your connection and try again.", true);
  }
});

elements.placeSearch.addEventListener("submit", searchPlaces);
elements.stopList.addEventListener("input", editStop);
elements.stopList.addEventListener("change", commitCoordinateEdit);
elements.stopList.addEventListener("click", handleStopAction);
elements.clearRoute.addEventListener("click", clearRoute);
elements.download.addEventListener("click", downloadGpx);
elements.expand.addEventListener("click", toggleExpandedMap);
elements.rideName.addEventListener("input", updateDownloadState);
document.addEventListener("fullscreenchange", syncExpandedMapState);
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && elements.mapShell.classList.contains("is-expanded")) {
    setExpandedMap(false);
  }
});

function addStop({ longitude, latitude, name }) {
  if (stops.length >= MAX_STOPS) {
    setStatus(`A route can contain up to ${MAX_STOPS} stops.`, true);
    return;
  }
  if (!isCoordinate(longitude, latitude)) {
    setStatus("That place does not have a valid map position.", true);
    return;
  }

  const id = ++stopSequence;
  const markerElement = document.createElement("button");
  markerElement.className = "route-marker";
  markerElement.type = "button";
  markerElement.setAttribute("aria-label", `Edit ${name}`);
  markerElement.addEventListener("click", (event) => {
    event.stopPropagation();
    focusStop(id);
  });
  const marker = new maplibregl.Marker({
    element: markerElement,
    draggable: true,
    anchor: "center",
  })
    .setLngLat([longitude, latitude])
    .addTo(map);
  marker.on("dragend", () => {
    const stop = stops.find((item) => item.id === id);
    if (!stop) return;
    const position = marker.getLngLat();
    stop.longitude = position.lng;
    stop.latitude = position.lat;
    renderStops();
    routeStops();
  });

  stops.push({ id, longitude, latitude, name: cleanPlaceName(name), marker });
  renderStops();
  routeStops();
  if (stops.length === 1) map.flyTo({ center: [longitude, latitude], zoom: 11 });
}

function renderStops() {
  elements.stopList.replaceChildren();
  elements.emptyStops.hidden = stops.length > 0;
  elements.clearRoute.disabled = stops.length === 0;
  elements.mapInstructions.textContent = stops.length
    ? "Tap to add another stop"
    : "Tap the map to add a route point";

  stops.forEach((stop, index) => {
    stop.marker.getElement().textContent = String(index + 1);
    stop.marker
      .getElement()
      .setAttribute("aria-label", `Edit ${stop.name || `stop ${index + 1}`}`);

    const item = document.createElement("li");
    item.className = "stop-card";
    item.dataset.stopId = String(stop.id);
    item.innerHTML = `
      <span class="stop-number" aria-hidden="true">${index + 1}</span>
      <div class="stop-fields">
        <div class="stop-name-field">
          <label for="stop-name-${stop.id}">Stop ${index + 1} name</label>
          <input id="stop-name-${stop.id}" data-field="name" maxlength="100" value="${escapeAttribute(stop.name)}" />
        </div>
        <div class="coordinate-row">
          <div class="coordinate-field">
            <label for="stop-lat-${stop.id}">Latitude</label>
            <input id="stop-lat-${stop.id}" data-field="latitude" inputmode="decimal" value="${stop.latitude.toFixed(6)}" aria-label="Stop ${index + 1} latitude" />
          </div>
          <div class="coordinate-field">
            <label for="stop-lon-${stop.id}">Longitude</label>
            <input id="stop-lon-${stop.id}" data-field="longitude" inputmode="decimal" value="${stop.longitude.toFixed(6)}" aria-label="Stop ${index + 1} longitude" />
          </div>
        </div>
        <div class="stop-actions">
          <button class="stop-action" type="button" data-action="up" ${index === 0 ? "disabled" : ""}>Move up</button>
          <button class="stop-action" type="button" data-action="down" ${index === stops.length - 1 ? "disabled" : ""}>Move down</button>
          <button class="stop-action" type="button" data-action="locate">Show</button>
          <button class="stop-action" type="button" data-action="remove">Remove</button>
        </div>
      </div>`;
    elements.stopList.append(item);
  });
  updateMapLines();
  updateDownloadState();
}

function editStop(event) {
  const item = event.target.closest("[data-stop-id]");
  const field = event.target.dataset.field;
  if (!item || field !== "name") return;
  const stop = findStop(item);
  if (!stop) return;
  stop.name = event.target.value;
  stop.marker
    .getElement()
    .setAttribute("aria-label", `Edit ${stop.name || "unnamed stop"}`);
}

function commitCoordinateEdit(event) {
  const item = event.target.closest("[data-stop-id]");
  const field = event.target.dataset.field;
  if (!item || !["latitude", "longitude"].includes(field)) return;
  const stop = findStop(item);
  if (!stop) return;
  const value = Number(event.target.value);
  const longitude = field === "longitude" ? value : stop.longitude;
  const latitude = field === "latitude" ? value : stop.latitude;
  if (!isCoordinate(longitude, latitude)) {
    event.target.value = stop[field].toFixed(6);
    setStatus("Latitude must be -90 to 90 and longitude -180 to 180.", true);
    return;
  }
  stop[field] = value;
  stop.marker.setLngLat([stop.longitude, stop.latitude]);
  routeStops();
}

function handleStopAction(event) {
  const button = event.target.closest("[data-action]");
  const item = event.target.closest("[data-stop-id]");
  if (!button || !item) return;
  const index = stops.findIndex((stop) => stop.id === Number(item.dataset.stopId));
  if (index === -1) return;

  switch (button.dataset.action) {
    case "up":
      if (index > 0) [stops[index - 1], stops[index]] = [stops[index], stops[index - 1]];
      break;
    case "down":
      if (index < stops.length - 1) {
        [stops[index], stops[index + 1]] = [stops[index + 1], stops[index]];
      }
      break;
    case "locate":
      map.flyTo({ center: [stops[index].longitude, stops[index].latitude], zoom: 14 });
      focusStop(stops[index].id);
      return;
    case "remove":
      stops[index].marker.remove();
      stops.splice(index, 1);
      break;
    default:
      return;
  }
  renderStops();
  routeStops();
}

function clearRoute() {
  if (stops.length === 0) return;
  if (!window.confirm("Remove every stop from this route?")) return;
  routeRequest?.abort();
  stops.forEach((stop) => stop.marker.remove());
  stops = [];
  routeCoordinates = [];
  renderStops();
  setSummary();
  setStatus("Add at least two stops to generate a route.");
}

async function routeStops() {
  routeRequest?.abort();
  routeRequestSequence += 1;
  const requestSequence = routeRequestSequence;
  routeCoordinates = [];
  setSummary();
  updateMapLines();
  updateDownloadState();

  if (stops.length < 2) {
    setStatus("Add at least two stops to generate a route.");
    return;
  }

  routeRequest = new AbortController();
  setStatus("Joining your stops by road…");
  const coordinates = stops
    .map((stop) => `${stop.longitude.toFixed(6)},${stop.latitude.toFixed(6)}`)
    .join(";");
  const url = new URL(`/route/v1/driving/${coordinates}`, ROUTING_URL);
  url.searchParams.set("overview", "full");
  url.searchParams.set("geometries", "geojson");
  url.searchParams.set("steps", "false");

  try {
    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      signal: routeRequest.signal,
    });
    if (!response.ok) throw new Error(`Routing failed (${response.status}).`);
    const data = await response.json();
    const route = data?.routes?.[0];
    if (data?.code !== "Ok" || !Array.isArray(route?.geometry?.coordinates)) {
      throw new Error(data?.message || "No road route was found for those stops.");
    }
    if (requestSequence !== routeRequestSequence) return;
    routeCoordinates = route.geometry.coordinates;
    setSummary(route.distance, route.duration);
    updateMapLines();
    updateDownloadState();
    setStatus("Road route ready. You can keep editing or download the GPX file.");
    fitRoute();
  } catch (error) {
    if (error.name === "AbortError") return;
    setStatus(
      "The road route could not be generated. Move a stop nearer a road or try again.",
      true,
    );
  }
}

function updateMapLines() {
  if (!map.isStyleLoaded()) return;
  const draft = stops.map((stop) => [stop.longitude, stop.latitude]);
  map.getSource("route-draft")?.setData(lineData(draft));
  map.getSource("road-route")?.setData(lineData(routeCoordinates));
}

function setSummary(distance, duration) {
  elements.distance.textContent = formatDistance(distance);
  elements.duration.textContent = formatDuration(duration);
}

function setStatus(message, isError = false) {
  elements.status.textContent = message;
  elements.status.classList.toggle("is-error", isError);
}

function updateDownloadState() {
  elements.download.disabled =
    !elements.rideName.value.trim() || stops.length < 2 || routeCoordinates.length < 2;
}

function downloadGpx() {
  try {
    const rideName = elements.rideName.value.trim();
    const gpx = buildGpx({ rideName, stops, routeCoordinates, createdAt: new Date() });
    const blob = new Blob([gpx], { type: "application/gpx+xml;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = gpxFileName(rideName);
    document.body.append(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
    setStatus(`${link.download} downloaded and ready to import into the app.`);
  } catch (error) {
    setStatus(error.message || "The GPX file could not be created.", true);
  }
}

async function searchPlaces(event) {
  event.preventDefault();
  const query = elements.placeQuery.value.trim();
  if (query.length < 2) {
    renderSearchMessage("Enter at least two characters.");
    return;
  }

  const cached = getCachedSearch(query);
  if (cached) {
    renderSearchResults(cached);
    return;
  }
  if (Date.now() - lastSearchAt < 1000) {
    renderSearchMessage("Please wait a moment before searching again.");
    return;
  }

  searchRequest?.abort();
  searchRequest = new AbortController();
  lastSearchAt = Date.now();
  renderSearchMessage("Searching…");
  const url = new URL(SEARCH_URL);
  url.searchParams.set("q", query);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("limit", "5");
  url.searchParams.set("addressdetails", "0");
  url.searchParams.set("email", "privacy@tailendcharlie.app");
  url.searchParams.set("accept-language", document.documentElement.lang || "en-GB");

  try {
    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      signal: searchRequest.signal,
    });
    if (!response.ok) throw new Error("Search is unavailable.");
    const data = await response.json();
    const results = Array.isArray(data)
      ? data
          .map((result) => ({
            latitude: Number(result.lat),
            longitude: Number(result.lon),
            name: String(result.display_name || "Search result"),
          }))
          .filter((result) => isCoordinate(result.longitude, result.latitude))
      : [];
    cacheSearch(query, results);
    renderSearchResults(results);
  } catch (error) {
    if (error.name === "AbortError") return;
    renderSearchMessage("Place search is unavailable. You can still tap the map.");
  }
}

function renderSearchResults(results) {
  elements.searchResults.replaceChildren();
  if (results.length === 0) {
    renderSearchMessage("No places found. Try a town, postcode or landmark.");
    return;
  }
  for (const result of results) {
    const button = document.createElement("button");
    button.className = "search-result";
    button.type = "button";
    button.textContent = result.name;
    button.addEventListener("click", () => {
      addStop(result);
      elements.searchResults.replaceChildren();
      elements.placeQuery.value = "";
      map.flyTo({ center: [result.longitude, result.latitude], zoom: 13 });
    });
    elements.searchResults.append(button);
  }
  const attribution = document.createElement("div");
  attribution.className = "search-attribution";
  attribution.innerHTML =
    'Search © <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">OpenStreetMap contributors</a>';
  elements.searchResults.append(attribution);
}

function renderSearchMessage(message) {
  elements.searchResults.replaceChildren();
  const paragraph = document.createElement("p");
  paragraph.className = "search-message";
  paragraph.textContent = message;
  elements.searchResults.append(paragraph);
}

function getCachedSearch(query) {
  try {
    const cache = JSON.parse(localStorage.getItem(SEARCH_CACHE_KEY) || "{}");
    const entry = cache[query.toLowerCase()];
    return entry && Date.now() - entry.savedAt < SEARCH_CACHE_MAX_AGE
      ? entry.results
      : null;
  } catch {
    return null;
  }
}

function cacheSearch(query, results) {
  try {
    const cache = JSON.parse(localStorage.getItem(SEARCH_CACHE_KEY) || "{}");
    const entries = Object.entries(cache)
      .filter(([, entry]) => Date.now() - entry.savedAt < SEARCH_CACHE_MAX_AGE)
      .slice(-19);
    localStorage.setItem(
      SEARCH_CACHE_KEY,
      JSON.stringify({
        ...Object.fromEntries(entries),
        [query.toLowerCase()]: { savedAt: Date.now(), results },
      }),
    );
  } catch {
    // Search still works when storage is unavailable or full.
  }
}

async function toggleExpandedMap() {
  const isExpanded =
    document.fullscreenElement === elements.mapShell ||
    elements.mapShell.classList.contains("is-expanded");
  if (isExpanded) {
    if (document.fullscreenElement) await document.exitFullscreen();
    setExpandedMap(false);
    return;
  }

  try {
    if (elements.mapShell.requestFullscreen) {
      await elements.mapShell.requestFullscreen();
      syncExpandedMapState();
    } else {
      setExpandedMap(true);
    }
  } catch {
    setExpandedMap(true);
  }
}

function syncExpandedMapState() {
  setExpandedMap(document.fullscreenElement === elements.mapShell);
}

function setExpandedMap(isExpanded) {
  elements.mapShell.classList.toggle("is-expanded", isExpanded);
  elements.expand.setAttribute("aria-pressed", String(isExpanded));
  elements.expand.setAttribute(
    "aria-label",
    isExpanded ? "Close full-screen map" : "Open map full screen",
  );
  elements.expandLabel.textContent = isExpanded ? "Close" : "Full screen";
  document.body.style.overflow = isExpanded ? "hidden" : "";
  window.setTimeout(() => map.resize(), 0);
}

function fitRoute() {
  if (routeCoordinates.length < 2) return;
  const bounds = routeCoordinates.reduce(
    (current, coordinate) => current.extend(coordinate),
    new maplibregl.LngLatBounds(routeCoordinates[0], routeCoordinates[0]),
  );
  map.fitBounds(bounds, { padding: 70, maxZoom: 14, duration: 700 });
}

function focusStop(id) {
  document.querySelector(`[data-stop-id="${id}"] input`)?.focus({ preventScroll: false });
}

function findStop(item) {
  return stops.find((stop) => stop.id === Number(item.dataset.stopId));
}

function cleanPlaceName(name) {
  const text = String(name || "").trim();
  return text.length > 100 ? `${text.slice(0, 97)}…` : text;
}

function isCoordinate(longitude, latitude) {
  return (
    Number.isFinite(longitude) &&
    Number.isFinite(latitude) &&
    longitude >= -180 &&
    longitude <= 180 &&
    latitude >= -90 &&
    latitude <= 90
  );
}

function escapeAttribute(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function emptyLineSource() {
  return { type: "geojson", data: lineData([]) };
}

function lineData(coordinates) {
  return {
    type: "FeatureCollection",
    features:
      coordinates.length < 2
        ? []
        : [
            {
              type: "Feature",
              properties: {},
              geometry: { type: "LineString", coordinates },
            },
          ],
  };
}
