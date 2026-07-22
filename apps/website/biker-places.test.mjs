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
    "Leather & Lace Bar and Grill",
  );
  assert.equal(searchBikerPlaces("Kings Oak")[0].name, "King's Oak Academy car park");
});

test("every catalogue entry has a directly mappable location", () => {
  assert.equal(BIKER_PLACES.length, 18);
  for (const place of BIKER_PLACES) {
    assert.ok(Number.isFinite(place.latitude), `${place.name} needs a latitude`);
    assert.ok(Number.isFinite(place.longitude), `${place.name} needs a longitude`);
    assert.ok(place.latitude >= -90 && place.latitude <= 90);
    assert.ok(place.longitude >= -180 && place.longitude <= 180);
  }

  const geoJson = bikerPlacesGeoJson();
  assert.equal(geoJson.features.length, BIKER_PLACES.length);
  assert.deepEqual(geoJson.features[0].geometry.coordinates, [
    BIKER_PLACES[0].longitude,
    BIKER_PLACES[0].latitude,
  ]);
});
