# Fix "Server unreachable" (http://192.168.1.4:3000)

The app cannot reach your backend. Follow these in order.

---

## 1. Backend must be running

On the **PC** where you want to run the API (the machine with IP 192.168.1.4):

- Open the **backend project** (e.g. `taxi_app_backend`).
- In terminal: `npm run dev` (or `npm start`).
- You should see the server listening on port 3000.

**Check:** On the **same PC**, open a browser and go to:
`http://192.168.1.4:3000/health`  
or  
`http://192.168.1.4:3000/health`

- If this **does not open** or shows an error → backend is not running or not on port 3000. Fix the backend first.
- If it **opens and returns OK** → backend is fine; the problem is network/firewall between phone and PC.

---

## 2. Same WiFi

- **Phone** and **PC** must be on the **same WiFi** (same network).
- Mobile data on the phone will not reach your PC’s local IP.

---

## 3. Correct IP address (192.168.1.4)

Your PC’s IP can change (e.g. after reboot or DHCP).

**On the PC (Windows):**

1. Open **Command Prompt** or **PowerShell**.
2. Run: `ipconfig`
3. Under your **Wi‑Fi** adapter, find **IPv4 Address**. It might be something like `192.168.1.4` or `192.168.1.5`.

If the IP is **not** `192.168.1.4`:

- Either update the app to use the **current** IP (see step 5 below),
- Or set your PC’s WiFi to use a **static IP** `192.168.1.4` in the router/PC network settings.

---

## 4. Allow port 3000 in Windows Firewall

Often the phone cannot reach the PC because **Windows Firewall** blocks port 3000.

**Option A – Run script (easiest):**

1. In this project, open folder: `api/scripts/`
2. Right‑click **`allow-firewall-port-3000.ps1`** → **Run with PowerShell**.
3. If prompted, choose **Run** / **Yes** (elevated). If it says “run as Administrator”, close PowerShell, right‑click the script again → **Run as administrator**.

**Option B – Manual rule:**

1. Press **Win + R**, type `wf.msc`, Enter (opens Windows Defender Firewall with Advanced Security).
2. Click **Inbound Rules** → **New Rule…**.
3. **Port** → Next → **TCP**, **Specific local ports:** `3000` → Next.
4. **Allow the connection** → Next → check **Domain**, **Private**, **Public** → Next.
5. Name: e.g. **Node backend 3000** → Finish.

Then test again from the phone (or from phone’s browser: `http://YOUR_PC_IP:3000/health`).

---

## 5. If your PC IP is different – update the app

If your real IP is e.g. `192.168.1.5`:

1. Open **`lib/config/connection_config.dart`**.
2. Change:
   - `physicalDeviceBaseUrl = 'http://192.168.1.4:3000'`
   - to: `physicalDeviceBaseUrl = 'http://192.168.1.5:3000'` (use your IP).
3. Save and **hot restart** the app (or stop and run again).

If you use **Android emulator** on the same PC, use:

- `http://10.0.2.2:3000`  
  and run the app with:  
  `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`

---

## Quick checklist

| Step | Check |
|------|--------|
| 1 | Backend running on PC? (`npm run dev`) |
| 2 | Browser on PC: `http://192.168.1.4:3000/health` works? |
| 3 | Phone and PC on same WiFi? |
| 4 | PC IP still 192.168.1.4? (`ipconfig`) |
| 5 | Firewall allows TCP port 3000? (run script or add rule) |
| 6 | App’s `connection_config.dart` uses the correct IP? |

After all steps, tap **Retry** on the Create Account screen. If it still fails, test from the **phone’s browser**: open `http://192.168.1.4:3000/health` (with your real PC IP). If that fails, the problem is still network/firewall between phone and PC.

