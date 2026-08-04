# AWS API Gateway — map to taxi-backend-main

No Gateway definition lives in this repo. Use this when connecting an existing API Gateway to the Node app (Express + Socket.IO on one port).

## Recommended architecture

```
Customer/Driver APK  ──HTTPS──►  API Gateway (REST)  ──►  ALB  ──►  Node :3000
Admin React          ──HTTPS──►  same
Socket.IO            ──WSS────►  ALB (WebSocket upgrade)  ──►  Node :3000
MongoDB              ◄──private──  Node only (VPC, no public port)
```

Socket.IO **cannot** use API Gateway HTTP APIs alone; use:

- **Application Load Balancer** with WebSocket support → Node, or  
- **API Gateway WebSocket API** (requires different integration; not covered by current Socket.IO server without adapter changes).

Practical approach: **one HTTPS domain** (`api.yourdomain.com`) → ALB → Node (REST + Socket on same service).

## REST route map (Gateway → Node paths)

Gateway stage prefix optional; Node expects paths below **without** a stage prefix if ALB forwards as-is.

| Client need | Node method + path |
|-------------|-------------------|
| Health | `GET /api/v1/health` |
| Admin login | `POST /api/v1/auth/login` |
| Customer login | `POST /api/customers/login` |
| Customer profile | `GET /api/customers/profile` |
| Book ride | `POST /api/customers/rides/request` (see `ride.routes.ts`) |
| Driver register | `POST /api/drivers/register/email` (+ verify + set-password) |
| Driver profile | `GET /api/drivers/profile` |
| Driver status | `PATCH /api/drivers/status` |
| Driver incoming | `GET /api/drivers/rides/incoming` |
| Accept ride | `POST /api/drivers/rides/:rideId/accept` |
| Admin drivers | `GET /api/admin/drivers` |
| Pending verification | `GET /api/admin/drivers/verification` |
| Approve driver | `PATCH /api/admin/drivers/:id/approve` |
| Approve by email | `POST /api/admin/drivers/approve-by-email` |

Verify exact ride paths in `src/modules/customer/ride/ride.routes.ts` before creating Gateway resources.

## CORS

Set on **Node** via `CORS_ORIGINS` (admin origin). API Gateway can also enable CORS on OPTIONS — avoid duplicate conflicting headers.

## TLS

Terminate TLS at **CloudFront**, **ALB**, or **API Gateway custom domain**. Node runs HTTP internally.

## Checklist

- [ ] `GET https://api.yourdomain.com/api/v1/health` returns 200 from internet  
- [ ] Admin login from browser  
- [ ] Customer login from APK  
- [ ] Driver login from APK  
- [ ] Socket connects with `wss://api.yourdomain.com` and JWT  
- [ ] MongoDB not reachable from public internet  
