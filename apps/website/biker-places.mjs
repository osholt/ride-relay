export const BIKER_PLACES = Object.freeze([
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
    aliases: ["Leather and Lace", "Leather Lace", "Taunton biker cafe"],
  },
  {
    name: "Choppers Cafe",
    address: "A338, Marlborough SN8 3RT",
    aliases: ["Chopper's Cafe", "Chopper Cafe"],
  },
  {
    name: "Ace Cafe London",
    address: "Ace Corner, North Circular Road, London NW10 7UD",
    aliases: ["Ace Cafe"],
  },
  {
    name: "Loomies Moto Cafe",
    address: "West Meon Hut, Petersfield GU32 1JX",
    aliases: ["Loomies"],
  },
  {
    name: "Sammy's Pit Stop",
    address: "Sammy Miller Museum, New Milton BH25 5SZ",
    aliases: ["Sammy Miller Cafe"],
  },
  {
    name: "The Bikers Loft",
    address: "Ventura Place, Poole BH16 5SW",
    aliases: ["Bikers Loft"],
  },
  {
    name: "Harry's Cafe at Fowlers",
    address: "12 Bath Road, Bristol BS4 3DR",
    aliases: ["Fowlers Cafe", "Harrys Cafe"],
  },
  {
    name: "Westcountry Choppers at Explorers Hangout",
    address: "Unit 25F, Merton Road, Bishopston, Bristol BS7 8TL",
    aliases: ["Westcountry Choppers", "Explorers Hangout"],
  },
  {
    name: "Fuel Stop Cafe A27",
    address: "Bognor Bridge Road, Chichester PO20 1QH",
    aliases: ["Fuel Stop Chichester"],
  },
  {
    name: "Cotswold Cafe / Pats Baps",
    address: "Unit 4, London Road, Little Compton GL56 0RR",
    aliases: ["Pats Baps", "Cotswold Cafe"],
  },
  {
    name: "The JollyRoger (Josies)",
    address: "The Mill, St John's Lane, Bovey Tracey TQ13 9FF",
    aliases: ["Jolly Roger", "Josies"],
  },
  {
    name: "Baffles Cafe at Davant Bikes",
    address: "Broomhill Way, Torquay TQ2 7QL",
    aliases: ["Baffles Cafe", "Davant Bikes"],
  },
  {
    name: "Pit Stop Cafe Plymouth",
    address: "1 Eagle Road, Plympton, Plymouth PL7 5JY",
    aliases: ["Plymouth Pit Stop"],
  },
  {
    name: "Louis Tea Rooms & Cafe",
    address: "Kit Hill, Callington PL17 8AX",
    aliases: ["Louis Tea Rooms"],
  },
  {
    name: "TTT Motorcycle Village",
    address: "Bulmer Road Industrial Estate, Sudbury CO10 7HJ",
    aliases: ["TTT Cafe"],
  },
  {
    name: "Amici Coffee Cafe & Grill",
    address: "Girtford Bridge, Sandy SG19 1NA",
    aliases: ["Amici Cafe"],
  },
]);

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

function markCatalogPlace(place) {
  return { ...place, catalog: true };
}
