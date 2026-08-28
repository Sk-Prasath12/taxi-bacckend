# Razorpay payment setup

## Backend (Docker — production)

The Docker API (`taxi_app_backend`) already integrates Razorpay in `src/modules/payment/`.

Set in the container environment or `.env`:

```env
RAZORPAY_KEY_ID=rzp_test_xxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxx
```

Optional dev-only signature bypass (never in production):

```env
ENABLE_PAYMENT_DEV_BYPASS=true
```

Restart backend after changing keys:

```bash
docker compose restart backend
```

## Backend (local Express — `backend/`)

`controllers/paymentController.js` uses the official `razorpay` npm package.

1. Copy `RAZORPAY_*` vars into `backend/.env`
2. `npm install` in `backend/`
3. `npm run dev`

## Customer app

1. At **booking summary**, choose **Razorpay (UPI / Card)** — sets `payment_mode: ONLINE` on confirm.
2. After ride completion, **Payment** screen shows the Razorpay checkout (mobile only).
3. Backend creates a real Razorpay order via `POST /api/payments/create-order`.
4. App verifies via `POST /api/payments/verify`.

## Driver app

- **Cash** rides: driver collects cash and closes immediately.
- **Razorpay** rides: driver waits on payment screen until `payment_success` socket event or poll shows `SUCCESS`.

## Test flow

1. Customer books with **Razorpay (UPI / Card)**.
2. Complete ride (driver drops off).
3. Customer taps **Pay with Razorpay** → use Razorpay test card/UPI.
4. Driver screen updates to **Payment OK**.

## Test success vs failure

| Result | How to test |
|--------|-------------|
| **SUCCESS** | UPI: `success@razorpay` · Card: `4111 1111 1111 1111` (any expiry/CVV) |
| **FAILED** | UPI: `failure@razorpay` · Or cancel/close the Razorpay checkout |

The customer app shows:
- **Payment screen** — status banner (PENDING / FAILED / SUCCESS) + Razorpay test guide
- **Success screen** — Razorpay badge, method, order ID, transaction ID, status SUCCESS
- **Failed screen** — Razorpay badge, error message, status FAILED, **Try Again** button

The driver app shows a coloured status chip: PENDING (orange), SUCCESS (green), FAILED (red).
