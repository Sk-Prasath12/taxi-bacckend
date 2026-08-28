# Seeds a verified ONLINE dummy driver near Guindy (Alandur area) for ride testing.
# Login in driver app:
#   Email:    dummy.driver@taxi.local
#   Password: Driver@1234

$ErrorActionPreference = "Stop"

$mongoOk = docker ps --format "{{.Names}}" | Select-String -Pattern "taxi_app_mongo" -Quiet
$appOk = docker ps --format "{{.Names}}" | Select-String -Pattern "taxi_app_backend" -Quiet
if (-not $mongoOk -or -not $appOk) {
  Write-Error "Docker stack not running. First: cd D:\taxiuser\taxi_customer_app ; .\scripts\start-backend.ps1"
  exit 1
}

Write-Host "Creating / updating dummy driver near Guindy..."

# Hash password inside backend container (same bcrypt as API)
$hash = docker exec taxi_app_backend node -e "require('bcrypt').hash('Driver@1234', 10).then(h => process.stdout.write(h))"
if (-not $hash -or $hash.Length -lt 20) {
  Write-Error "Failed to hash password via backend container"
  exit 1
}

$js = @"
const email = 'dummy.driver@taxi.local';
const hash = '$hash';
const lat = 13.0067;
const lng = 80.2206;
const vt = db.vehicle_types.findOne({ name: 'Small 5 Seater Car', is_active: true });
if (!vt) { print('ERROR: vehicle type missing'); quit(1); }

let user = db.users.findOne({ email: email, role: 'DRIVER' });
const now = new Date();
const geo = { type: 'Point', coordinates: [lng, lat] };

if (!user) {
  const ins = db.users.insertOne({
    name: 'Dummy Driver',
    email: email,
    phone: '9999990001',
    role: 'DRIVER',
    password_hash: hash,
    is_active: true,
    is_blocked: false,
    is_driver_verified: true,
    driver_verification_status: 'APPROVED',
    driver_status: 'ONLINE',
    driver_location: geo,
    driver_location_updated_at: now,
    createdAt: now,
    updatedAt: now,
  });
  user = db.users.findOne({ _id: ins.insertedId });
  print('DRIVER_CREATED ' + user._id);
} else {
  db.users.updateOne(
    { _id: user._id },
    { `$set: {
      password_hash: hash,
      is_active: true,
      is_blocked: false,
      is_driver_verified: true,
      driver_verification_status: 'APPROVED',
      driver_status: 'ONLINE',
      driver_location: geo,
      driver_location_updated_at: now,
      name: 'Dummy Driver',
      phone: '9999990001',
      updatedAt: now,
    }}
  );
  user = db.users.findOne({ _id: user._id });
  print('DRIVER_UPDATED ' + user._id);
}

const profile = db.driver_profiles.findOne({ user_id: user._id });
const profileDoc = {
  user_id: user._id,
  phone: '9999990001',
  address: 'Guindy, Chennai',
  license_number: 'TN-DUMMY-001',
  vehicle_reg_number: 'TN01DM9999',
  vehicle_type_id: vt._id,
  vehicle_model: 'Dzire',
  vehicle_color: 'White',
  aadhaar_number: '999999999999',
  pan_number: 'DUMMY9999D',
  account_holder_name: 'Dummy Driver',
  account_number: '1234567890',
  ifsc_code: 'DUMMY0001234',
  profile_completed: true,
  updatedAt: now,
};
if (!profile) {
  db.driver_profiles.insertOne({ ...profileDoc, createdAt: now });
  print('PROFILE_CREATED');
} else {
  db.driver_profiles.updateOne({ _id: profile._id }, { `$set: profileDoc });
  print('PROFILE_UPDATED');
}

// Also refresh Kiruba near Guindy so existing logins receive rides.
db.users.updateMany(
  { role: 'DRIVER', email: { `$in: ['kiruba12@yopmail.com', 'sridharshini@yopmail.com'] } },
  { `$set: {
      driver_status: 'ONLINE',
      is_driver_verified: true,
      driver_verification_status: 'APPROVED',
      driver_location: geo,
      driver_location_updated_at: now,
    }}
);

printjson({
  email: email,
  password: 'Driver@1234',
  status: user.driver_status,
  location: user.driver_location,
  verified: user.is_driver_verified,
});
"@

$tmp = Join-Path $env:TEMP "seed-dummy-driver.js"
Set-Content -Path $tmp -Value $js -Encoding ascii
docker cp $tmp taxi_app_mongo:/tmp/seed-dummy-driver.js
docker exec taxi_app_mongo mongosh -u taxiadmin -p taxi123 --authenticationDatabase admin taxi_app --file /tmp/seed-dummy-driver.js

Write-Host ""
Write-Host "Dummy driver ready (near Guindy / Alandur):" -ForegroundColor Green
Write-Host "  Email:    dummy.driver@taxi.local"
Write-Host "  Password: Driver@1234"
Write-Host "  Status:   ONLINE + APPROVED"
Write-Host ""
Write-Host "In driver app: login → Go ONLINE (if needed) → wait for customer ride."
