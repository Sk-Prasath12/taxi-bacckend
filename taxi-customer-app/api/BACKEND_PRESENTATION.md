# Taxi Backend – Presentation Charts (Detailed)

Use these in slides, docs, or export to PDF. Mermaid diagrams render in GitHub, VS Code (Markdown Preview), and many presentation tools.

---

## 1. System Overview

```mermaid
flowchart TB
    subgraph Client["📱 Client (Flutter taxi_user)"]
        APP[Taxi User App]
    end

    subgraph Backend["🖥️ Backend (Node/NestJS)"]
        API[REST API<br/>/api/v1]
        WS[WebSocket<br/>Socket.IO]
        AUTH[Auth Module]
        BOOK[Booking Module]
        STATS[Stats Module]
        GW[Gateway]
    end

    subgraph Data["💾 Data & Services"]
        DB[(PostgreSQL)]
        REDIS[(Redis<br/>optional)]
        SMTP[Email / SMTP]
    end

    APP -->|HTTP + JWT| API
    APP -->|Token in handshake| WS
    API --> AUTH
    API --> BOOK
    API --> STATS
    WS --> GW
    AUTH --> DB
    BOOK --> DB
    STATS --> DB
    GW --> DB
    AUTH --> REDIS
    AUTH --> SMTP
```

---

## 2. High-Level API Map

```mermaid
flowchart LR
    subgraph Auth["🔐 Auth /api/v1/auth"]
        A1[Register]
        A2[OTP Verify]
        A3[Setup Password]
        A4[Login]
        A5[Refresh]
        A6[Profile GET/PUT]
        A7[Forget/Reset Pwd]
    end

    subgraph Booking["🚕 Booking /api/v1/booking"]
        B1[types<br/>vehicle-types<br/>package-types]
        B2[locations<br/>GET / POST]
        B3[orders<br/>CRUD + confirm<br/>cancel + review]
        B4[stats<br/>count<br/>earnings<br/>summary]
    end

    subgraph Other["📡 Other"]
        H[GET /health]
    end

    Client[Flutter App] --> Auth
    Client --> Booking
    Client --> H
```

---

## 3. Database Entity Relationship

```mermaid
erDiagram
    user ||--o{ refresh_token : has
    user ||--o{ user_location : has
    user ||--o{ order : "places (customer)"
    user ||--o{ order : "drives (driver)"
    user ||--o{ review : writes

    order }o--|| user_location : "pickup from"
    order }o--o| vehicle_type : "uses"
    order }o--o| package_type : "uses"
    order }o--o| booking_type : "type"
    order ||--o| review : "has one"

    user {
        int id PK
        string email UK
        string password_hash
        string name
        string phone
        string gender
        string role
        string street
        string city
        string pin_code
        bool email_verified
        timestamp created_at
        timestamp updated_at
    }

    refresh_token {
        int id PK
        int user_id FK
        string token
        timestamp expires_at
    }

    otp {
        int id PK
        string email
        string otp_code
        string purpose
        timestamp expires_at
        bool used
    }

    user_location {
        int id PK
        int user_id FK
        string label
        string address
        string street
        string city
        decimal lat
        decimal lng
        timestamp created_at
    }

    vehicle_type {
        int id PK
        string name
        string slug
        decimal base_fare
        decimal per_km
        decimal per_min
        bool is_active
    }

    package_type {
        int id PK
        string name
        string slug
        decimal max_kg
        bool is_active
    }

    booking_type {
        int id PK
        string name
        string slug
        bool is_active
    }

    order {
        int id PK
        int user_id FK
        int driver_id FK
        string status
        int pickup_location_id FK
        string pickup_address
        decimal pickup_lat
        decimal pickup_lng
        string drop_address
        decimal drop_lat
        decimal drop_lng
        string receiver_name
        string receiver_phone
        int booking_type_id FK
        int vehicle_type_id FK
        int package_type_id FK
        decimal weight_kg
        string payer_type
        string payment_mode
        decimal estimated_distance_km
        decimal final_distance_km
        decimal subtotal
        decimal tax
        decimal total_amount
        string cancel_reason
        timestamp confirmed_at
        timestamp assigned_at
        timestamp started_at
        timestamp completed_at
        text route_polyline
        timestamp created_at
    }

    review {
        int id PK
        int order_id FK UK
        int user_id FK
        int driver_id FK
        int rating
        string title
        text comment
        timestamp created_at
    }
```

