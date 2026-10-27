# Tajer ID — Driver App API (REST) — Flutter integration reference

Generated 2026-09-03 from `routes/api.php` and the Postman collection `tajerid_driver_api.postman_collection.json`. This document is meant to be handed to an AI coding assistant to build the Dart/Flutter data layer of the **driver app**. It covers only the endpoints the driver app needs.

## 1. Basics

| Item | Value |
|---|---|
| Base URL | `https://tajerid.com` (use a `--dart-define=BASE_URL` for local/staging) |
| Path prefix | `/api` (v1 auth + content) and `/api/v2` (driver platform) |
| Format | JSON request and response bodies, `Accept: application/json` |
| Language | `Accept-Language: ar` or `en` on every call (drives localized strings) |
| Auth header | `Authorization: Bearer <jwt>` (preferred) or legacy `jwt: <jwt>` |
| Token source | `POST /api/auth/login` returns `user.jwt` (200-char opaque string). Store it securely (flutter_secure_storage). |
| User id | Never needed in bodies. The server derives `user_id` from the token. Only the password-reset step sends it explicitly. |
| Driver identity | Derived server-side: `fleet_drivers.user_id = authenticated user`. Not a driver → `403 {"msg":"not_a_driver"}`. |
| Rate limits | Global 60 req/min per client on `/api/*`; stricter per-endpoint limits noted below. `429 {"message":"Too Many Attempts."}` |

### REST conventions

- `GET` reads. All filters go in the query string (`?date=2026-09-03`, `?page=2`).
- `POST` creates, commands (start, arrive, deliver, verify…) and every multipart upload.
- `PATCH` partial updates and `…/status` transitions. `PUT` idempotent sets (assign vehicle, set language, device token).
- `DELETE` deletes/revokes. A JSON body is allowed for optional fields such as `reason`.
- Ids are path segments: `/driver/stops/{stop_id}/arrive`. Every numeric id is validated as `[0-9]+`; a non-numeric id returns `404`.
- A wrong verb returns `405 {"message":"The POST method is not supported for route …"}`.

### Two response envelopes (normalize in the client)

| Endpoints | Shape |
|---|---|
| `/driver/*` (except training/performance), `/auth/*`, uploads, account deletion | **bare**: `{"msg": "...", "<payload>": …}` or `{"data": …}` with real HTTP status codes |
| `/driver/training/*`, `/driver/performance`, `/incidents/*`, `/push/*`, `/biometric/*` | **wrapped**: `{"status": <int>, "data": …}` or `{"status": <int>, "message": "..."}`; the HTTP status usually mirrors `status` |

Validation failures everywhere: `400 {"msg":"validation_error","bag":{"field":["message"]}}`.

Responses are encoded with `JSON_NUMERIC_CHECK`: **numeric-looking strings arrive as numbers** (a phone number or an all-digit SKU can be an `int`). Parse with tolerant converters (`num`/`String` → `String` via `.toString()`).

### Persist after these calls

| Call | Save |
|---|---|
| `POST /api/auth/login` | `user.jwt`, `user.id` |
| `GET /api/v2/driver/profile` | `driver.id`, `driver.organization_id`, vehicle, terms/language flags |
| `GET /api/v2/driver/today_route` | `route.id`, `route.stops[].id`, `route.stops[].items[].id` |

## 2. Recommended app flow

1. `PUT /api/auth/device_token` with the FCM/APNs token, then `POST /api/auth/login` (also sends `token`).
2. `GET /api/v2/driver/profile` → if `terms_accepted` is false show terms and `POST /api/v2/driver/terms/accept`; `PUT /api/v2/driver/language`.
3. `POST /api/v2/push/register` with the device token, platform and locale.
4. `GET /api/v2/driver/today_route` → render route + stops. `POST /api/v2/driver/routes/{route_id}/start`.
5. For each stop: `en_route` → `arrive` (with GPS) → pickup **or** deliver. Delivery: `otp/resend` if needed, `barcode/verify` per item, `seals`, optional `partial_reject`, then `deliver` with `otp_code`. Proof photos: `POST /driver/uploads` (multipart) then `POST /driver/stops/{stop_id}/proof` with the returned `file_path`.
6. Background: `POST /api/v2/driver/location` every N seconds while a route is active (single ping or batch).
7. Offline: queue actions with a `client_uuid` and flush with `POST /api/v2/driver/sync/batch`.
8. End: `POST /api/v2/driver/routes/{route_id}/complete`, `GET /api/v2/driver/end_of_day_summary`.

## 3. Endpoint index

