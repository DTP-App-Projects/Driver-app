# Digital Trade Portal — Driver App · Flutter Build Brief

> **How to use this file:** paste it (or attach it) to Claude together with
> `dtp_driver_api.postman_collection.json`, both of which sit on your Desktop.
> The Postman collection is the authoritative API contract — every endpoint below is
> documented there with its exact validation rules, error codes and sample payloads.

---

## The prompt

You are building **Digital Trade Portal Driver**, a production Flutter app for delivery drivers in a
Saudi B2B logistics platform. The Laravel backend already exists and cannot be changed —
build the client against the contract in `dtp_driver_api.postman_collection.json`.

Read that collection first. Each request's **Description** tab contains the real
`Validator::make()` rules, response shapes and error strings pulled from the controllers.
Do not invent endpoints, fields or status codes; if something you need is missing, list it
as an open question rather than inventing it.

Ship a complete, runnable app — not a scaffold. Every screen listed below must be built,
wired to the real API, and cover its loading / empty / error / offline states.

---

## 1. Non-negotiable constraints

| Constraint | Detail |
|---|---|
| **Language** | Arabic-first, RTL by default. English is a full second locale. The user's choice is persisted server-side via `POST /api/v2/driver/language`. |
| **Offline-first** | The driver works in warehouses, basements and industrial zones. Every mutating action must survive no-signal. See §5. |
| **One-handed use** | Drivers hold a phone in one hand and a carton in the other. Large tap targets (min 56dp), bottom-anchored primary actions, no tiny checkboxes. |
| **Loading skeletons** | Every list and detail screen has a shimmer skeleton matching its final layout. Never a bare spinner on a full screen, never a layout jump when data lands. |
| **Battery** | Location tracking is the main drain. Batch pings, use distance filters, stop tracking when no route is `in_progress`. |

---

## 2. Stack

- Flutter 3.x, Dart 3, null-safe.
- **State:** Riverpod 2 (or Bloc — pick one and stay consistent).
- **HTTP:** Dio + interceptors (auth header, locale header, retry, logging).
- **Local DB:** Drift or Isar — needed for the offline queue and route cache, not just prefs.
- **Secure storage:** `flutter_secure_storage` for the session token.
- **Location:** `geolocator` + a foreground service (`flutter_background_geolocation` or
  `flutter_foreground_task`) so tracking survives the app being backgrounded.
- **Camera/scan:** `camera` + `mobile_scanner` for barcodes.
- **Push:** `firebase_messaging` (Android) + APNs (iOS).
- **Maps:** Google Maps Flutter.
- Layers: `data` (dio clients, DTOs, local DB) → `domain` (entities, repositories, use cases)
  → `presentation` (screens, controllers). No `http` calls from widgets.

---

## 3. Auth — read this carefully, it is unusual

There is **no OAuth and no Sanctum**. Login returns a 200-character random string stored on
`users.jwt`. Despite the name it is **not a JWT** — do not try to decode it, there are no
claims, no `exp`, and no refresh endpoint.

```
POST /api/auth/login   { token: <fcm_token>, email, password }
  → 200 { user: { id, jwt, ... } }
```

Persist `user.jwt` in secure storage and attach it to **every** subsequent request as:

```
jwt: <token>                     // what iOS sends
Authorization: Bearer <token>    // what Android sends
```

The server accepts either. Pick one in your Dio interceptor.

**Rules the client must respect:**

1. **Never send `driver_id`.** Every `/api/v2/driver/*` endpoint derives the driver from the
   token by looking up `fleet_drivers WHERE user_id = <authenticated user>`. Same for stops:
   a `stop_id` belonging to another driver's route returns `404 stop_not_found`.
2. **`403 {"msg":"not_a_driver"}` is not a login failure.** It means the account is valid but
   has no driver record. Show a dedicated "your account is not set up as a driver — contact
   your fleet manager" screen with a sign-out button. Do **not** loop back to login.
3. Legacy `/api/auth/*` endpoints *also* want `user_id` in the body, cross-checked against
   the token. The `/api/v2/driver/*` endpoints do not. Handle both in the interceptor.
4. The login response's `phone` is prefixed with the literal string `m_p` — strip it.
5. There is no token expiry signal. Treat any `401` as "session dead" → clear storage,
   unregister the push token, return to login.
6. **Biometrics:** `POST /api/v2/biometric/verify` returns an `api_token`, but authentication
   reads `users.jwt`. That returned token does **not** currently work as a session token.
   So implement biometrics as a **local unlock gate** over the stored `jwt`, not as a
   server round-trip. Flag this in your README as a backend inconsistency to fix later.

