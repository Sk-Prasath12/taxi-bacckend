import { Types } from "mongoose";
import { HttpError } from "../../utils/http-error";
import {
  GeoCoordinate,
  OperationalZoneEntity,
  OperationalZoneModel,
} from "./operational-zone.model";

type CoordinateInput = [number, number];

type ZoneLocationInput = {
  lat: number;
  lng: number;
};

type CreateZoneInput = {
  zone_name: string;
  coordinates: CoordinateInput[];
  created_by: string;
};

type UpdateZoneInput = {
  zone_name?: string;
  coordinates?: CoordinateInput[];
};

const isFiniteNumber = (value: unknown): value is number =>
  typeof value === "number" && Number.isFinite(value);

const validateCoordinate = (coordinate: unknown, index: number): GeoCoordinate => {
  if (!Array.isArray(coordinate) || coordinate.length !== 2) {
    throw new HttpError(400, `Coordinate at index ${index} must be [lng, lat]`);
  }

  const [lng, lat] = coordinate;

  if (!isFiniteNumber(lng) || !isFiniteNumber(lat)) {
    throw new HttpError(400, `Coordinate at index ${index} must contain valid numbers`);
  }

  if (lng < -180 || lng > 180) {
    throw new HttpError(400, `Longitude out of range at index ${index}`);
  }

  if (lat < -90 || lat > 90) {
    throw new HttpError(400, `Latitude out of range at index ${index}`);
  }

  return [lng, lat];
};

const isSamePoint = (a: GeoCoordinate, b: GeoCoordinate): boolean => a[0] === b[0] && a[1] === b[1];

const buildClosedPolygonRing = (coordinates: CoordinateInput[]): GeoCoordinate[] => {
  if (!Array.isArray(coordinates) || coordinates.length < 3) {
    throw new HttpError(400, "Coordinates must contain at least 3 points");
  }

  const sanitized = coordinates.map((coordinate, index) => validateCoordinate(coordinate, index));
  const [firstPoint] = sanitized;
  const lastPoint = sanitized[sanitized.length - 1];

  if (!firstPoint) {
    throw new HttpError(400, "Coordinates cannot be empty");
  }

  if (!isSamePoint(firstPoint, lastPoint)) {
    sanitized.push([...firstPoint]);
  }

  if (sanitized.length < 4) {
    throw new HttpError(400, "A valid polygon requires at least 3 unique points");
  }

  return sanitized;
};

const getZoneById = async (zoneId: string) => {
  if (!Types.ObjectId.isValid(zoneId)) {
    throw new HttpError(400, "Invalid operational zone id");
  }

  const zone = await OperationalZoneModel.findById(zoneId);
  if (!zone) {
    throw new HttpError(404, "Operational zone not found");
  }

  return zone;
};

export const createZone = async (payload: CreateZoneInput) => {
  const ring = buildClosedPolygonRing(payload.coordinates);

  const zone = await OperationalZoneModel.create({
    zone_name: payload.zone_name.trim(),
    polygon: {
      type: "Polygon",
      coordinates: [ring],
    },
    is_active: true,
    created_by: new Types.ObjectId(payload.created_by),
  } as OperationalZoneEntity);

  return zone;
};

export const getAllZones = async () => {
  return OperationalZoneModel.find().sort({ createdAt: -1 }).lean();
};

export const updateZone = async (zoneId: string, payload: UpdateZoneInput) => {
  const zone = await getZoneById(zoneId);

  if (payload.zone_name !== undefined) {
    zone.zone_name = payload.zone_name.trim();
  }

  if (payload.coordinates !== undefined) {
    const ring = buildClosedPolygonRing(payload.coordinates);
    zone.polygon = {
      type: "Polygon",
      coordinates: [ring],
    };
  }

  await zone.save();
  return zone;
};

export const toggleZoneStatus = async (zoneId: string, isActive: boolean) => {
  const zone = await getZoneById(zoneId);
  zone.is_active = isActive;
  await zone.save();
  return zone;
};

export const checkLocationInZone = async (lat: number, lng: number) => {
  if (!isFiniteNumber(lat) || !isFiniteNumber(lng)) {
    throw new HttpError(400, "Invalid location coordinates");
  }

  if (lng < -180 || lng > 180 || lat < -90 || lat > 90) {
    throw new HttpError(400, "Location coordinates are out of range");
  }

  const point: GeoCoordinate = [lng, lat];

  return OperationalZoneModel.findOne({
    is_active: true,
    polygon: {
      $geoIntersects: {
        $geometry: {
          type: "Point",
          coordinates: point,
        },
      },
    },
  }).lean();
};

export const validateRideLocations = async (pickup: ZoneLocationInput, drop: ZoneLocationInput) => {
  const pickupZone = await checkLocationInZone(pickup.lat, pickup.lng);
  if (!pickupZone) {
    throw new HttpError(400, "Pickup zone inactive");
  }

  const dropZone = await checkLocationInZone(drop.lat, drop.lng);
  if (!dropZone) {
    throw new HttpError(400, "Drop zone inactive");
  }

  return {
    success: true,
    pickup_zone_id: pickupZone._id,
    drop_zone_id: dropZone._id,
  };
};
