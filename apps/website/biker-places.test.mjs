import assert from "node:assert/strict";
import test from "node:test";

import {
  BIKER_PLACES,
  bikerPlacesGeoJson,
  normalizePlaceQuery,
  searchBikerPlaces,
} from "./biker-places.mjs";

test("place normalisation tolerates apostrophes and ampersands", () => {
  assert.equal(normalizePlaceQuery("King's Oak"), normalizePlaceQuery("Kings Oak"));
  assert.equal(
    normalizePlaceQuery("Leather & Lace"),
    normalizePlaceQuery("Leather and Lace"),
  );
});

test("catalogue finds biker stops using common name variants", () => {
  assert.equal(searchBikerPlaces("Chopper's Cafe")[0].name, "Choppers Cafe");
  assert.equal(
    searchBikerPlaces("Leather and Lace near Taunton")[0].name,
    "Leather and Lace Bar and Grill",
  );
  assert.equal(searchBikerPlaces("Kings Oak")[0].name, "King's Oak Academy car park");
});

test("every catalogue entry has a directly mappable location", () => {
  assert.equal(BIKER_PLACES.length, 294);
  assert.equal(
    BIKER_PLACES.filter((place) => place.source === "Bike + Brew Passport 2026")
      .length,
    291,
  );
  for (const withdrawnName of [
    "Blackham Station Cafe",
    "Garw Cafe",
    "Highway 39 Cafe and Lounge",
    "The View Coffee Shop",
  ]) {
    assert.ok(
      !BIKER_PLACES.some((place) => place.name === withdrawnName),
      `${withdrawnName} should stay excluded while absent from the current event map`,
    );
  }
  assert.ok(
    !BIKER_PLACES.some(
      (place) => place.latitude === 51.07752 && place.longitude === -1.48757,
    ),
    "The withdrawn Hampshire Crown Inn location should stay excluded",
  );
  const coordinateKeys = new Set();
  for (const place of BIKER_PLACES) {
    assert.ok(Number.isFinite(place.latitude), `${place.name} needs a latitude`);
    assert.ok(Number.isFinite(place.longitude), `${place.name} needs a longitude`);
    assert.ok(place.latitude >= -90 && place.latitude <= 90);
    assert.ok(place.longitude >= -180 && place.longitude <= 180);
    const coordinateKey = `${place.latitude},${place.longitude}`;
    assert.ok(
      !coordinateKeys.has(coordinateKey),
      `${place.name} duplicates another map point`,
    );
    coordinateKeys.add(coordinateKey);
    if (place.source) {
      assert.match(place.sourceUrl, /^https:\/\/ukbikercafes\.co\.uk\//);
      assert.match(place.googleMapUrl, /^https:\/\/www\.google\.com\/maps\/d\//);
    }
  }

  const geoJson = bikerPlacesGeoJson();
  assert.equal(geoJson.features.length, BIKER_PLACES.length);
  assert.deepEqual(geoJson.features[0].geometry.coordinates, [
    BIKER_PLACES[0].longitude,
    BIKER_PLACES[0].latitude,
  ]);
});