---

## 4. Response envelopes — normalise them

The backend uses **two different shapes**, and the driver app touches both:

```jsonc
// DriverAppController, UploadController, AccountDeletionController
{ "msg": "delivery_confirmed", "stop": { ... } }        // real HTTP status codes

// DriverTrainingController, DriverPerformanceController,
// IncidentController, PushController, BiometricController
{ "status": 200, "data": { ... } }                       // status duplicated in the body
```

Write one `ApiResponse<T>` unwrapper that handles both.

Two more parsing traps:

- Responses are encoded with **`JSON_NUMERIC_CHECK`**: any numeric-looking *string* becomes a
  *number*. A phone number, SKU code or seal number made only of digits can arrive as an
  `int`. All your DTOs must parse these fields leniently (`json['x']?.toString()`).
- **`POST /api/v2/driver/stop/barcode/verify` returns HTTP 200 on a mismatch**, with
  `{"success": false, "msg": "barcode_mismatch"}`. Branch on `success`, never on the status
  code.

---

## 5. Offline-first architecture (the core of this app)

Every mutating action goes into a **local outbox table** first, then to the network. The
backend has a purpose-built replay endpoint:

```
POST /api/v2/driver/sync/batch
{ "events": [ { client_uuid, action_type, payload, client_created_at } ] }
```

- The server sorts by `client_created_at` — ordering survives an out-of-order flush.
- It **deduplicates on `client_uuid`** — a replayed event that already landed comes back as
  `already_synced`, not a double-post. **Generate the UUID once, on creation, and never
  regenerate it on retry.** This is the single most important client-side rule.
- Supported `action_type`s: `arrive`, `pickup`, `deliver`, `skip`, `proof_upload`,
  `location_batch`, `incident`. Each `payload` is exactly the body you would have POSTed
  online. Anything else fails with `unknown_action_type`.
- Per-event results: `synced` | `already_synced` | `failed` (with `error`) | `skipped`.
  Failures are retried server-side up to 3× by a background job, but keep them queued
  locally too and surface a "pending sync" badge with a manual retry.

**File uploads are the exception.** `POST /api/v2/driver/uploads/attachment` is multipart and
cannot be queued through `sync/batch` — `proof_upload` replays *metadata only* and assumes the
file already exists server-side. So: cache photos locally, and on reconnect upload the bytes
**first**, then replay the proof metadata with the returned `file_path`.

Design the outbox as: `(id, client_uuid, action_type, payload_json, created_at, status,
attempts, last_error)`. Flush on connectivity regain, on app resume, and every N minutes.

---

## 6. The delivery workflow — server-enforced state machine

```
pending ──(en_route)──► en_route ──(arrive)──► arrived ──(pickup|deliver)──► completed
   └────────────────────────(skip)────────────────────────────────────────► skipped
```

The server rejects out-of-order calls (`must_arrive_before_pickup`,
`must_arrive_before_delivery`, `stop_not_available_for_arrival`, `stop_cannot_be_skipped`).
Mirror this state machine locally so the UI only ever offers legal actions — never rely on
the error to tell the driver they tapped the wrong button.

### Pickup stop
1. `stop/en_route` → notifies the supplier the driver is heading over.
2. `stop/arrive` (with GPS) → server runs a **geofence check** against the branch, stores
   `distance_from_branch_meters` and appends a `[GEOFENCE WARNING]` note if the driver is
   outside the radius. The call still succeeds — show a soft warning, don't block.
3. Scan barcodes per line via `stop/barcode/verify` (incremental, mutates the item rows).
4. Record seals via `stop/seal/submit` with `mode: "pickup"`.
5. `stop/pickup` with `items[]` (`loaded_qty` per line), `seal_numbers[]`, optional
   `temperature` (cold chain), departure coordinates.
   → Server validates loaded vs expected (`quantity_validation_failed`) and enforces scanning
   on lines flagged `barcode_required` (`barcode_validation_failed`). Both come back as
   `422 {"msg":"pickup_failed","error":"<detail json>"}` — **parse the embedded JSON and
   highlight the offending lines in the UI**, don't dump the raw string.

### Delivery stop
1. `stop/arrive` → for a delivery the server also **generates and SMSes a 6-digit OTP** to the
   receiver. The response carries `otp_required`, `otp_sent_to`, `otp_expires_at` and
   `expected_seal_numbers`. If the SMS fails you get `otp_error` — show manual entry, never
   block the driver.
