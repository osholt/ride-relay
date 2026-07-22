import assert from "node:assert/strict";
import test from "node:test";

import {
  buildGpx,
  escapeXml,
  formatDistance,
  formatDuration,
  gpxFileName,
} from "./planner-core.mjs";

test("buildGpx creates app-compatible GPX metadata, waypoints and track", () => {
  const gpx = buildGpx({
    rideName: "Peaks & Dales",
    stops: [
      { name: "Start <cafe>", longitude: -2.12345678, latitude: 53.12345678 },
      { name: "Finish", longitude: -1.98765432, latitude: 53.23456789 },
    ],
    routeCoordinates: [
      [-2.12345678, 53.12345678],
      [-1.98765432, 53.23456789],
    ],
    createdAt: new Date("2026-07-22T10:30:00.000Z"),
  });

  assert.match(gpx, /version="1\.1" creator="Tail End Charlie"/);
  assert.match(gpx, /<name>Peaks &amp; Dales<\/name>/);
  assert.match(gpx, /<name>Start &lt;cafe&gt;<\/name>/);
  assert.match(gpx, /<wpt lat="53\.1234568" lon="-2\.1234568">/);
  assert.match(gpx, /<trkpt lat="53\.2345679" lon="-1\.9876543" \/>/);
  assert.match(gpx, /<time>2026-07-22T10:30:00\.000Z<\/time>/);
});

test("buildGpx requires a named, routed ride", () => {
  assert.throws(
    () =>
      buildGpx({
        rideName: " ",
        stops: [{}, {}],
        routeCoordinates: [[0, 0], [1, 1]],
        createdAt: new Date(),
      }),
    /Name the ride/,
  );
  assert.throws(
    () =>
      buildGpx({
        rideName: "Ride",
        stops: [{ name: "A", longitude: 0, latitude: 0 }],
        routeCoordinates: [[0, 0], [1, 1]],
        createdAt: new Date(),
      }),
    /at least two stops/,
  );
});

test("helpers produce safe names and concise route summaries", () => {
  assert.equal(escapeXml(`A & B's <ride>`), "A &amp; B&apos;s &lt;ride&gt;");
  assert.equal(gpxFileName("  Côte & Coast  "), "cote-coast.gpx");
  assert.equal(gpxFileName("!!!"), "tail-end-charlie-route.gpx");
  assert.equal(formatDistance(16093.44), "10 mi");
  assert.equal(formatDistance(8046.72), "5.0 mi");
  assert.equal(formatDuration(5400), "1 hr 30 min");
  assert.equal(formatDuration(1200), "20 min");
});
