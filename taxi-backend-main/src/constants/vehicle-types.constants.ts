/** Single source of truth for vehicle types across Customer, Driver, Admin, and Backend. */
export const CANONICAL_VEHICLE_TYPES = [
  { code: "BIKE", name: "Bike", per_km_rate: 10, max_passengers: 1 },
  { code: "AUTO", name: "Auto", per_km_rate: 20, max_passengers: 3 },
  { code: "MINI", name: "Mini", per_km_rate: 30, max_passengers: 4 },
  { code: "SEDAN", name: "Sedan", per_km_rate: 40, max_passengers: 4 },
  { code: "SUV", name: "SUV", per_km_rate: 50, max_passengers: 6 },
  { code: "PREMIUM_SEDAN", name: "Premium Sedan", per_km_rate: 60, max_passengers: 4 },
  { code: "PREMIUM_SUV", name: "Premium SUV", per_km_rate: 70, max_passengers: 7 },
  { code: "XL", name: "XL", per_km_rate: 80, max_passengers: 12 },
  { code: "ELECTRIC", name: "Electric", per_km_rate: 90, max_passengers: 4 },
  { code: "ACCESSIBLE", name: "Accessible", per_km_rate: 100, max_passengers: 4 },
] as const;

export type CanonicalVehicleCode = (typeof CANONICAL_VEHICLE_TYPES)[number]["code"];

/**
 * Legacy DB names / codes → current display name.
 * Old overlapping categories (Luxury, Hybrid, Van, 5/7 Seater) map into the nearest canonical type.
 */
export const LEGACY_VEHICLE_NAME_ALIASES: Record<string, string> = {
  "Small 5 Seater Car": "Mini",
  "5 Seater": "Mini",
  "Big 7 Seater Car": "Premium SUV",
  "7 Seater": "Premium SUV",
  Motorbike: "Bike",
  "Two Wheeler": "Bike",
  Hatchback: "Mini",
  Luxury: "Premium Sedan",
  Van: "XL",
  Hybrid: "Electric",
  "Premium": "Premium Sedan",
  CAR_5_SEATER: "Mini",
  CAR_7_SEATER: "Premium SUV",
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
    (v) => v.name === normalized || v.code === normalized.toUpperCase().replace(/\s+/g, "_")
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
