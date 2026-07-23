import { BIKE_AND_BREW_PLACES } from "./bike-and-brew-places.mjs";

const CURATED_BIKER_PLACES = Object.freeze([
  {
    name: "King's Oak Academy car park",
    address: "Brook Road, Kingswood, Bristol BS15 4JT",
    latitude: 51.462674,
    longitude: -2.484519,
    aliases: ["Kings Oak", "Kingswood start"],
  },
  {
    name: "Cross Hands Hotel car park",
    address: "Tetbury Road, Old Sodbury, Bristol BS37 6RJ",
    latitude: 51.528729,
    longitude: -2.342245,
    aliases: ["Cross Hands", "Old Sodbury"],
  },
  {
    name: "Leather & Lace Bar and Grill",
    address: "114 Broadway, Chilton Polden, Bridgwater TA7 9EW",
    latitude: 51.1528,
    longitude: -2.888,
    aliases: ["Leather and Lace", "Leather Lace", "Taunton biker cafe"],
  },
  {
    name: "Choppers Cafe",
    address: "A338, Marlborough SN8 3RT",
    latitude: 51.3384772,
    longitude: -1.6741862,
    aliases: ["Chopper's Cafe", "Chopper Cafe"],
  },
  {
    name: "Ace Cafe London",
    address: "Ace Corner, North Circular Road, London NW10 7UD",
    latitude: 51.5412726,
    longitude: -0.2776857,
    aliases: ["Ace Cafe"],
  },
  {
    name: "Loomies Moto Cafe",
    address: "West Meon Hut, Petersfield GU32 1JX",
    latitude: 51.0304331,
    longitude: -1.0757297,
    aliases: ["Loomies"],
  },
  {
    name: "Sammy's Pit Stop",
    address: "Sammy Miller Museum, New Milton BH25 5SZ",
    latitude: 50.7657167,
    longitude: -1.6733903,
    aliases: ["Sammy Miller Cafe"],
  },
  {
    name: "The Bikers Loft",
    address: "Ventura Place, Poole BH16 5SW",
    latitude: 50.734976,
    longitude: -2.0201387,
    aliases: ["Bikers Loft"],
  },
  {
    name: "Harry's Cafe at Fowlers",
    address: "12 Bath Road, Bristol BS4 3DR",
    latitude: 51.4466279,
    longitude: -2.5813014,
    aliases: ["Fowlers Cafe", "Harrys Cafe"],
  },
  {
    name: "Westcountry Choppers at Explorers Hangout",
    address: "Unit 25F, Merton Road, Bishopston, Bristol BS7 8TL",
    latitude: 51.482122,
    longitude: -2.585891,
    aliases: ["Westcountry Choppers", "Explorers Hangout"],
  },
  {
    name: "Fuel Stop Cafe A27",
    address: "Chichester Bypass, Chichester PO19 8JH",
    latitude: 50.827641,
    longitude: -0.7566195,
    aliases: ["Fuel Stop Chichester"],
  },
  {
    name: "Cotswold Cafe / Pats Baps",
    address: "Unit 4, London Road, Little Compton GL56 0RR",
    latitude: 51.972472,
    longitude: -1.633504,
    aliases: ["Pats Baps", "Cotswold Cafe"],
  },
  {
    name: "The JollyRoger (Josies)",
    address: "The Mill, St John's Lane, Bovey Tracey TQ13 9FF",
    latitude: 50.59248,
    longitude: -3.68041,
    aliases: ["Jolly Roger", "Josies"],
  },
  {
    name: "Baffles Cafe at Davant Bikes",
    address: "Broomhill Way, Torquay TQ2 7QL",
    latitude: 50.48389,
    longitude: -3.54836,
    aliases: ["Baffles Cafe", "Davant Bikes"],
  },
  {
    name: "Pit Stop Cafe Plymouth",
    address: "1 Eagle Road, Plympton, Plymouth PL7 5JY",
    latitude: 50.385787,
    longitude: -4.020334,
    aliases: ["Plymouth Pit Stop"],
  },
  {
    name: "Louis Tea Rooms & Cafe",
    address: "Kit Hill, Callington PL17 8AX",
    latitude: 50.5146041,
    longitude: -4.2835432,
    aliases: ["Louis Tea Rooms"],
  },
  {
    name: "TTT Motorcycle Village",
    address: "Bulmer Road Industrial Estate, Sudbury CO10 7HJ",
    latitude: 52.0364175,
    longitude: 0.7137209,
    aliases: ["TTT Cafe"],
  },
  {
    name: "Amici Coffee Cafe & Grill",
    address: "Girtford Bridge, Sandy SG19 1NA",
    latitude: 52.127758,
    longitude: -0.299927,
    aliases: ["Amici Cafe"],
  },
]);