2. Verify seals with `stop/seal/submit` `mode: "delivery"` — the report includes
   `mismatched`; a non-zero value is **tamper evidence** and must be shown loudly.
3. OTP: `driver/otp/verify` (or send `otp_code` inline on the delivery call).
   Wrong code → `{success:false, msg:"invalid_code", attempts_remaining:N}`.
   `otp_expired` / `max_attempts_reached` / `no_active_otp` all return
   `requires_generation: true` → offer **Resend**, not another attempt.
4. Partial refusals: `stop/partial_reject` per line (adds to `returned_qty`, recomputes
   `delivered_qty`). Rejects `rejected_qty > expected_qty`.
5. Photo proof: upload bytes → `driver/proof/upload` with the returned `file_path`.
   **Photo proofs are rejected without `watermark_data`** (`400 watermark_required`).
   Build the watermark client-side — timestamp, GPS, driver name, route code, stop id — burn
   it into the image *and* send it as the `watermark_data` object.
6. `stop/deliver` with `items[]` where **`delivered_qty + returned_qty + damaged_qty` must
   reconcile against `expected_qty`** or the whole call fails with `quantity_balance_failed`.
   Validate this client-side before sending — never let the driver hit a server rejection for
   arithmetic you could have checked.

> ⚠️ **The OTP bypass trap.** If you call `stop/deliver` with no `otp_code` and no prior
> verification, the server does **not** fail — it silently records an OTP **bypass** using
> `bypass_reason` (defaulting to `no_otp_provided`) and completes the delivery, flagging it so
> the trader can dispute. Always send a real, driver-selected `bypass_reason`
> (e.g. `receiver_phone_unreachable`, `receiver_refused_otp`) behind an explicit confirmation
> sheet. Never let a bypass happen by accident.

7. After delivery, poll `stop/receipt_status` to show the trader's verdict:
   `pending_trader_action` → `accepted` | `partial` | `rejected` | `disputed`.

---

## 7. Screens to build

| # | Screen | Endpoints | Notes |
|---|---|---|---|
| 1 | Splash / session restore | — | Secure-storage token → route to Home or Login. |
| 2 | Login | `auth/update_token`, `auth/login` | Register the device token *before* login. |
| 3 | Forgot password (3 steps) | `send_reset`, `check_reset`, `password_reset` | |
| 4 | Not-a-driver gate | — | Shown on `403 not_a_driver`. |
| 5 | First-run: language + terms | `terms`, `driver/language`, `driver/terms/accept` | One-time gate. |
| 6 | **Home / Today's route** | `driver/today_route` | Route card + ordered stop list. Must render `late_routes` as a red banner (overdue routes from previous days) and `upcoming_routes` as a preview. Skeleton list while loading. |
| 7 | Route detail + map | same payload | Stops on a map, polyline, progress `completed_stops / total_stops`. |
| 8 | **Stop detail** | the whole of §6 | The workhorse screen. Bottom action bar changes with stop status. |
| 9 | Item checklist | `stop/barcode/verify`, `stop/partial_reject` | Per-line qty steppers + scan state. |
| 10 | Barcode scanner | `stop/barcode/verify` | Full-screen, torch toggle, haptic on match. |
| 11 | Seal capture | `stop/seal/submit` | Pickup entry + delivery verification with mismatch alert. |
| 12 | OTP sheet | `driver/otp/*` | Countdown to `otp_expires_at`, resend cooldown (server allows 6/min), attempts remaining, explicit bypass path. |
| 13 | Proof camera | `driver/uploads/attachment`, `driver/proof/upload` | Watermark overlay, signature pad for `signature` proofs. |
| 14 | Skip stop | `stop/skip` | Reason picker (never send the bare default). |
| 15 | End of day | `driver/end_of_day_summary`, `route/complete` | Full shift summary before closing the route. |
| 16 | History | `driver/history` | Paginated (15/page), Laravel paginator envelope. |
| 17 | Incidents | `driver/incident/report`, `incident/*` | Report form + list with SLA badge from `incident/age`. |
| 18 | Notifications inbox | `driver/notifications`, `/read`, `/read_all` | Latest 100, unread = `read_at == null`. |
| 19 | Earnings | `driver/earnings` | Current month (live-computed) + last 6 closed periods. Note `deductions_total` is always `0.0` on the current month — it only becomes real once payroll closes the period. |
| 20 | Performance | `driver/performance` | Date-range KPIs, defaults to last 30 days. |
| 21 | Training | `driver/training/*` | Curriculum → module → quiz → certificate. |
| 22 | Profile & vehicle | `driver/profile`, `/profile/update`, `available_vehicles`, `assign_vehicle` | Licence expiry warning when `driver_license_expiry` is near. |
| 23 | Settings | `driver/language`, push toggles, `push/test` | |
| 24 | Delete account | `account/deletion-request*` | **Required by App Store & Play Store.** |
| 25 | Sync status | local outbox + `sync/batch` | Pending count, per-item error, manual retry. |

