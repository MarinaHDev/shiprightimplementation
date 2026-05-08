# ShipRight Dashboard Implementation

Fulfillment dashboard for internal ops staff. Replaces the spreadsheet workflow with a proper Rails 8 application: lifecycle-enforced order management, live carrier tracking, and bulk operations across orders.

---

## Quick start

```sh
bin/setup
```

Installs dependencies, sets up and seeds the database, then boots the server at <http://localhost:3000>.

To reset everything from scratch: `bin/setup --reset`
To skip the server boot: `bin/setup --skip-server`

**Login credentials (seeded)**

| Email | Password |
|---|---|
| `ops@shipright.test` | `password123` |

No registration page exists by design. New accounts go through the console:
```sh
bin/rails c
> User.create!(name: "New Staff", email_address: "new@shipright.test", password: "password123")
```

---

## Running tests

```sh
bin/rails test
```

It covers: state machine transitions and guards, audit trail correctness, service objects (single and bulk transitions), carrier gateway retry and error handling, job idempotency, and controller auth + happy/sad paths.

---

## How it's built

### The stack

- Rails 8.1 / Ruby 3.4 / PostgreSQL 14+
- Hotwire: Turbo Drive + Turbo Streams over Action Cable (Solid Cable)
- Stimulus for the bulk-select bar
- Tailwind CSS
- Solid Queue for background jobs, Solid Cache for caching
- AASM for the order state machine
- PaperTrail for audit history, wrapped in a reusable `Auditable` concern
- Minitest + FactoryBot + Faker

No Docker, no CI/CD pipeline, no production deploy config — per the assignment brief.

---

### Order lifecycle

This is the core of the system. The state machine lives on the `Order` model via AASM:

```
pending → approved → shipped → delivered
                   ↘ cancelled (from pending, approved, or shipped)
```


The rules sit on the model because they are invariants of what an order *is*, independent of how the UI happens to call them today.

Controllers never fire transitions directly. They go through `Orders::Transition`, which:

- returns a `Result` value object (no rescued exceptions in the controller)
- converts `AASM::InvalidTransition` into a human-readable message like `"Cannot ship an order that is pending"`
- handles after-effects in one place (e.g. enqueuing `TrackingSyncJob` on `:ship`)

`Orders::BulkTransition` reuses the same service per-order. Bulk is a UI affordance, not a separate code path — the state machine is never bypassed.

---

### Audit trail

Every status change is recorded via PaperTrail, scoped to the `status` column only. The integration is wrapped in a small `Auditable` concern:

```ruby
include Auditable
audited only: [:status]
```

Any future model (`Shipment`, `Refund`, etc.) gets the same trail with those two lines. `#audit_history` returns a plain struct so views don't couple to PaperTrail internals. The whodunnit is set to the signed-in user's email address in every request.

---

### Carrier integration

Carrier is treated as an unreliable external dependency. The boundary is `lib/carrier/`:

- `Carrier::FakeClient` — deterministic simulator, seeded per tracking number so the dedupe path is testable
- `Carrier::Gateway` — the only seam the rest of the app touches. Retries transient errors with backoff, maps all failure modes to a `Result` value, logs everything
- Swapping in a real carrier means implementing one method and pointing `Carrier.gateway` at the new client

`TrackingSyncJob` runs in the background after `:ship`, deduplicates events by `(order_id, carrier_event_id)`, and broadcasts a Turbo Stream replace to the order detail page when done. If the carrier fails the job exits cleanly and the staff can retry manually.

---

### Real-time updates

The order detail page subscribes to a Turbo Stream channel scoped to the order:

```erb
<%= turbo_stream_from @order %>
```

When the tracking sync job finishes it broadcasts a replace of the timeline partial. No polling, no page refresh.

---

### Money

Prices stored as `decimal(12, 2)` on both `products.price` and `line_items.unit_price`. Unit price is snapshotted into the line item at creation so order totals stay stable when catalog prices change later.

---

### Authentication

Uses Rails 8's built-in generator (`bin/rails generate authentication`). No registration route is wired, sessions are signed-cookie-backed, and `Authentication` is included in `ApplicationController` so every action requires a login for default.

---

## Decisions and tradeoffs

| Decision | What I chose | What I considered | Why |
|---|---|---|---|
| State machine | AASM | Hand-rolled concern | AASM gives guards, declarative events, and a readable DSL for ~6 states without much overhead |
| Audit trail | PaperTrail + `Auditable` concern | Custom polymorphic table | PaperTrail solves whodunnit and change diffs out of the box; the concern keeps it swappable |
| Money storage | `decimal(12,2)` | Integer cents | Reads naturally in psql; rounding behavior is identical for the operations this dashboard does |
| Background jobs | Solid Queue (async adapter in dev) | Sidekiq | No Redis needed; evaluator gets a single `bin/setup` with no extra services |
| Cancel from shipped | Allowed | Disallow after approval | Operations need to flag recalls after dispatch; terminal only at `delivered` |

---

## What I'd add with more time

- **Pagination on the index.** Right now it loads all orders but keyset pagination is the right fix at any real volume.
- **Row-level locking on transitions.** Two staff approving the same order simultaneously will both pass `may_approve?` — the service catches the eventual `AASM::InvalidTransition` gracefully, but a `with_lock` would be cleaner.
- **Role separation.** Every authenticated user has the same permissions. A real ops team needs at least a supervisor/operator split; Pundit would be the natural fit.
- **System tests.** The controller tests cover HTTP-level happy/sad paths but don't exercise the Stimulus bulk-select or the Turbo Stream broadcast end-to-end.

---

## Edge cases noted, not implemented

- **Concurrent transitions** — handled gracefully at the service layer but not locked at the DB level
- **Carrier rate limits** — the fake client doesn't simulate them; the gateway has the shape to add a token bucket
- **Webhook-driven tracking** — a real carrier would push events rather than us polling; the adapter boundary is already in the right place for this
- **Line item editing after creation** — the dashboard is read + transition only