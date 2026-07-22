const XML_ENTITIES = Object.freeze({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&apos;",
});

export function escapeXml(value) {
  return String(value).replace(/[&<>"']/g, (character) => XML_ENTITIES[character]);
}

export function gpxFileName(rideName) {
  const slug = String(rideName)
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return `${slug || "tail-end-charlie-route"}.gpx`;
}

export function formatDistance(metres) {
  if (!Number.isFinite(metres) || metres < 0) return "—";
  const miles = metres / 1609.344;
  return `${miles < 10 ? miles.toFixed(1) : Math.round(miles)} mi`;
}

export function formatDuration(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return "—";
  const totalMinutes = Math.round(seconds / 60);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours === 0) return `${minutes} min`;
  return minutes === 0 ? `${hours} hr` : `${hours} hr ${minutes} min`;
}

export function buildGpx({ rideName, stops, routeCoordinates, createdAt }) {
  const safeName = String(rideName).trim();
  if (!safeName) throw new Error("Name the ride before downloading it.");
  if (!Array.isArray(stops) || stops.length < 2) {
    throw new Error("Add at least two stops before downloading the GPX file.");
  }
  if (!Array.isArray(routeCoordinates) || routeCoordinates.length < 2) {
    throw new Error("Generate a road route before downloading the GPX file.");
  }

  const timestamp = (createdAt instanceof Date ? createdAt : new Date(createdAt))
    .toISOString();
  const waypoints = stops
    .map((stop, index) => {
      validateCoordinate(stop.longitude, stop.latitude);
      const name = String(stop.name).trim() || `Stop ${index + 1}`;
      return [
        `  <wpt lat="${formatCoordinate(stop.latitude)}" lon="${formatCoordinate(stop.longitude)}">`,
        `    <name>${escapeXml(name)}</name>`,
        "    <sym>Flag</sym>",
        "  </wpt>",
      ].join("\n");
    })
    .join("\n");
  const trackPoints = routeCoordinates
    .map(([longitude, latitude]) => {
      validateCoordinate(longitude, latitude);
      return `      <trkpt lat="${formatCoordinate(latitude)}" lon="${formatCoordinate(longitude)}" />`;
    })
    .join("\n");

  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<gpx version="1.1" creator="Tail End Charlie" xmlns="http://www.topografix.com/GPX/1/1">',
    "  <metadata>",
    `    <name>${escapeXml(safeName)}</name>`,
    "    <desc>Road-following group ride planned at tailendcharlie.app.</desc>",
    `    <time>${timestamp}</time>`,
    "  </metadata>",
    waypoints,
    "  <trk>",
    `    <name>${escapeXml(safeName)}</name>`,
    "    <trkseg>",
    trackPoints,
    "    </trkseg>",
    "  </trk>",
    "</gpx>",
    "",
  ].join("\n");
}

function validateCoordinate(longitude, latitude) {
  if (
    !Number.isFinite(longitude) ||
    !Number.isFinite(latitude) ||
    longitude < -180 ||
    longitude > 180 ||
    latitude < -90 ||
    latitude > 90
  ) {
    throw new Error("The route contains an invalid coordinate.");
  }
}

function formatCoordinate(value) {
  return Number(value).toFixed(7);
}