const importedPlaces = BIKE_AND_BREW_PLACES.map((place) => {
  const curatedMatch = CURATED_BIKER_PLACES.find(
    (candidate) => distanceBetweenPlaces(candidate, place) <= 250,
  );
  return {
    ...place,
    aliases: [curatedMatch?.name, ...(curatedMatch?.aliases || [])].filter(
      (alias, index, aliases) =>
        alias && alias !== place.name && aliases.indexOf(alias) === index,
    ),
    category: "cafe",
  };
});

const curatedOnly = CURATED_BIKER_PLACES.filter(
  (place) =>
    !BIKE_AND_BREW_PLACES.some(
      (importedPlace) => distanceBetweenPlaces(place, importedPlace) <= 250,
    ),
).map((place) => ({
  ...place,
  category: /car park/i.test(place.name) ? "start" : "cafe",
}));

export const BIKER_PLACES = Object.freeze([...curatedOnly, ...importedPlaces]);

export function bikerPlacesGeoJson() {
  return {
    type: "FeatureCollection",
    features: BIKER_PLACES.map((place, index) => ({
      type: "Feature",
      properties: {
        index,
        name: place.name,
        address: place.address,
        category: place.category,
      },
      geometry: {
        type: "Point",
        coordinates: [place.longitude, place.latitude],
      },
    })),
  };
}

export function normalizePlaceQuery(value) {
  return String(value)
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[’'`]/g, "")
    .replace(/&/g, " and ")
    .replace(/[^a-zA-Z0-9]+/g, " ")
    .trim()
    .toLowerCase();
}

export function searchBikerPlaces(query, limit = 8) {
  const normalised = normalizePlaceQuery(query);
  if (!normalised) return BIKER_PLACES.slice(0, limit).map(markCatalogPlace);
  const terms = normalised
    .split(/\s+/)
    .filter((term) => !["at", "in", "near", "the"].includes(term));

  return BIKER_PLACES.map((place) => {
    const name = normalizePlaceQuery(place.name);
    const haystack = normalizePlaceQuery(
      [place.name, place.address, ...(place.aliases || [])].join(" "),
    );
    const matchedTerms = terms.filter((term) => haystack.includes(term)).length;
    const score =
      (name === normalised ? 100 : 0) +
      (name.startsWith(normalised) ? 30 : 0) +
      (haystack.includes(normalised) ? 20 : 0) +
      matchedTerms;
    return { place, score, matches: matchedTerms === terms.length };
  })
    .filter((entry) => entry.matches)
    .sort((left, right) => right.score - left.score)
    .slice(0, limit)
    .map((entry) => markCatalogPlace(entry.place));
}

export function bikerPlaceKey(place) {
  return place.sourceId != null
    ? `source-${place.sourceId}`
    : `coordinate-${Number(place.latitude).toFixed(6)},${Number(place.longitude).toFixed(6)}`;
}

export function sortBikerPlaces(
  places,
  mode = "alphabetical",
  start = null,
  durations = new Map(),
) {
  const sorted = [...places];
  if (mode === "distance" && start) {
    return sorted.sort(
      (left, right) =>
        distanceBetweenPlaces(start, left) - distanceBetweenPlaces(start, right) ||
        left.name.localeCompare(right.name),
    );
  }
  if (mode === "duration" && start) {
    return sorted.sort((left, right) => {
      const leftDuration = durations.get(bikerPlaceKey(left));
      const rightDuration = durations.get(bikerPlaceKey(right));
      const durationDifference =
        (Number.isFinite(leftDuration) ? leftDuration : Number.POSITIVE_INFINITY) -
        (Number.isFinite(rightDuration) ? rightDuration : Number.POSITIVE_INFINITY);
      return (
        durationDifference ||
        distanceBetweenPlaces(start, left) - distanceBetweenPlaces(start, right) ||
        left.name.localeCompare(right.name)
      );
    });
  }
  return sorted.sort((left, right) => left.name.localeCompare(right.name));
}

function markCatalogPlace(place) {
  return { ...place, catalog: true };
}

export function distanceBetweenPlaces(first, second) {
  const radians = Math.PI / 180;
  const latitude1 = first.latitude * radians;
  const latitude2 = second.latitude * radians;
  const latitudeDelta = latitude2 - latitude1;
  const longitudeDelta = (second.longitude - first.longitude) * radians;
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(latitude1) *
      Math.cos(latitude2) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}