---

## 4. Order Lifecycle (State Machine)

```mermaid
stateDiagram-v2
    [*] --> DRAFT : POST /booking/orders

    DRAFT --> PENDING : PUT .../confirm
    DRAFT --> CANCELLED : PUT .../cancel

    PENDING --> ASSIGNED : Driver accepts
    PENDING --> CANCELLED : User/System cancel

    ASSIGNED --> DRIVER_ARRIVED : Driver at pickup
    ASSIGNED --> CANCELLED : Cancel

    DRIVER_ARRIVED --> IN_PROGRESS : Trip start
    DRIVER_ARRIVED --> CANCELLED : Cancel

    IN_PROGRESS --> COMPLETED : Trip end, pay
    IN_PROGRESS --> CANCELLED : Cancel

    COMPLETED --> [*] : (User can POST review)

    note right of DRAFT : User creates booking
    note right of PENDING : Notify drivers (WebSocket)
    note right of COMPLETED : Count & earnings updated
```

---

## 5. Stats, Count & Earnings Flow

```mermaid
flowchart TB
    subgraph Sources["Data sources"]
        ORDERS[(order table)]
    end

    subgraph Filters["Filter"]
        F[status = COMPLETED<br/>user_id = current user]
    end

    subgraph Endpoints["API endpoints"]
        E1["GET /booking/stats"]
        E2["GET /booking/rides/count"]
        E3["GET /booking/earnings"]
        E4["GET /booking/orders/summary"]
    end

    subgraph Aggregations["Aggregations"]
        A1["totalRideCount = COUNT(*)"]
        A2["totalSpent = SUM(total_amount)"]
        A3["totalDistanceKm = SUM(final_distance_km)"]
    end

    ORDERS --> F
    F --> A1
    F --> A2
    F --> A3

    A1 --> E1
    A2 --> E1
    A3 --> E1
    A1 --> E2
    A2 --> E3
    A1 --> E4
    A2 --> E4
```

**Response shapes:**

| Endpoint | Response (data) |
|----------|------------------|
| `/booking/stats` | `{ totalRideCount, totalSpent, totalDistanceKm, completedCount, cancelledCount }` |
| `/booking/rides/count` | `{ count }` |
| `/booking/earnings` | `{ totalSpent, currency }` |
| `/booking/orders/summary` | `{ totalRideCount, totalSpent }` (or same as stats) |

---

## 6. Order History & History with Route

```mermaid
flowchart LR
    subgraph Request["Request"]
        R1["GET /booking/orders?limit=20&offset=0"]
        R2["&status=COMPLETED"]
        R3["&includeRoute=true"]
    end

    subgraph Backend["Backend"]
        Q[Query orders<br/>by user_id]
        P[Paginate]
        J[Join pickup/drop<br/>addresses]
        RT[Attach route_polyline<br/>or coordinates]
    end

    subgraph Response["Response"]
        RES["data: array of orders<br/>meta: total, limit, offset"]
        ROUTE["Each order includes<br/>routePolyline or routeCoordinates"]
    end

    R1 --> Q
    R2 --> Q
    Q --> P
    P --> J
    R3 --> RT
    J --> RT
    RT --> RES
    R3 --> ROUTE
```

**Single order with route:**  
`GET /booking/orders/:id?includeRoute=true` → one order with full route for map.

---

## 7. WebSocket Events (User App)

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant Server as Backend (Socket.IO)
    participant Driver as Driver App

    App->>Server: connect(auth: { token })
    Server-->>App: authenticated | auth_error

    App->>Server: join_ride { orderId }
    Note over App,Server: User in room for this order

    Note over Server,Driver: Order confirmed → notify drivers
    Server-->>App: finding_driver
    Driver->>Server: accept order
    Server-->>App: order_assigned
    Driver->>Server: arrived at pickup
    Server-->>App: driver_arrived
    Driver->>Server: start trip
    Server-->>App: order_status_update (IN_PROGRESS)
    loop Live tracking
        Driver->>Server: location
        Server-->>App: location_update
    end
    Driver->>Server: complete trip
    Server-->>App: order_completed

    opt Cancel
        App->>Server: (user cancels via REST)
        Server-->>App: order_cancelled
    end

    App->>Server: leave_ride { orderId }