---

## 8. Location tracking

- Foreground service with a persistent notification while a route is `in_progress`; stop it
  entirely when no route is active.
- Buffer samples locally, flush **batched** every 30–60 s to `driver/location/update` using
  the `{ "locations": [ ... ] }` shape (the flat single-ping shape exists but is wasteful).
- Each sample: `latitude`, `longitude`, `speed_kmh`, `heading`, `accuracy_meters`,
  `battery_level`, `logged_at`. **Always send `logged_at`** — it is what makes offline replay
  produce an accurate trail.
- Send `battery_level`: ops uses it to distinguish a dead phone from a stalled driver.
- This data feeds the live map, ETA, deviation alerts, and the `actual_distance_km` computed
  when the route completes.

---

## 9. Push notifications

- Register on login **and on every token refresh**: `push/register` with
  `platform`, `locale`, `device_id`, `device_model`, `os_version`, and
  **`app_variant: "driver"`** — that field is what routes driver-only pushes to this app.
- `push/unregister` on logout, or the device keeps receiving another driver's assignments.
- Handle foreground, background and terminated states; deep-link the payload to the right
  stop or incident.

---

## 10. Error handling contract

Map the backend's string codes to localised Arabic/English copy. At minimum:

`not_a_driver`, `stop_not_found`, `route_not_found`, `route_not_found_or_not_assigned`,
`must_arrive_before_pickup`, `must_arrive_before_delivery`, `stop_is_not_a_pickup`,
`stop_is_not_a_delivery`, `stop_cannot_be_skipped`, `cannot_mark_en_route_in_status_*`,
`quantity_validation_failed`, `quantity_balance_failed`, `barcode_validation_failed`,
`barcode_mismatch`, `watermark_required`, `otp_verification_failed`, `invalid_code`,
`otp_expired`, `max_attempts_reached`, `no_active_otp`, `rejected_qty_exceeds_expected`,
`item_not_in_stop`, `vehicle_not_found`, `vehicle_not_in_your_org`, `vehicle_not_in_your_fleet`,
`no_route_for_date`, `unknown_action_type`.

Never show a raw backend string to a driver. Never show a stack trace. Every error state gets
a retry affordance.

**Rate limits** are per-endpoint (`throttle:6,1` on OTP resend, `throttle:10,1` on OTP verify
and login, `throttle:30,1` and `throttle:60,1` elsewhere — each request's description in the
collection states its own). Handle `429` with a visible cooldown, and never auto-retry OTP
endpoints in a tight loop.

---

## 11. Definition of done

- [ ] Every screen in §7 built, wired to the real API, with skeleton / empty / error / offline states.
- [ ] Full Arabic RTL + English, switchable at runtime, persisted server-side.
- [ ] Outbox survives force-quit; UUIDs stable across retries; verified by airplane-mode testing.
- [ ] Quantity balance and barcode requirements validated client-side *before* submitting.
- [ ] OTP bypass impossible without an explicit driver-chosen reason.
- [ ] Photo proofs always carry `watermark_data`.
- [ ] Location tracking starts/stops with route status; no drain while idle.
- [ ] Both response envelopes and `JSON_NUMERIC_CHECK` coercion handled in one place.
- [ ] Account deletion flow present (store compliance).
- [ ] Unit tests on the DTO layer and the offline queue; widget tests on the stop state machine.
- [ ] README documenting setup, and the biometric `api_token` vs `jwt` inconsistency.

---

## 12. Open questions to raise, not guess

- `driver_notifications` may not be migrated on every environment — those endpoints return
  `{data: []}` rather than erroring. Confirm before treating empty as a real empty state.
- `DriverPerformanceService::forDriver()`'s exact field set is build-dependent — inspect a
  live response and code defensively.
- The training quiz `answers[].answer` type (string vs index) depends on the question type —
  confirm against real curriculum data.
