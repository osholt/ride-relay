export const DISCOVERY_CATEGORIES = Object.freeze({
  twisty_highlight: Object.freeze({
    label: "Twisty highlights",
    colour: "#f97316",
    geometryType: "LineString",
  }),
  mountain_pass: Object.freeze({
    label: "Mountain passes",
    colour: "#0f9d8a",
    geometryType: "Point",
  }),
  good_biking_road: Object.freeze({
    label: "Good biking roads",
    colour: "#2583e9",
    geometryType: "LineString",
  }),
});

export const DISCOVERY_CATALOGUE_URL = "/data/discovery-catalogue.geojson";

export function filterDiscoveryFeatures(collection, bounds, categories) {
  const enabled = new Set(categories);
  if (!collection || collection.type !== "FeatureCollection") {
    return emptyFeatureCollection();
  }
  return {
    type: "FeatureCollection",
    features: collection.features.filter(
      (feature) =>
        enabled.has(feature?.properties?.category) &&
        featureIntersectsBounds(feature, bounds),
    ),
  };
}

export function discoveryFeatureAnchor(feature) {
  const coordinates = feature?.geometry?.coordinates;
  if (feature?.geometry?.type === "Point") return coordinates;
  if (feature?.geometry?.type !== "LineString" || !coordinates?.length) {
    return null;
  }
  return coordinates[Math.floor(coordinates.length / 2)];
}

export function discoveryRouteStop(feature) {
  const coordinate = discoveryFeatureAnchor(feature);
  if (!coordinate) return null;
  return {
    longitude: coordinate[0],
    latitude: coordinate[1],
    name:
      String(feature?.properties?.name || "").trim() ||
      DISCOVERY_CATEGORIES[feature?.properties?.category]?.label ||
      "Discovery highlight",
  };
}

export function nearbyDiscoveryFeatures(collection, coordinate, maximumKm = 5) {
  if (!Array.isArray(coordinate) || !collection?.features) return [];
  return collection.features
    .map((feature) => ({
      feature,
      distanceKm: haversineKm(coordinate, discoveryFeatureAnchor(feature)),
    }))
    .filter((entry) => entry.distanceKm <= maximumKm)
    .sort((a, b) => a.distanceKm - b.distanceKm);
}

export function emptyFeatureCollection() {
  return { type: "FeatureCollection", features: [] };
}

function featureIntersectsBounds(feature, bounds) {
  if (!bounds) return true;
  const coordinates =
    feature?.geometry?.type === "Point"
      ? [feature.geometry.coordinates]
      : feature?.geometry?.coordinates;
  if (!Array.isArray(coordinates)) return false;
  return coordinates.some(
    (coordinate) =>
      Array.isArray(coordinate) &&
      coordinate[0] >= bounds.west &&
      coordinate[0] <= bounds.east &&
      coordinate[1] >= bounds.south &&
      coordinate[1] <= bounds.north,
  );
}

function haversineKm(from, to) {
  if (!Array.isArray(to)) return Number.POSITIVE_INFINITY;
  const radians = (value) => (value * Math.PI) / 180;
  const latitudeDelta = radians(to[1] - from[1]);
  const longitudeDelta = radians(to[0] - from[0]);
  const startLatitude = radians(from[1]);
  const endLatitude = radians(to[1]);
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(startLatitude) *
      Math.cos(endLatitude) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}
