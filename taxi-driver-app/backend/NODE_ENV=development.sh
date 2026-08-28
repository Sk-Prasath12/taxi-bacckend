NODE_ENV=development
PORT=3000

MONGO_URI=mongodb://taxiadmin:taxi123@mongo:27017/taxi_app?authSource=admin

JWT_ACCESS_SECRET=taxi_app_access_secret_1234567890
JWT_REFRESH_SECRET=taxi_app_refresh_secret_1234567890
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
BCRYPT_SALT_ROUNDS=10

# SMTP configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=pinmeashwin@gmail.com
SMTP_PASSWORD=tmwekcmckpdqdwcr
SMTP_FROM_EMAIL=pinmeashwin@gmail.com