import assert from "node:assert/strict";
import test from "node:test";

import {
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