```

**Event summary:**

| Direction | Event | When |
|-----------|--------|------|
| Server → App | `authenticated` | Valid token |
| Server → App | `auth_error` | Invalid token |
| Server → App | `order_created` | Draft created |
| Server → App | `finding_driver` | Order confirmed |
| Server → App | `order_assigned` | Driver accepted |
| Server → App | `order_status_update` | Status changed |
| Server → App | `driver_arrived` | Driver at pickup |
| Server → App | `location_update` | Driver live location |
| Server → App | `order_cancelled` | Order cancelled |
| Server → App | `order_completed` | Trip completed |
| App → Server | `join_ride` | Subscribe to order |
| App → Server | `leave_ride` | Unsubscribe |

---

## 8. Auth Flow (Registration & Login)

```mermaid
flowchart TB
    subgraph Register["Registration"]
        R1[POST /auth/register] --> R2[Create user + Send OTP]
        R2 --> R3[POST /auth/register/verify-otp]
        R3 --> R4[POST /auth/setup-password]
        R4 --> R5[Return tokens]
    end

    subgraph Login["Login"]
        L1[POST /auth/login<br/>email + password] --> L2[Return access + refresh]
        L2A[POST /auth/login/send-otp] --> L2B[POST /auth/login/verify-otp]
        L2B --> L2
    end

    subgraph Protected["Protected"]
        P1[GET/PUT /auth/profile<br/>Authorization: Bearer token]
        P2[All /booking/*<br/>require same token]
    end

    R5 --> P1
    L2 --> P1
    P1 --> P2
```

---

## 9. Tech Stack (Overview)

```mermaid
flowchart LR
    subgraph Runtime["Runtime"]
        N[Node.js 18+]
    end

    subgraph Framework["Framework"]
        F[NestJS / Express]
    end

    subgraph API["API"]
        R[REST /api/v1]
        S[Socket.IO]
    end

    subgraph Data["Data"]
        PG[(PostgreSQL)]
        RD[(Redis)]
    end

    subgraph External["External"]
        E[SMTP / Email]
    end

    N --> F
    F --> R
    F --> S
    F --> PG
    F --> RD
    F --> E
```

| Layer | Choice | Purpose |
|-------|--------|---------|
| Runtime | Node.js 18+ | Backend runtime |
| Framework | NestJS or Express | REST + structure |
| API | REST + Socket.IO | HTTP + real-time |
| Database | PostgreSQL | Users, orders, locations, reviews |
| Cache | Redis (optional) | OTP, rate limit |
| Auth | JWT access + refresh | Stateless auth |
| Email | Nodemailer / SMTP | OTP delivery |

---

## 10. Module Dependency (Backend)

```mermaid
flowchart TB
    subgraph Entry["Entry"]
        MAIN[main.ts]
        APP[app.module]
    end

    subgraph Modules["Modules"]
        HEALTH[health]
        AUTH[auth]
        USERS[users]
        BOOKING[booking]
        ORDERS[orders]
        LOCATIONS[locations]
        REVIEWS[reviews]
        MASTER[master]
        STATS[stats]
        GATEWAY[gateway]
    end

    subgraph Common["Common"]
        GUARD[JwtAuthGuard]
        PIPE[ValidationPipe]
        INTERCEPTOR[Response transform]
    end

    MAIN --> APP
    APP --> HEALTH
    APP --> AUTH
    APP --> BOOKING
    APP --> GATEWAY
    AUTH --> USERS
    BOOKING --> ORDERS
    BOOKING --> LOCATIONS
    BOOKING --> REVIEWS
    BOOKING --> MASTER
    BOOKING --> STATS
    AUTH --> GUARD
    BOOKING --> GUARD
    ORDERS --> GUARD
```

---

*Use this file in VS Code (Markdown Preview), GitHub, or any tool that supports Mermaid to view the charts. Export to PDF from browser or use in slide decks.*
