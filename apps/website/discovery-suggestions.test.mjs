import assert from "node:assert/strict";
import test from "node:test";

import {
  createSuggestionDraft,
  decodeSuggestionQueue,
  encodeSuggestionQueue,
  submissionPayload,
} from "./discovery-suggestions.mjs";

const now = Date.UTC(2026, 6, 22, 12);

test("suggestion drafts survive an offline queue round trip", () => {
  const draft = createSuggestionDraft(
    {
      category: "mountain_pass",
      name: "Test pass",
      reason: "Signed at the summit",
      longitude: -3.11,
      latitude: 52.01,
    },
    now,
    () => "submission-1",
  );
  assert.deepEqual(decodeSuggestionQueue(encodeSuggestionQueue([draft]), now), [draft]);
  assert.equal(submissionPayload(draft).status, undefined);
});

test("malformed or stale local suggestions are discarded", () => {
  assert.deepEqual(decodeSuggestionQueue("broken", now), []);
  assert.throws(() =>
    createSuggestionDraft({
      category: "motorway",
      name: "No",
      longitude: 999,
      latitude: 52,
    }),
  );
});

test("road suggestions preserve a selected road-following line", () => {
  const draft = createSuggestionDraft(
    {
      category: "good_biking_road",
      name: "Test road",
      reason: "A useful continuous rural section",
      geometry: {
        type: "LineString",
        coordinates: [
          [-3.2, 52],
          [-3.1, 52.1],
          [-3, 52.2],
        ],
      },
    },
    now,
    () => "road-1",
  );
  assert.equal(draft.geometry.type, "LineString");
  assert.equal(draft.geometry.coordinates.length, 3);
});
