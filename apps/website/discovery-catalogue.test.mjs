import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  discoveryFeatureAnchor,
  discoveryRouteStop,
  filterDiscoveryFeatures,
  nearbyDiscoveryFeatures,
} from "./discovery-catalogue.mjs";

const collection = {
  type: "FeatureCollection",
  features: [
    {
      type: "Feature",
      properties: { id: "pass", category: "mountain_pass" },
      geometry: { type: "Point", coordinates: [-3.11, 52.01] },
    },
    {
      type: "Feature",
      properties: { id: "road", category: "good_biking_road" },
      geometry: {
        type: "LineString",
        coordinates: [
          [-3.2, 52],
          [-3.1, 52.1],
          [-3, 52.2],
        ],
      },
    },
  ],
};

test("filters independently enabled discovery categories to the viewport", () => {
  assert.deepEqual(
    filterDiscoveryFeatures(
      collection,
      { west: -3.15, south: 51.9, east: -3.05, north: 52.05 },
      ["mountain_pass"],
    ).features.map((feature) => feature.properties.id),
    ["pass"],
  );
  assert.equal(filterDiscoveryFeatures(collection, null, []).features.length, 0);
});

test("uses the midpoint of a road as its route-via-here anchor", () => {
  assert.deepEqual(discoveryFeatureAnchor(collection.features[1]), [-3.1, 52.1]);
  const existingStops = [{ name: "Start", longitude: -3.3, latitude: 51.9 }];
  existingStops.push(discoveryRouteStop(collection.features[1]));
  assert.deepEqual(existingStops, [
    { name: "Start", longitude: -3.3, latitude: 51.9 },
    { name: "Good biking roads", longitude: -3.1, latitude: 52.1 },
  ]);
});

test("finds nearby published entries before a suggestion is queued", () => {
  const nearby = nearbyDiscoveryFeatures(collection, [-3.11, 52.01], 2);
  assert.deepEqual(nearby.map((entry) => entry.feature.properties.id), ["pass"]);
});

test("web and mobile ship the same reviewed proof-of-concept geometry", () => {
  const web = JSON.parse(
    readFileSync(new URL("./data/discovery-catalogue.geojson", import.meta.url)),
  );
  const mobile = JSON.parse(
    readFileSync(
      new URL("../mobile/assets/discovery_catalogue.geojson", import.meta.url),
    ),
  );
  const geometryById = (catalogue) =>
    Object.fromEntries(
      catalogue.features.map((feature) => [
        feature.properties.id,
        feature.geometry,
      ]),
    );
  assert.deepEqual(geometryById(mobile), geometryById(web));
});
