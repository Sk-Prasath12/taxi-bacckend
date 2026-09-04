/** Single source of truth — only these four vehicle types. */
export const CANONICAL_VEHICLE_TYPES = [
  { code: "BIKE", name: "Bike", per_km_rate: 10, max_passengers: 1 },
  { code: "AUTO", name: "Auto", per_km_rate: 20, max_passengers: 3 },
  { code: "FIVE_SEATER", name: "5 Seater", per_km_rate: 35, max_passengers: 5 },
  { code: "SEVEN_SEATER", name: "7 Seater", per_km_rate: 55, max_passengers: 7 },
] as const;

export type CanonicalVehicleCode = (typeof CANONICAL_VEHICLE_TYPES)[number]["code"];

/**
 * Legacy DB names / codes → current display name.
 */
export const LEGACY_VEHICLE_NAME_ALIASES: Record<string, string> = {
  Mini: "5 Seater",
  Sedan: "5 Seater",
  SUV: "7 Seater",
  "Premium Sedan": "5 Seater",
  "Premium SUV": "7 Seater",
  XL: "7 Seater",
  Electric: "5 Seater",
  Accessible: "5 Seater",
  "Small 5 Seater Car": "5 Seater",
  "5 Seater": "5 Seater",
  "Big 7 Seater Car": "7 Seater",
  "7 Seater": "7 Seater",
  Motorbike: "Bike",
  "Two Wheeler": "Bike",
  Hatchback: "5 Seater",
  Luxury: "5 Seater",
  Van: "7 Seater",
  Hybrid: "5 Seater",
  Premium: "5 Seater",
  CAR_5_SEATER: "5 Seater",
  CAR_7_SEATER: "7 Seater",
  MINI: "5 Seater",
  SEDAN: "5 Seater",
  PREMIUM_SEDAN: "5 Seater",
  PREMIUM_SUV: "7 Seater",
  ELECTRIC: "5 Seater",
  ACCESSIBLE: "5 Seater",
};

export const canonicalVehicleCodes = (): CanonicalVehicleCode[] =>
  CANONICAL_VEHICLE_TYPES.map((v) => v.code);

export const canonicalVehicleNames = (): string[] =>
  CANONICAL_VEHICLE_TYPES.map((v) => v.name);

export const normalizeVehicleDisplayName = (name: string): string =>
  LEGACY_VEHICLE_NAME_ALIASES[name.trim()] ?? name.trim();

export const vehicleCodeFromName = (name: string): CanonicalVehicleCode | null => {
  const normalized = normalizeVehicleDisplayName(name);
  const match = CANONICAL_VEHICLE_TYPES.find(
    (v) =>
      v.name === normalized ||
      v.code === normalized.toUpperCase().replace(/\s+/g, "_") ||
      v.code === name.trim().toUpperCase().replace(/\s+/g, "_")
  );
  return match?.code ?? null;
};

export const sortVehicleTypesByCanonicalOrder = <T extends { code?: string | null; name: string }>(
  rows: T[]
): T[] => {
  const order = new Map<string, number>(CANONICAL_VEHICLE_TYPES.map((v, i) => [v.code, i]));
  const nameOrder = new Map<string, number>(CANONICAL_VEHICLE_TYPES.map((v, i) => [v.name, i]));
  return [...rows].sort((a, b) => {
    const ai =
      (a.code ? order.get(a.code.toUpperCase()) : undefined) ??
      nameOrder.get(normalizeVehicleDisplayName(a.name)) ??
      99;
    const bi =
      (b.code ? order.get(b.code.toUpperCase()) : undefined) ??
      nameOrder.get(normalizeVehicleDisplayName(b.name)) ??
      99;
    return ai - bi;
  });
};
