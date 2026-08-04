export const USER_ROLES = ["ADMIN", "CUSTOMER", "DRIVER"] as const;
export type UserRole = (typeof USER_ROLES)[number];
export const DRIVER_STATUSES = ["ONLINE", "OFFLINE", "BUSY"] as const;
export type DriverStatus = (typeof DRIVER_STATUSES)[number];

export const DRIVER_VERIFICATION_STATUSES = ["PENDING", "APPROVED", "REJECTED"] as const;
export type DriverVerificationStatus = (typeof DRIVER_VERIFICATION_STATUSES)[number];

export type DriverProfileSnapshot = {
  dob?: Date | null;
  phone?: string | null;
  address?: string | null;
  emergency_contact?: string | null;
  license_number?: string | null;
  vehicle_reg_number?: string | null;
  vehicle_type_id?: string | null;
  vehicle_model?: string | null;
  vehicle_color?: string | null;
  pan_number?: string | null;
  aadhaar_number?: string | null;
  voter_id?: string | null;
  account_holder_name?: string | null;
  bank_name?: string | null;
  branch_name?: string | null;
  account_number?: string | null;
  ifsc_code?: string | null;
  account_type?: string | null;
  upi_id?: string | null;
  profile_completed?: boolean;
  updatedAt?: Date | null;
};

export type GeoJsonPoint = {
  type: "Point";
  coordinates: [number, number];
};

export type UserEntity = {
  name: string;
  email: string;
  phone?: string;
  fcm_token?: string;
  password_hash: string;
  role: UserRole;
  driver_status?: DriverStatus;
  /** Latest driver GPS (GeoJSON Point) — drivers only */
  driver_location?: GeoJsonPoint;
  driver_location_updated_at?: Date;
  /** Set for drivers only; ignored for other roles */
  is_driver_verified?: boolean;
  /** Set for drivers only; ignored for other roles */
  driver_verification_status?: DriverVerificationStatus;
  /** Driver profile snapshot mirrored for easy role=DRIVER lookups */
  driver_profile?: DriverProfileSnapshot;
  is_active: boolean;
  is_blocked: boolean;
  blocked_reason?: string;
};