| Method | Path | Purpose | Auth |
|---|---|---|---|
| `PUT` | `/api/auth/device_token` | Update Device Token | public |
| `POST` | `/api/auth/login` | Login (driver) | public |
| `POST` | `/api/auth/profile` | Update Basic Profile | jwt |
| `PATCH` | `/api/auth/password` | Change Password | jwt |
| `POST` | `/api/auth/password/forgot` | Forgot Password · Send Code | public |
| `POST` | `/api/auth/password/verify_code` | Forgot Password · Check Code | public |
| `POST` | `/api/auth/password/reset` | Forgot Password · Set New | jwt |
| `POST` | `/api/v2/biometric/credentials` | Enroll Device | jwt |
| `POST` | `/api/v2/biometric/challenge` | Request Challenge | public |
| `POST` | `/api/v2/biometric/verify` | Verify Signature | public |
| `GET` | `/api/v2/biometric/credentials` | List Enrolled Devices | jwt |
| `DELETE` | `/api/v2/biometric/credentials/{credential_id}` | Revoke Device | jwt |
| `GET` | `/api/v2/driver/profile` | Driver Profile | jwt |
| `PATCH` | `/api/v2/driver/profile` | Update Driver Profile | jwt |
| `GET` | `/api/v2/driver/vehicles/available` | Available Vehicles | jwt |
| `PUT` | `/api/v2/driver/vehicle` | Assign Vehicle | jwt |
| `POST` | `/api/v2/driver/terms/accept` | Accept Terms | jwt |
| `PUT` | `/api/v2/driver/language` | Set Language | jwt |
| `GET` | `/api/v2/driver/today_route` | Today Route | jwt |
| `POST` | `/api/v2/driver/routes/{route_id}/start` | Start Route | jwt |
| `POST` | `/api/v2/driver/routes/{route_id}/complete` | Complete Route | jwt |
| `GET` | `/api/v2/driver/history` | Route History | jwt |
| `GET` | `/api/v2/driver/end_of_day_summary` | End Of Day Summary | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/en_route` | Mark Stop En Route | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/arrive` | Arrive At Stop | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/pickup` | Confirm Pickup | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/deliver` | Confirm Delivery | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/skip` | Skip Stop | jwt |
| `GET` | `/api/v2/driver/stops/{stop_id}/receipt_status` | Goods Receipt Status | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/otp/resend` | Resend OTP | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/otp/verify` | Verify OTP | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/barcode/verify` | Verify Barcode | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/seals` | Submit Pickup Seals | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/seals` | Verify Delivery Seals | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/partial_reject` | Partial Reject Item | jwt |
| `POST` | `/api/v2/driver/uploads` | Upload Attachment | jwt |
| `POST` | `/api/v2/driver/stops/{stop_id}/proof` | Attach Proof To Stop | jwt |
| `POST` | `/api/v2/driver/location` | Update Location (single ping) | jwt |
| `POST` | `/api/v2/driver/location` | Update Location (batch) | jwt |
| `POST` | `/api/v2/driver/incidents` | Report Incident | jwt |
| `POST` | `/api/v2/incidents/{incident_id}/acknowledge` | Acknowledge Incident | jwt |
| `POST` | `/api/v2/incidents/{incident_id}/investigate` | Investigate Incident | jwt |
| `POST` | `/api/v2/incidents/{incident_id}/resolve` | Resolve Incident | jwt |
| `POST` | `/api/v2/incidents/{incident_id}/reopen` | Reopen Incident | jwt |
| `GET` | `/api/v2/incidents/{incident_id}/age` | Incident Age / SLA | jwt |
| `GET` | `/api/v2/driver/notifications` | Notifications Inbox | jwt |
| `PATCH` | `/api/v2/driver/notifications/{notification_id}/read` | Mark Notification Read | jwt |
| `PATCH` | `/api/v2/driver/notifications/read_all` | Mark All Read | jwt |
| `POST` | `/api/v2/push/register` | Register Push Token | jwt |
| `POST` | `/api/v2/push/unregister` | Unregister Push Token | jwt |
| `POST` | `/api/v2/push/test` | Send Test Push | jwt |
| `GET` | `/api/v2/driver/earnings` | Earnings | jwt |
| `GET` | `/api/v2/driver/performance` | My Performance | jwt |
| `GET` | `/api/v2/driver/training/curriculum` | Curriculum | jwt |
| `GET` | `/api/v2/driver/training/modules/{module_id}` | Module Content | jwt |
| `POST` | `/api/v2/driver/training/modules/{module_id}/start` | Start Module | jwt |
| `POST` | `/api/v2/driver/training/modules/{module_id}/submit` | Submit Quiz | jwt |
| `GET` | `/api/v2/driver/training/certificate` | Certificate / Status | jwt |
| `POST` | `/api/v2/driver/sync/batch` | Sync Batch | jwt |
| `GET` | `/api/countries` | Countries & Cities | public |
| `GET` | `/api/abouts` | About | public |
| `GET` | `/api/terms` | Terms & Conditions | public |
| `GET` | `/api/support` | Support | public |
| `POST` | `/api/v2/account/deletion_request` | Request Account Deletion | jwt |
| `GET` | `/api/v2/account/deletion_request` | My Deletion Request | jwt |
| `DELETE` | `/api/v2/account/deletion_request` | Cancel Deletion Request | jwt |

## 4. Endpoint details


### 00 · Session & Auth

Sign-in surface for the driver app. There is no OAuth/Sanctum guard: `POST /api/auth/login` returns `user.jwt`, a 200-char random string stored on `users.jwt`. Every protected call re-sends it as the `jwt` header (iOS) or `Authorization: Bearer` header (Android).

A user is only a driver if a `fleet_drivers` row exists with `user_id = users.id`. If not, every `/api/v2/driver/*` endpoint answers `403 {"msg":"not_a_driver"}` — the app must treat that as "this account is not provisioned as a driver", not as a login failure.

#### Update Device Token

`PUT /api/auth/device_token`

**Controller:** `Api\AuthController@update_token`

**Auth:** public — no token required.

Registers/refreshes the device push token row **before** login so the token exists when the user signs in. Returns `204 No Content` on success.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `token` | required | FCM / APNs device token |

**Body example**

```json
{
    "token": "{device_token}"
}
```

#### Login (driver)

`POST /api/auth/login`

**Controller:** `Api\AuthController@login`

**Auth:** public — no token required.

**Rate limit:** `throttle:10,1`.

Returns `{ user: { …, id, jwt } }`. On success persist `user.jwt` and `user.id`; every protected call sends the jwt.

**Errors:** `401 invalid_email`, `401 invalid_password`, `200 {status:failed,msg:'suspended user'}` for a suspended account.

**Note:** the response's `phone` is prefixed with the literal `m_p` (e.g. `m_p512345678`) — strip that prefix client-side.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `token` | required | FCM / APNs device token, linked to the user on login |
| `email` | required | driver's e-mail |
| `password` | required | plaintext password |

**Body example**

```json
{
    "token": "{device_token}",
    "email": "driver@tajerid.com",
    "password": "secret123"
}
```

#### Update Basic Profile

`POST /api/auth/profile`

**Controller:** `Api\AuthController@update`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Edits the shared `users` record (name / e-mail / phone / avatar). Driver-specific fields (licence, national ID) live on a different endpoint — see **02 · Driver Profile & Vehicle → Update Driver Profile**.

Send as `multipart/form-data` when `image` is included.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `user_id` | required|exists:users (must match the jwt) | `{user_id}` |
| `first_name` | required |  |
| `last_name` | required |  |
| `email` | required|email | 409-style `401 email_exists` if taken by another user |
| `phone` | required|numeric | `401 phone_exists` if taken |
| `company_name` | sometimes |  |
| `bank_info` | sometimes |  |
| `image` | sometimes|image | avatar file |

**Body example**

```json
{
    "first_name": "Ahmed",
    "last_name": "Al-Otaibi",
    "email": "driver@tajerid.com",
    "phone": "512345678"
}
```

#### Change Password

`PATCH /api/auth/password`

**Controller:** `Api\AuthController@update_password`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:10,1`.

Returns `204` on success, `401 old_password_incorrect` otherwise.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `user_id` | required|exists:users (must match the jwt) | `{user_id}` |
| `old_password` | required |  |
| `new_password` | required|min:6 |  |

**Body example**

```json
{
    "old_password": "secret123",
    "new_password": "newsecret123"
}
```

#### Forgot Password · Send Code

`POST /api/auth/password/forgot`

**Controller:** `Api\AuthController@send_reset`

**Auth:** public — no token required.

**Rate limit:** `throttle:6,1`.

Emails a reset code to the account.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `email` | required |  |

**Body example**

```json
{
    "email": "driver@tajerid.com"
}
```

#### Forgot Password · Check Code

`POST /api/auth/password/verify_code`

**Controller:** `Api\AuthController@check_reset`

**Auth:** public — no token required.

**Rate limit:** `throttle:10,1`.

Validates the emailed code (checks `codes.expire_at`). Returns the user so the app can call the next step.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `code` | required | 6-digit code from the e-mail |

**Body example**

```json
{
    "code": "123456"
}
```

#### Forgot Password · Set New

`POST /api/auth/password/reset`

**Controller:** `Api\AuthController@password_reset`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:6,1`.

Returns `204`. Requires the `jwt` header of the user returned by **Check Code**.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `user_id` | required|exists:users (must match the jwt) | `{user_id}` |
| `password` | required|min:6 |  |

**Body example**

```json
{
    "user_id": "{user_id}",
    "password": "newsecret123"
}
```


### 01 · Biometric Login

Face ID / fingerprint sign-in. The device generates an EC-P256 or RSA-2048 key pair, enrols the public key while the user is already logged in, then later signs a server-issued challenge to re-authenticate without a password.

⚠️ **Known caveat:** `biometric/verify` returns an `api_token` written to `users.api_token`, while every other endpoint authenticates against `users.jwt`. That returned `api_token` therefore does **not** work as the `jwt` header today. Until the backend is aligned, keep the `jwt` from password login in secure storage and use biometrics as a local unlock gate.

#### Enroll Device

`POST /api/v2/biometric/credentials`

**Controller:** `Api\V2\BiometricController@enroll`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `device_id` | required|string|max:128 | stable per-install ID |
| `device_name` | nullable|string|max:191 | e.g. "Ahmed's iPhone 15" |
| `device_platform` | required|in:android,ios |  |
| `device_os_version` | nullable|string|max:32 |  |
| `biometric_type` | required|in:fingerprint,face,passcode |  |
| `public_key` | required|string|max:8192 | base64 SPKI public key |
| `key_algorithm` | nullable|in:EC_P256,RSA_2048 | defaults to EC_P256 |

**Body example**

```json
{
    "device_id": "{device_id}",
    "device_name": "Driver iPhone",
    "device_platform": "ios",
    "device_os_version": "18.2",
    "biometric_type": "face",
    "public_key": "BASE64_SPKI_PUBLIC_KEY",
    "key_algorithm": "EC_P256"
}
```

#### Request Challenge

`POST /api/v2/biometric/challenge`

**Controller:** `Api\V2\BiometricController@challenge`

**Auth:** public — no token required.

**Rate limit:** `throttle:10,1`.

Public. Returns a 64-char one-time `challenge` the device must sign with its private key.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `device_id` | required|string|max:128 |  |
| `email` | nullable|email | narrows the lookup when several users share a device |

**Body example**

```json
{
    "device_id": "{device_id}",
    "email": "driver@tajerid.com"
}
```

#### Verify Signature

`POST /api/v2/biometric/verify`

**Controller:** `Api\V2\BiometricController@verify`

**Auth:** public — no token required.

**Rate limit:** `throttle:10,1`.

Public. Returns `{ api_token, user }` — see the caveat in this folder's description.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `device_id` | required|string|max:128 |  |
| `challenge` | required|string|size:64 | echo the value from **Request Challenge** |
| `signature` | required|string|max:4096 | base64 signature over the challenge |

**Body example**

```json
{
    "device_id": "{device_id}",
    "challenge": "REPLACE_WITH_64_CHAR_CHALLENGE",
    "signature": "BASE64_SIGNATURE"
}
```

#### List Enrolled Devices

`GET /api/v2/biometric/credentials`

**Controller:** `Api\V2\BiometricController@list`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Returns every credential for the signed-in user with `status` and `last_used_at`.

#### Revoke Device

`DELETE /api/v2/biometric/credentials/{credential_id}`

**Controller:** `Api\V2\BiometricController@revoke`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `credential_id` (path) | required|integer | id from **List Enrolled Devices** |
| `reason` | nullable|string|max:191 | defaults to `user_request` |

**Body example**

```json
{
    "reason": "lost_device"
}
```


### 02 · Driver Profile & Vehicle

Everything the driver sees on the "My account" tab. `driver/profile` is the correct app-boot call: a `403 not_a_driver` here means the account exists but has no `fleet_drivers` row, and the app should show a "contact your fleet manager" screen instead of the route UI.

#### Driver Profile

`GET /api/v2/driver/profile`

**Controller:** `Api\V2\DriverAppController@profile`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Returns `{ driver: { …fleet_drivers row, user, defaultVehicle, organization, fleetCompany } }`.

Key columns: `status`, `employment_type`, `rating`, `total_deliveries`, `total_pickups`, `rate_per_delivery`, `base_salary`, `currency`, `can_bypass_otp`, `driver_license_no`, `driver_license_expiry`, `national_id`, `default_vehicle_id`.

**Errors:** `403 {"msg":"not_a_driver"}`.

#### Update Driver Profile

`PATCH /api/v2/driver/profile`

**Controller:** `Api\V2\DriverAppController@updateProfile`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Only the four fields below are persisted — anything else in the body is ignored. Returns `{data:{ok:true}}`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `national_id` | nullable|string|max:64 |  |
| `driver_license_no` | nullable|string|max:64 |  |
| `driver_license_expiry` | nullable|date | `YYYY-MM-DD` |
| `photo` | nullable|string|max:500 | relative path returned by **Upload Attachment**, not a raw file |

**Body example**

```json
{
    "national_id": "1098765432",
    "driver_license_no": "DL-88231",
    "driver_license_expiry": "2028-04-30",
    "photo": "uploads/b2b/driver/2026/08/photo.jpg"
}
```

#### Available Vehicles

`GET /api/v2/driver/vehicles/available`

**Controller:** `Api\V2\DriverAppController@availableVehicles`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Lists `fleet_vehicles` with `status = available` scoped to the driver's `organization_id`, or to `fleet_company_id` when the driver belongs to an outsourced fleet. Returns `{data:[{id, plate_number, vehicle_type, make, model, year, capacity_kg, is_refrigerated}]}` — `{data:[]}` when the driver has neither scope.

#### Assign Vehicle

`PUT /api/v2/driver/vehicle`

**Controller:** `Api\V2\DriverAppController@assignVehicle`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Sets `fleet_drivers.default_vehicle_id`.

**Errors:** `404 vehicle_not_found`, `403 vehicle_not_in_your_org`, `403 vehicle_not_in_your_fleet`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `vehicle_id` | required|integer | from **Available Vehicles** |

**Body example**

```json
{
    "vehicle_id": "{vehicle_id}"
}
```

#### Accept Terms

`POST /api/v2/driver/terms/accept`

**Controller:** `Api\V2\DriverAppController@acceptTerms`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:6,1`.

No body. Stamps `fleet_drivers.terms_accepted_at`. Call once, gated behind the first-run terms screen. Returns `{success:true, accepted_at}`.

**Body example**

```json
{}
```

#### Set Language

`PUT /api/v2/driver/language`

**Controller:** `Api\V2\DriverAppController@setLanguage`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:30,1`.

Persists the UI language on the user record so server-sent notifications match the app.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `language` | required|in:ar,en |  |

**Body example**

```json
{
    "language": "ar"
}
```


### 03 · Today's Route

The home screen. `today_route` is the single call that drives it — it returns the active route **plus** any overdue routes from previous days (`late_routes`, shown as a red banner) and the next few `upcoming_routes`.

Route status machine: `draft → assigned → in_progress → completed` (`cancelled` possible from the fleet side).

#### Today Route

`GET /api/v2/driver/today_route?date=`

**Controller:** `Api\V2\DriverAppController@todayRoute`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Returns:

```json
{
  "route": { "id": 12, "code": "RT-0001", "route_date": "2026-08-26",
    "status": "in_progress", "total_stops": 6, "completed_stops": 2,
    "stops": [ { "id": 41, "stop_order": 1, "stop_type": "pickup|delivery|internal_transfer_delivery",
        "status": "pending|en_route|arrived|completed|skipped", "branch": {…},
        "items": [ { "id": 90, "expected_qty": 10, "sku": { "product": {…}, "barcode": "…" } } ],
        "proofs": [] } ],
    "vehicle": {…} },
  "eta": { … },              // only when route.status = in_progress
  "late_routes": [ … ],      // assigned/in_progress routes with route_date < today
  "upcoming_routes": [ … ]   // next 5 assigned routes
}
```

Stops arrive already sorted by `stop_order`.

**Query parameters**

| Field | Rule | Notes |
|---|---|---|
| `date` | optional | `YYYY-MM-DD`; defaults to today on the server |

**Query example**

```
?date=
```

#### Start Route

`POST /api/v2/driver/routes/{route_id}/start`

**Controller:** `Api\V2\DriverAppController@startRoute`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Moves the route `assigned → in_progress`, stamps `actual_start_time`, and automatically flips the **first** stop to `en_route` (which pushes a "driver is on the way" notification to that stop's counterparty).

**Errors:** `404 route_not_found_or_not_assigned` — the route must exist, belong to this driver and still be `assigned`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `route_id` (path) | required (no explicit validator) | `{route_id}` |

**Body example**

```json
{}
```

#### Complete Route

`POST /api/v2/driver/routes/{route_id}/complete`

**Controller:** `Api\V2\DriverAppController@completeRoute`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Moves `in_progress → completed`, stamps `actual_end_time`, computes `actual_distance_km` from the recorded location trail, and increments `fleet_drivers.total_deliveries` by the number of completed delivery stops.

**Errors:** `404 route_not_found` when the route isn't `in_progress`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `route_id` (path) | required (no explicit validator) | `{route_id}` |

**Body example**

```json
{}
```

#### Route History

`GET /api/v2/driver/history?page=1`

**Controller:** `Api\V2\DriverAppController@history`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Paginated (15/page) list of this driver's **completed** routes, newest `route_date` first, with `stops.branch` and `vehicle` eager-loaded. Standard Laravel paginator envelope (`data`, `current_page`, `last_page`, `total`, …).

**Query parameters**

| Field | Rule | Notes |
|---|---|---|
| `page` | optional | paginator page — may also be sent as a `?page=` query string |

**Query example**

```
?page=1
```

#### End Of Day Summary

`GET /api/v2/driver/end_of_day_summary?date=`

**Controller:** `Api\V2\DriverAppController@endOfDaySummary`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

The shift-closing screen. Returns `{date, driver_name, route_code, status, summary:{ total_stops, completed_stops, skipped_stops, pickups_done, deliveries_done, total_items, total_delivered_qty, total_returned_qty, total_damaged_qty, incidents_count, distance_km, working_minutes }}`.

**Errors:** `404 no_route_for_date`.

**Query parameters**

| Field | Rule | Notes |
|---|---|---|
| `date` | optional | `YYYY-MM-DD`; defaults to today |

**Query example**

```
?date=
```


### 04 · Stop Execution

The core workflow, one stop at a time. Server-enforced order:

```
pending ──(en_route)──► en_route ──(arrive)──► arrived ──(pickup|deliver)──► completed
    └──────────────────────(skip)──────────────────────────► skipped
```

`arrive` is rejected unless the stop is `pending` or `en_route`; `pickup`/`deliver` are rejected unless the stop is `arrived` (`must_arrive_before_pickup` / `must_arrive_before_delivery`). Every one of these calls resolves the stop through `resolveDriverStop()`, so a stop belonging to another driver's route returns `404 stop_not_found` — never trust a client-supplied driver id.

#### Mark Stop En Route

`POST /api/v2/driver/stops/{stop_id}/en_route`

**Controller:** `Api\V2\DriverAppController@markStopEnRoute`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:30,1`.

Driver-initiated "I've left, heading your way". Sets `en_route_at` and notifies the trader/supplier so their timeline shows the milestone instead of jumping from "dispatched" to "arrived".

**Errors:** `422 cannot_mark_en_route_in_status_<status>` when the stop is past `en_route`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required (no explicit validator) | `{stop_id}` |

**Body example**

```json
{}
```

#### Arrive At Stop

`POST /api/v2/driver/stops/{stop_id}/arrive`

**Controller:** `Api\V2\DriverAppController@arriveAtStop`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Stamps `actual_arrival_time` + arrival coordinates and runs a **geofence check** against the branch: when `latitude`/`longitude` are supplied the server stores `distance_from_branch_meters` and appends a `[GEOFENCE WARNING]` line to the stop notes if the driver is outside the allowed radius. The call still succeeds — the warning is informational.

For a **delivery** stop the server also generates and sends the receiver OTP, so the response carries:

```json
{ "msg": "arrived", "stop": {…},
  "otp_required": true,
  "otp_sent_to": "05xxxxxxxx",
  "otp_expires_at": "2026-08-26 14:05:00",
  "expected_seal_numbers": ["SEAL-1","SEAL-2"] }
```

If SMS delivery fails you get `otp_required: true` plus an `otp_error` string — show the manual-entry path, don't block the driver.

**Errors:** `404 stop_not_found`, `500 arrival_failed` (transaction rolled back, includes `error`).

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required (no explicit validator) | `{stop_id}` |
| `latitude` | optional | device GPS — enables the geofence check |
| `longitude` | optional |  |
| `notes` | optional | forwarded verbatim into the execution service |

**Body example**

```json
{
    "latitude": 24.7136,
    "longitude": 46.6753
}
```

#### Confirm Pickup

`POST /api/v2/driver/stops/{stop_id}/pickup`

**Controller:** `Api\V2\DriverAppController@confirmPickup`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Completes a **pickup** stop: writes `loaded_qty` + barcode results per item, records seal numbers, dispatches the underlying delivery note / internal transfer, marks the stop `completed`, bumps the route's `completed_stops`, and flips the next delivery stop to `en_route`.

The server validates the loaded quantities against `expected_qty` before committing (`quantity_validation_failed`) and enforces barcode scanning on items flagged `barcode_required` (`barcode_validation_failed`). Both come back as `422 {"msg":"pickup_failed","error":"…"}` with the detail JSON embedded in `error` — parse it to highlight the offending lines.

**Errors:** `404 stop_not_found`, `422 must_arrive_before_pickup`, `422 stop_is_not_a_pickup`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |
| `items[]` | array | one entry per line being loaded |
| `items[].item_id` | required within the array | `delivery_stop_items.id` |
| `items[].loaded_qty` | numeric | defaults to `expected_qty` when omitted |
| `items[].barcode_scanned` | bool |  |
| `items[].barcode_match` | bool |  |
| `items[].barcode_value` | string |  |
| `items[].condition_notes` | string |  |
| `seal_numbers[]` | array of strings | recorded as the pickup seals for this shipment |
| `temperature` | numeric | stored on the delivery note as `temperature_on_load` (cold chain) |
| `departure_latitude` | numeric | falls back to the arrival coordinates |
| `departure_longitude` | numeric |  |

**Body example**

```json
{
    "items": [
        {
            "item_id": "{item_id}",
            "loaded_qty": 10,
            "barcode_scanned": true,
            "barcode_match": true,
            "barcode_value": "6281000000001",
            "condition_notes": ""
        }
    ],
    "seal_numbers": [
        "SEAL-1001",
        "SEAL-1002"
    ],
    "temperature": 4.5,
    "departure_latitude": 24.7136,
    "departure_longitude": 46.6753
}
```

#### Confirm Delivery

`POST /api/v2/driver/stops/{stop_id}/deliver`

**Controller:** `Api\V2\DriverAppController@confirmDelivery`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Completes a **delivery** stop and is the most guarded call in the app.

**OTP handling** (three paths):
1. `otp_code` present → verified inline; a bad code aborts with `otp_verification_failed`.
2. `otp_code` absent but the OTP was already verified via **Verify OTP** → proceeds.
3. Neither → the server records an OTP **bypass** using `bypass_reason` and continues, flagging the delivery so the trader can dispute it within the review window. Always send a real `bypass_reason` (e.g. `receiver_phone_unreachable`) — it is stored and audited.

**Quantity balance** is mandatory: `delivered_qty + returned_qty + damaged_qty` must reconcile against `expected_qty` for every line, or the call fails with `quantity_balance_failed` and a per-line error list. Barcode requirements are enforced the same way as on pickup.

**Errors:** `404 stop_not_found`, `422 must_arrive_before_delivery`, `422 stop_is_not_a_delivery`, `422 {"msg":"delivery_failed","error":"…"}`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |
| `otp_code` | optional string | 6 digits; omit only when using a bypass |
| `bypass_reason` | optional string | used when no OTP is supplied and none was verified |
| `items[].item_id` | required within the array |  |
| `items[].delivered_qty` | numeric | defaults 0 |
| `items[].returned_qty` | numeric | defaults 0 |
| `items[].damaged_qty` | numeric | defaults 0 |
| `items[].condition_notes` | string |  |
| `seal_numbers[]` | array of strings | verified against the seals recorded at pickup |
| `signer_name / signer_role` | string | receiver identity captured with the signature proof |

**Body example**

```json
{
    "otp_code": "{otp_code}",
    "items": [
        {
            "item_id": "{item_id}",
            "delivered_qty": 9,
            "returned_qty": 1,
            "damaged_qty": 0,
            "condition_notes": "one carton dented"
        }
    ],
    "seal_numbers": [
        "SEAL-1001",
        "SEAL-1002"
    ],
    "signer_name": "Khalid",
    "signer_role": "branch_manager"
}
```

#### Skip Stop

`POST /api/v2/driver/stops/{stop_id}/skip`

**Controller:** `Api\V2\DriverAppController@skipStop`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Marks the stop `skipped` with a `failure_reason`, still counts it toward `completed_stops` so the route can close, and flips the next delivery to `en_route`.

Only `pending`, `en_route` or `arrived` stops can be skipped (`stop_cannot_be_skipped`).

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |
| `reason` | optional string | defaults to `skipped_by_driver`; surface a reason picker in the UI |

**Body example**

```json
{
    "reason": "branch_closed"
}
```

#### Goods Receipt Status

`GET /api/v2/driver/stops/{stop_id}/receipt_status`

**Controller:** `Api\V2\DriverAppController@stopReceiptStatus`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:60,1`.

Post-delivery visibility: did the trader accept what was dropped off? Poll this after **Confirm Delivery** on stops whose `reference_type` is `delivery_note`.

Possible `data.status` values: `not_applicable` (stop isn't tied to a delivery note), `no_delivery_note`, `pending_trader_action`, or the receipt's own status — `accepted` | `partial` | `rejected` | `disputed`. When a receipt exists you also get `goods_receipt_id`, `receipt_no`, `received_at`, `disputed_at`, `totals.received_qty`, `totals.rejected_qty`, `qty_mismatch_with_driver` and `notes`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |


### 05 · Receiver OTP

Proof-of-handover: on arrival at a delivery stop the server SMSes a 6-digit code to the receiver, who reads it out to the driver.

Both path shapes exist and hit the **same controller methods** — `/driver/otp/*` (original) and `/driver/stop/otp/*` (added so the mobile clients keep a consistent `/driver/stop/*` namespace). Pick one and stay consistent.

`verify` returns `{success:false, msg:'invalid_code', attempts_remaining:N}` on a wrong code and expires the OTP after the attempt cap (`max_attempts_reached`) or timeout (`otp_expired`) — both come back with `requires_generation:true`, meaning the app should offer **Resend**, not another attempt.

#### Resend OTP

`POST /api/v2/driver/stops/{stop_id}/otp/resend`

**Controller:** `Api\V2\DriverAppController@resendOtp`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:6,1`.

Identical to **Resend OTP** — same controller method, alternate path.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |

**Body example**

```json
{}
```

#### Verify OTP

`POST /api/v2/driver/stops/{stop_id}/otp/verify`

**Controller:** `Api\V2\DriverAppController@verifyOtp`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:10,1`.

Identical to **Verify OTP** — same controller method, alternate path.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |
| `otp_code` | required|string|size:6 |  |

**Body example**

```json
{
    "otp_code": "{otp_code}"
}
```


### 06 · Barcode, Seals & Rejections

Scan-and-verify helpers used inside the pickup/delivery sheets. They mutate the stop's item rows directly, so the app can call them incrementally as the driver scans, then send the final tallies with **Confirm Pickup / Confirm Delivery**.

#### Verify Barcode

`POST /api/v2/driver/stops/{stop_id}/barcode/verify`

**Controller:** `Api\V2\DriverAppController@stopBarcodeVerify`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:60,1`.

Compares a scanned code against `skus.barcode` for every item on the stop. A match sets `barcode_scanned = true` and `barcode_match = true` on that line and returns `{success:true, item_id}`. A miss returns **HTTP 200** with `{success:false, msg:'barcode_mismatch'}` — check the `success` flag, not the status code. Both outcomes are written to the audit log.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |
| `barcode` | required|string|max:128 | raw scanner output; trimmed server-side |

**Body example**

```json
{
    "barcode": "6281000000001"
}
```

#### Submit Pickup Seals

`POST /api/v2/driver/stops/{stop_id}/seals`

**Controller:** `Api\V2\DriverAppController@stopSealSubmit`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:30,1`.

`mode: "pickup"` records the seal numbers applied when the shipment was loaded. Returns `{success, recorded}`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |
| `seals` | required|array|min:1 |  |
| `seals.*` | required|string|max:64 |  |
| `mode` | required|in:pickup,delivery | `pickup` here |

**Body example**

```json
{
    "seals": [
        "SEAL-1001",
        "SEAL-1002"
    ],
    "mode": "pickup"
}
```

#### Verify Delivery Seals

`POST /api/v2/driver/stops/{stop_id}/seals`

**Controller:** `Api\V2\DriverAppController@stopSealSubmit`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:30,1`.

`mode: "delivery"` verifies the seals present at drop-off against those recorded at pickup. The response merges the seal service report — `{success, matched, mismatched, missing, extra, …}`; `success` is true only when `mismatched` is 0. Surface any mismatch prominently: it is tamper evidence.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |
| `seals` | required|array|min:1 | seals read at the delivery point |
| `seals.*` | required|string|max:64 |  |
| `mode` | required|in:pickup,delivery | `delivery` here |

**Body example**

```json
{
    "seals": [
        "SEAL-1001",
        "SEAL-1002"
    ],
    "mode": "delivery"
}
```

#### Partial Reject Item

`POST /api/v2/driver/stops/{stop_id}/partial_reject`

**Controller:** `Api\V2\DriverAppController@stopPartialReject`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:30,1`.

Records a receiver's partial refusal of one line: adds to `returned_qty`, recomputes `delivered_qty = expected_qty − returned_qty`, and appends the reason to `condition_notes`.

**Errors:** `404 item_not_in_stop`, `400 rejected_qty_exceeds_expected`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |
| `item_id` | required|integer | must belong to this stop |
| `rejected_qty` | required|numeric|min:0.01 | cannot exceed `expected_qty` |
| `reason` | required|string|max:120 | short code/label, e.g. `damaged_packaging` |
| `notes` | nullable|string|max:500 |  |

**Body example**

```json
{
    "item_id": "{item_id}",
    "rejected_qty": 1,
    "reason": "damaged_packaging",
    "notes": "carton torn on arrival"
}
```


### 07 · Proofs & File Upload

Two-step by design: **upload the bytes first**, then **attach the returned path** to the stop as a typed proof. `proof/upload` never receives a file — it takes the `file_path` string that the upload endpoint returned.

Photo proofs (`pickup_photo`, `delivery_photo`, `damage_photo`, `condition_photo`) are **rejected without `watermark_data`** (`400 watermark_required`). Build the watermark client-side from the capture context (timestamp, GPS, driver, route/stop code) and send it as an object.

#### Upload Attachment

`POST /api/v2/driver/uploads`

**Controller:** `Api\V2\UploadController@driverAttachment`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:60,1`.

`multipart/form-data`. Driver-only — no B2B membership required, unlike `/v2/uploads/mobile_attachment`.

Files land under `public/uploads/b2b/driver/YYYY/MM/`. Response:

```json
{ "msg": "attachment_uploaded",
  "data": { "original_name": "…", "stored_name": "…",
    "file_path": "uploads/b2b/driver/2026/08/20260826_ab12cd34ef.jpg",
    "file_url": "https://…", "mime_type": "image/jpeg", "size": 182344, "module": "proof" } }
```

Pass `data.file_path` (not `file_url`) to **Attach Proof To Stop**.

**Errors:** `401 unauthenticated`, `403 not_a_driver`, `400 validation_error`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `attachment` | required|file|max:10240|mimes:jpg,jpeg,png,webp,pdf | 10 MB cap |
| `module` | sometimes|nullable|string|max:100 | free-form tag, defaults to `proof` |

**Multipart form fields**

| Field | Type | Value |
|---|---|---|
| `attachment` | file |  — jpg, jpeg, png, webp or pdf — max 10 MB |
| `module` | text | proof  |

#### Attach Proof To Stop

`POST /api/v2/driver/stops/{stop_id}/proof`

**Controller:** `Api\V2\DriverAppController@uploadProof`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Creates a `delivery_proofs` row linked to the stop. Returns `{msg:'proof_uploaded', proof:{…}}`.

**Errors:** `404 stop_not_found`, `400 validation_error`, `400 {"msg":"watermark_required","error":"photo_proofs_must_include_watermark"}`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `stop_id` (path) | required | `{stop_id}` |
| `proof_type` | required|in:pickup_photo,delivery_photo,damage_photo,signature,condition_photo,return_photo,document_scan |  |
| `proof_category` | required|in:pickup,delivery,return,inspection |  |
| `file_path` | required|string | `data.file_path` from **Upload Attachment** |
| `watermark_data` | required for the four photo types | object; stored as JSON |
| `file_type` | optional | mime type |
| `latitude / longitude` | optional | capture coordinates |
| `captured_at` | optional | defaults to server `now()` — send the device timestamp for offline captures |
| `signer_name / signer_role / signer_national_id` | optional | for `signature` proofs |
| `camera_source` | optional | defaults to `camera`; use it to flag gallery picks |
| `client_uuid` | optional | idempotency key — reuse the same UUID across offline retries |
| `notes` | optional |  |

**Body example**

```json
{
    "proof_type": "delivery_photo",
    "proof_category": "delivery",
    "file_path": "uploads/b2b/driver/2026/08/20260826_ab12cd34ef.jpg",
    "file_type": "image/jpeg",
    "latitude": 24.7136,
    "longitude": 46.6753,
    "captured_at": "2026-08-26 14:03:11",
    "watermark_data": {
        "driver": "Ahmed Al-Otaibi",
        "route_code": "RT-0001",
        "stop_id": "{stop_id}",
        "timestamp": "2026-08-26T14:03:11+03:00",
        "lat": 24.7136,
        "lng": 46.6753
    },
    "camera_source": "camera",
    "client_uuid": "6f6a8c1e-0f2a-4a1b-9a55-2f7d1c8e4b10",
    "notes": "handed to branch manager"
}
```


### 08 · Live Location

Feeds `driver_location_logs`, which powers the fleet console's live map, ETA calculation, route deviation alerts and the `actual_distance_km` computed when the route completes.

**Send batches, not single pings.** The endpoint accepts either shape, but batching every 30–60 s is what the backend is tuned for and it survives connectivity gaps. Include `battery_level` — the ops team uses it to tell a dead phone apart from a stalled driver.

#### Update Location (single ping)

`POST /api/v2/driver/location`

**Controller:** `Api\V2\DriverAppController@updateLocation`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Flat form: the server wraps the top-level fields into a one-element batch. Returns `{msg:'location_updated', points_saved:N}`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `latitude` | required in practice | decimal(10,7) |
| `longitude` | required in practice |  |
| `speed_kmh` | optional |  |
| `heading` | optional | 0–359 |
| `accuracy_meters` | optional |  |
| `battery_level` | optional | 0–100 |
| `logged_at` | optional | defaults to server `now()` |

**Body example**

```json
{
    "latitude": 24.7136,
    "longitude": 46.6753,
    "speed_kmh": 42.5,
    "heading": 130,
    "accuracy_meters": 8,
    "battery_level": 74,
    "logged_at": "2026-08-26 14:03:11"
}
```

#### Update Location (batch)

`POST /api/v2/driver/location`

**Controller:** `Api\V2\DriverAppController@updateLocation`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Preferred shape. When `locations` is present the flat fields are ignored entirely. Each element carries its own `logged_at`, so a queue flushed after 10 minutes offline still produces an accurate trail.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `locations` | array | one entry per GPS sample |
| `locations[].latitude` | required |  |
| `locations[].longitude` | required |  |
| `locations[].speed_kmh / heading / accuracy_meters / battery_level` | optional |  |
| `locations[].logged_at` | optional | device timestamp — send it for offline replay |

**Body example**

```json
{
    "locations": [
        {
            "latitude": 24.7136,
            "longitude": 46.6753,
            "speed_kmh": 42.5,
            "heading": 130,
            "accuracy_meters": 8,
            "battery_level": 74,
            "logged_at": "2026-08-26 14:03:11"
        },
        {
            "latitude": 24.715,
            "longitude": 46.679,
            "speed_kmh": 38.0,
            "heading": 128,
            "accuracy_meters": 6,
            "battery_level": 73,
            "logged_at": "2026-08-26 14:03:41"
        }
    ]
}
```


### 09 · Incidents

Anything that goes wrong on the road. The driver app owns **Report Incident**; the lifecycle transitions below are shared with the fleet console (they authenticate any signed-in user, so surface them read-only in the driver app unless your rollout says otherwise).

Lifecycle: `reported → acknowledged → investigating → resolved|dismissed`, with `reopen` going back.

#### Report Incident

`POST /api/v2/driver/incidents`

**Controller:** `Api\V2\DriverAppController@reportIncident`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Creates a `driver_incidents` row attributed to this driver. When `route_id` is omitted the server attaches the driver's current route automatically.

**Errors:** `403 not_a_driver`, `400 validation_error`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `incident_type` | required|in:accident,vehicle_breakdown,goods_damage,theft_attempt,customer_complaint,delay,other |  |
| `severity` | sometimes|in:low,medium,high,critical | defaults to `medium` |
| `description` | optional string |  |
| `route_id` | optional | defaults to the driver's today route |
| `stop_id` | optional | links the incident to a specific stop |
| `latitude / longitude` | optional | where it happened |

**Body example**

```json
{
    "incident_type": "vehicle_breakdown",
    "severity": "high",
    "description": "Flat tyre on the ring road",
    "route_id": "{route_id}",
    "stop_id": "{stop_id}",
    "latitude": 24.7136,
    "longitude": 46.6753
}
```

#### Acknowledge Incident

`POST /api/v2/incidents/{incident_id}/acknowledge`

**Controller:** `Api\V2\IncidentController@acknowledge`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `incident_id` (path) | required|integer | `{incident_id}` |
| `notes` | nullable|string|max:2000 |  |

**Body example**

```json
{
    "notes": "Dispatcher notified"
}
```

#### Investigate Incident

`POST /api/v2/incidents/{incident_id}/investigate`

**Controller:** `Api\V2\IncidentController@investigate`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `incident_id` (path) | required|integer |  |
| `notes` | nullable|string|max:2000 |  |

**Body example**

```json
{
    "notes": "Awaiting workshop report"
}
```

#### Resolve Incident

`POST /api/v2/incidents/{incident_id}/resolve`

**Controller:** `Api\V2\IncidentController@resolve`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `incident_id` (path) | required|integer |  |
| `resolution_notes` | required|string|max:2000 |  |
| `outcome` | nullable|in:resolved,dismissed | defaults to `resolved` |

**Body example**

```json
{
    "resolution_notes": "Tyre replaced, route resumed",
    "outcome": "resolved"
}
```

#### Reopen Incident

`POST /api/v2/incidents/{incident_id}/reopen`

**Controller:** `Api\V2\IncidentController@reopen`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `incident_id` (path) | required|integer |  |
| `reason` | required|string|max:500 |  |

**Body example**

```json
{
    "reason": "Damage reappeared next day"
}
```

#### Incident Age / SLA

`GET /api/v2/incidents/{incident_id}/age`

**Controller:** `Api\V2\IncidentController@age`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Returns `{sla_breached, severity, reported_at, resolved_at}` — drives the red/amber badge on the incident card.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `incident_id` (path) | required|integer |  |


### 10 · Notifications & Push

Two independent channels: the in-app inbox (`driver_notifications`, polled) and FCM/APNs push (delivered).

The inbox endpoints degrade gracefully — if the `driver_notifications` table hasn't been migrated they return `{data:[]}` / `{data:{ok:true}}` instead of erroring, so the app must not treat an empty list as a failure.

#### Notifications Inbox

`GET /api/v2/driver/notifications`

**Controller:** `Api\V2\DriverAppController@notifications`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Returns the latest **100** notifications for this driver, newest first: `{data:[{id, event_code, title, body, payload_json, delivery_note_id, route_stop_id, incident_id, read_at, created_at}]}`. Unread = `read_at === null`.

#### Mark Notification Read

`PATCH /api/v2/driver/notifications/{notification_id}/read`

**Controller:** `Api\V2\DriverAppController@notificationsMarkRead`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Scoped to this driver — passing another driver's notification id silently affects nothing.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `id` (path) | required|integer | `driver_notifications.id` |

**Body example**

```json
{}
```

#### Mark All Read

`PATCH /api/v2/driver/notifications/read_all`

**Controller:** `Api\V2\DriverAppController@notificationsMarkAllRead`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Stamps `read_at` on every unread row for this driver.

**Body example**

```json
{}
```

#### Register Push Token

`POST /api/v2/push/register`

**Controller:** `Api\V2\PushController@register`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Call after login **and** on every FCM/APNs token refresh. Idempotent per token. Returns `{status:200, data:{token_id, registered_at}}`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `token` | required|string|max:512 | FCM / APNs token |
| `platform` | required|in:android,ios,web |  |
| `app_variant` | nullable|in:driver,supplier,trader,owner,admin | **send `driver`** so the backend routes driver-only pushes here |
| `locale` | nullable|string|max:8 | `ar` / `en` |
| `device_id` | nullable|string|max:128 |  |
| `device_model` | nullable|string|max:191 |  |
| `os_version` | nullable|string|max:32 |  |

**Body example**

```json
{
    "token": "{device_token}",
    "platform": "android",
    "app_variant": "driver",
    "locale": "ar",
    "device_id": "{device_id}",
    "device_model": "Pixel 8",
    "os_version": "15"
}
```

#### Unregister Push Token

`POST /api/v2/push/unregister`

**Controller:** `Api\V2\PushController@unregister`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Call on logout so the device stops receiving another driver's assignments.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `token` | required|string |  |

**Body example**

```json
{
    "token": "{device_token}"
}
```

#### Send Test Push

`POST /api/v2/push/test`

**Controller:** `Api\V2\PushController@test`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Fires a test notification to every registered token of the signed-in user; returns `{data:{sent:N}}`. Handy for a "test notifications" button in developer settings.

**Body example**

```json
{}
```


### 11 · Earnings & Performance

Read-only money and KPI screens. Earnings for the current month are computed live; closed months come from the payroll table.

#### Earnings

`GET /api/v2/driver/earnings`

**Controller:** `Api\V2\DriverAppController@earnings`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Response:

```json
{ "data": {
  "currency": "SAR",
  "current": {
    "period": "2026-08",
    "base_salary": 3000.0,
    "rate_per_delivery": 12.5,
    "deliveries_count": 84,
    "deliveries_pay": 1050.0,
    "bonuses_total": 200.0,
    "deductions_total": 0.0,
    "net_total": 4250.0,
    "bonuses": [ { "id": 3, "type": "ontime", "amount": 200.0,
                    "description": "…", "awarded_on": "2026-08-15" } ]
  },
  "history": [ { "period": "2026-07", "base_salary": 3000.0, "deliveries_count": 91,
                 "deliveries_pay": 1137.5, "bonuses_total": 0.0, "deductions_total": 0.0,
                 "net_total": 4137.5, "currency": "SAR", "status": "paid",
                 "paid_at": "2026-08-01 09:00:00" } ]
} }
```

`current.deliveries_count` counts completed **delivery** stops whose route falls in the current month. `deductions_total` is always `0.0` on the live-computed current month — deductions only appear once payroll closes the period into `driver_payments`. `history` returns the last 6 closed periods.

#### My Performance

`GET /api/v2/driver/performance?since=2026-07-27&until=2026-08-26`

**Controller:** `Api\V2\DriverPerformanceController@self`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

KPI rollup for the signed-in driver (on-time rate, completion rate, incident count, etc. — whatever `DriverPerformanceService::forDriver()` computes for your build).

**Errors:** `401 unauthenticated`, `403 not_a_driver`.

**Query parameters**

| Field | Rule | Notes |
|---|---|---|
| `since` | optional date | defaults to 30 days ago |
| `until` | optional date | defaults to now |

**Query example**

```
?since=2026-07-27&until=2026-08-26
```


### 12 · Training & Certification

Onboarding/compliance modules the driver must pass. All five endpoints return the `{status: <int>, data|message: …}` envelope (note: **different shape** from the driver-app endpoints, which return bare objects) and answer `401 not_a_driver` when no `fleet_drivers` row exists.

#### Curriculum

`GET /api/v2/driver/training/curriculum`

**Controller:** `Api\V2\DriverTrainingController@curriculum`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Returns `{status:200, data:{status:{…certification state…}, curriculum:[…modules…]}}` — the module list plus this driver's progress and certificate state.

#### Module Content

`GET /api/v2/driver/training/modules/{module_id}`

**Controller:** `Api\V2\DriverTrainingController@module`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Errors:** `400` invalid id, `404 module_not_found`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `id` (path) | required|integer | module id from **Curriculum** |

#### Start Module

`POST /api/v2/driver/training/modules/{module_id}/start`

**Controller:** `Api\V2\DriverTrainingController@start`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Returns `{status:200, data:{module_id, status, started_at}}`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `id` (path) | required|integer | module id |

**Body example**

```json
{}
```

#### Submit Quiz

`POST /api/v2/driver/training/modules/{module_id}/submit`

**Controller:** `Api\V2\DriverTrainingController@submit`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Grades the attempt and returns the service result (score, pass/fail, whether a certificate was issued).

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `id` (path) | required|integer | module id |
| `answers` | required|array|min:1 |  |
| `answers[].question_id` | required |  |
| `answers[].answer` | required | string or index, per the question type |

**Body example**

```json
{
    "answers": [
        {
            "question_id": 1,
            "answer": "b"
        },
        {
            "question_id": 2,
            "answer": "a"
        }
    ]
}
```

#### Certificate / Status

`GET /api/v2/driver/training/certificate`

**Controller:** `Api\V2\DriverTrainingController@certificate`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Returns the same `driverStatus()` payload as **Curriculum**'s `data.status` — certification state, expiry, outstanding modules.


### 13 · Offline Sync

The single most important endpoint for a driver app that works in basements and industrial zones.

Queue every mutating action locally with a client-generated UUID, then replay the queue through this endpoint when connectivity returns. The server sorts by `client_created_at`, so ordering is preserved even if the app flushes out of order, and it **deduplicates on `client_uuid`** — a re-sent event that already succeeded comes back as `already_synced` rather than double-posting.

#### Sync Batch

`POST /api/v2/driver/sync/batch`

**Controller:** `Api\V2\DriverAppController@syncBatch`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

Returns one result per event, in processed order:

```json
{ "results": [
  { "client_uuid": "…", "status": "synced", "result": {…} },
  { "client_uuid": "…", "status": "already_synced" },
  { "client_uuid": "…", "status": "failed", "error": "must_arrive_before_delivery" },
  { "status": "skipped", "reason": "missing_uuid" }
] }
```

A `failed` event is retried server-side up to 3 times by a background job, but the app should also keep it queued and surface it in a "pending sync" badge.

**Supported `action_type` values and their `payload` shape:**

| `action_type` | payload | equivalent online call |
|---|---|---|
| `arrive` | `{stop_id, latitude, longitude, …}` | `/driver/stop/arrive` |
| `pickup` | `{stop_id, items[], seal_numbers[], …}` | `/driver/stop/pickup` |
| `deliver` | `{stop_id, otp_code, items[], …}` | `/driver/stop/deliver` |
| `skip` | `{stop_id, reason}` | `/driver/stop/skip` |
| `proof_upload` | `{stop_id, proof_type, proof_category, file_path, watermark_data, …}` | `/driver/proof/upload` |
| `location_batch` | `{locations: [...]}` | `/driver/location/update` |
| `incident` | `{incident_type, severity, description, …}` | `/driver/incident/report` |

Anything else fails with `unknown_action_type: <value>`.

⚠️ `proof_upload` replays the **metadata** only — the file itself must already exist on the server, so upload bytes via `/driver/uploads/attachment` first (that one cannot be queued offline).

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `events` | required|array |  |
| `events[].client_uuid` | required|string | idempotency key — generate once, never regenerate on retry |
| `events[].action_type` | required|string | see the table above |
| `events[].payload` | object | same body you would have POSTed online |
| `events[].client_created_at` | optional datetime | used for ordering — always send it |

**Body example**

```json
{
    "events": [
        {
            "client_uuid": "6f6a8c1e-0f2a-4a1b-9a55-2f7d1c8e4b10",
            "action_type": "arrive",
            "client_created_at": "2026-08-26 13:58:02",
            "payload": {
                "stop_id": "{stop_id}",
                "latitude": 24.7136,
                "longitude": 46.6753
            }
        },
        {
            "client_uuid": "8b1d2f34-77aa-4c0e-9d21-5c9e0a7b3d44",
            "action_type": "deliver",
            "client_created_at": "2026-08-26 14:06:40",
            "payload": {
                "stop_id": "{stop_id}",
                "otp_code": "123456",
                "items": [
                    {
                        "item_id": "{item_id}",
                        "delivered_qty": 10,
                        "returned_qty": 0,
                        "damaged_qty": 0
                    }
                ]
            }
        },
        {
            "client_uuid": "c4a9e0b2-1e55-4f77-8b30-9a2c6d1f0e88",
            "action_type": "location_batch",
            "client_created_at": "2026-08-26 14:10:00",
            "payload": {
                "locations": [
                    {
                        "latitude": 24.715,
                        "longitude": 46.679,
                        "logged_at": "2026-08-26 14:09:30",
                        "battery_level": 70
                    }
                ]
            }
        }
    ]
}
```


### 14 · App Content & Account

Static content for the settings/legal screens plus the account-deletion flow required by the Apple App Store and Google Play. All content endpoints are `GET` and public.

#### Countries & Cities

`GET /api/countries`

**Controller:** `Api\SettingController@get_countries`

**Auth:** public — no token required.

Public `GET`. Countries are rows with `type = main`, cities `type = sub`. Used by profile forms.

#### About

`GET /api/abouts`

**Controller:** `Api\SettingController@get_abouts`

**Auth:** public — no token required.

Public `GET`. Localised via `Accept-Language`.

#### Terms & Conditions

`GET /api/terms`

**Controller:** `Api\SettingController@get_terms`

**Auth:** public — no token required.

Public `GET`. Render this before calling **Accept Terms**.

#### Support

`GET /api/support`

**Controller:** `Api\SettingController@get_support`

**Auth:** public — no token required.

Public `GET`. Support contact channels for the help screen.

#### Request Account Deletion

`POST /api/v2/account/deletion_request`

**Controller:** `Api\V2\AccountDeletionController@submit`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:5,60`.

Store-compliance requirement. Submits a deletion request for admin review; the actual purge runs after a grace period. A second submit while one is already active returns the existing request instead of duplicating it.

**Errors:** `401 unauthorized`, `400 validation_error`.

**Body fields**

| Field | Rule | Notes |
|---|---|---|
| `reason` | sometimes|nullable|string|max:1000 | optional free text |

**Body example**

```json
{
    "reason": "No longer driving for this fleet"
}
```

#### My Deletion Request

`GET /api/v2/account/deletion_request`

**Controller:** `Api\V2\AccountDeletionController@me`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

No body. Returns `{request: {…}}` for the most recent request regardless of status (so a rejection and its reason stay visible), or `{request: null}` if none was ever filed.

#### Cancel Deletion Request

`DELETE /api/v2/account/deletion_request`

**Controller:** `Api\V2\AccountDeletionController@cancel`

**Auth:** required — `Authorization: Bearer <jwt>`. The driver identity is derived server-side from the token (`user_api()` → `fleet_drivers.user_id`); you do **not** need to send `driver_id`.

**Rate limit:** `throttle:10,60`.

No body. Cancels the active request. **Errors:** `404 no_active_request`.

**Body example**

```json
{}
```


## 5. Flutter integration guide

### 5.1 HTTP client (Dio)

```dart
final dio = Dio(BaseOptions(
  baseUrl: const String.fromEnvironment('BASE_URL', defaultValue: 'https://tajerid.com'),
  headers: {'Accept': 'application/json'},
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 30),
  validateStatus: (_) => true, // handle status codes ourselves
));

dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
  o.headers['Accept-Language'] = LocaleStore.current; // 'ar' | 'en'
  final jwt = await TokenStore.read();
  if (jwt != null) o.headers['Authorization'] = 'Bearer $jwt';
  h.next(o);
}));
```

### 5.2 Response normaliser

```dart
class ApiResult<T> { final int status; final T? data; final String? msg; final Map<String, List<String>>? bag; ... }

ApiResult<Map<String, dynamic>> normalise(Response r) {
  final body = r.data is Map ? Map<String, dynamic>.from(r.data) : <String, dynamic>{};
  // wrapped envelope: {status, data|message}
  if (body['status'] is int && (body.containsKey('data') || body.containsKey('message'))) {
    return ApiResult(status: body['status'], data: body['data'], msg: body['message']);
  }
  // bare envelope: {msg, ...payload} | {data: ...}
  final bag = body['bag'] is Map ? (body['bag'] as Map).map((k, v) => MapEntry('$k', List<String>.from(v))) : null;
  return ApiResult(status: r.statusCode ?? 0, data: body, msg: body['msg']?.toString(), bag: bag);
}
```

Treat `status >= 200 && < 300` as success, `400 + msg == 'validation_error'` as field errors (show `bag`), `401/403` as auth/permission (on `401` with `msg == 'unauthenticated'` or an invalid jwt, clear the token and go to login), `404` as not found, `429` as retry-after, `5xx` as retryable.

### 5.3 Id handling

Ids can arrive as `int` or `String` because of `JSON_NUMERIC_CHECK`. Model them as `int` with a tolerant parser: `int.parse(v.toString())`. Put ids in the URL path with string interpolation, never in the body (server ignores body ids for routing).

### 5.4 GET with parameters

Use Dio `queryParameters`; arrays serialise as `key[]=a&key[]=b` (Laravel style): `dio.get(path, queryParameters: {...}, options: Options(listFormat: ListFormat.multiCompatible))`.

### 5.5 Multipart uploads

Only `POST /api/v2/driver/uploads` (attachment) and `POST /api/auth/profile` (profile image) are multipart. Use `FormData.fromMap({'attachment': await MultipartFile.fromFile(path), 'module': 'driver_proof'})`. The response gives `file_path`; pass it to `POST /driver/stops/{stop_id}/proof` together with `watermark_data` (required for photo proofs) and `client_uuid` for idempotency.

### 5.6 Offline queue and idempotency

Stop actions accept `client_uuid`. Generate a UUID v4 per action, persist the queued action locally (Drift/Isar/Hive), and either replay it directly when back online or send it in `POST /api/v2/driver/sync/batch` (`events[].client_uuid`, `events[].action_type`, payload). The server de-duplicates on `client_uuid`, so retries are safe.

### 5.7 Location pings

While a route is `in_progress`, send `POST /api/v2/driver/location` every 15–30 s with `latitude`, `longitude`, `speed_kmh`, `heading`, `accuracy_meters`, `battery_level`, `logged_at` (server time format `YYYY-MM-DD HH:MM:SS`). When offline, buffer and send the batch form (`locations: [...]`).

### 5.8 Suggested repository layout

```
lib/data/api/
  api_client.dart        // Dio + interceptors + normaliser
  auth_api.dart          // 00 Session & Auth, 01 Biometric
  driver_api.dart        // 02 profile, 03 routes, 04 stops, 05 OTP, 06 barcode/seals, 07 proofs, 08 location
  incidents_api.dart     // 09
  notifications_api.dart // 10 (+ push register)
  training_api.dart      // 11 earnings/performance, 12 training
  sync_api.dart          // 13
  content_api.dart       // 14 countries/about/terms/support, account deletion
lib/data/models/        // freezed models with tolerant int/String parsing
```

### 5.9 Error and success `msg` strings (verified against the server code)

Errors: `validation_error`, `unauthenticated`, `not_a_driver`, `stop_not_found`, `route_not_found`, `route_not_found_or_not_assigned`, `no_route_for_date`, `must_arrive_before_pickup`, `must_arrive_before_delivery`, `stop_is_not_a_delivery`, `arrival_failed`, `pickup_failed`, `delivery_failed`, `watermark_required`, `no_reference`, `no_active_otp`, `otp_expired`, `invalid_code`, `max_attempts_reached`, `barcode_mismatch`, `item_not_in_stop`, `rejected_qty_exceeds_expected`, `no_pickup_seals_recorded`, `vehicle_not_found`, `vehicle_not_in_your_fleet`, `vehicle_not_in_your_org`, `invalid_email`, `invalid_password`, `suspended user`, `Too Many Attempts.`

Success: `arrived`, `stop_en_route`, `pickup_confirmed`, `delivery_confirmed`, `stop_skipped`, `route_started`, `route_completed`, `otp_resent`, `otp_verified`, `proof_uploaded`, `location_updated`, `incident_reported`.

Map them to localized UI messages and fall back to the raw `msg`.
