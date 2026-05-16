# CONTACT — Implementační plán

> Mobilní multiplayer appka: dva prsty, dva lidé, jeden prsten, reálná fyzika přes Supabase Broadcast.

---

## Stack

| Vrstva | Technologie |
|---|---|
| Frontend | Flutter (iOS + Android) |
| Fyzika | Vlastní Dart engine, 60Hz, Euler integrace |
| Realtime | Supabase Realtime Broadcast |
| Backend (thin) | Supabase DB + Auth |
| Haptics | `HapticFeedback` + custom intensity |
| Renderer | `CustomPainter` / Impeller |

---

## Architektura

```
Zařízení A                    Supabase Realtime              Zařízení B
┌──────────────────┐          ┌─────────────────┐          ┌──────────────────┐
│ PhysicsWorld     │          │ Broadcast        │          │ PhysicsWorld     │
│ - RingBody       │──input──►│ channel:         │──input──►│ - RingBody       │
│ - FingerA (local)│          │ game:{roomId}    │          │ - FingerB (local)│
│ - FingerB (remote│◄─input───│                  │◄─input───│ - FingerA (remote│
│                  │          │ ring_hint (2s)   │          │                  │
│ HapticEngine     │          └─────────────────┘          │ HapticEngine     │
└──────────────────┘                                        └──────────────────┘

Supabase DB:
├── users         (id, name, avatar_url)
├── friendships   (user_a, user_b, status)
├── invites       (token, from_id, to_id, room_id, expires_at)
└── rooms         (id, host_id, guest_id, created_at)
```

---

## Fyzikální model

### RingBody

```dart
class RingBody {
  Offset position;        // střed prstenu
  Offset velocity;        // px/s
  double mass     = 1.0;
  double radius   = 44.0;
  double drag     = 0.018;       // odpor vzduchu
  double elasticity = 0.72;      // odraz od stěn
  double wallFriction = 0.86;    // tření při dopadu

  void applyForce(Offset f, double dt) {
    velocity += (f / mass) * dt;
  }

  void applyImpulse(Offset j) {
    velocity += j / mass;        // šťouchnutí
  }

  void tick(double dt, Size bounds) {
    velocity *= (1.0 - drag);    // drag
    position += velocity * dt;
    _bounceWalls(bounds);
  }
}
```

### Síla prstu na prsten

```dart
// Prst musí být v kontaktní zóně (radius * 1.6)
Offset fingerForce(Offset fingerPos, double dt) {
  final delta = fingerPos - ring.position;
  final dist  = delta.distance;
  if (dist > ring.radius * 1.6) return Offset.zero;

  const stiffness = 180.0;
  return delta.normalized * stiffness * (1.0 - dist / (ring.radius * 1.6));
}
```

### Šťouchnutí (flick)

```dart
// Detekce: velocity prstu za poslední 2 framy
Offset flickImpulse(Offset prevFinger, Offset currFinger, double dt) {
  final fingerVel = (currFinger - prevFinger) / dt;
  if (fingerVel.distance < 300) return Offset.zero;  // threshold
  return fingerVel * 0.008 * ring.mass;              // tuning koeficient
}
```

### Odpor (haptic)

```dart
// resistance = jak moc remote prst brání pohybu
double calcResistance(Offset localForce, Offset remoteForce) {
  final dot = localForce.dot(remoteForce);           // negativní = protisměr
  if (dot >= 0) return 0.0;
  return (-dot / (localForce.distance * remoteForce.distance + 0.001))
      .clamp(0.0, 1.0);
}
```

### Soft sync (desync korekce)

```dart
// Host broadcastuje ring_hint každé 2s
// Guest aplikuje jemný lerp
ring.position = Offset.lerp(ring.position, remoteHintPos, 0.12);
```

---

## Supabase Broadcast — zprávy

| Typ | Odesílá | Payload |
|---|---|---|
| `finger` | Oba, ~60fps | `{ x, y, active, impulse? }` |
| `ring_hint` | Jen host, každé 2s | `{ rx, ry, vx, vy }` |
| `presence` | Supabase auto | online status |

```dart
// Odeslání
channel.sendBroadcast('finger', {
  'x': pos.dx, 'y': pos.dy,
  'active': isDown,
  'impulse': flick != null ? {'dx': flick.dx, 'dy': flick.dy} : null,
});

// Příjem
channel.onBroadcast('finger', (payload) {
  remoteFingerPos = Offset(payload['x'], payload['y']);
  remoteFingerActive = payload['active'];
  if (payload['impulse'] != null) {
    ring.applyImpulse(Offset(payload['impulse']['dx'], payload['impulse']['dy']));
  }
});
```

---

## Struktura Flutter projektu

```
lib/
├── main.dart
├── app/
│   ├── router.dart              // GoRouter: splash → auth → home → game → invite
│   └── theme.dart
├── features/
│   ├── auth/
│   │   ├── auth_page.dart       // Apple Sign In / magic link
│   │   └── auth_bloc.dart
│   ├── friends/
│   │   ├── friends_page.dart    // roster přátel + online status
│   │   ├── friends_bloc.dart
│   │   └── invite_service.dart  // generování + přijímání invite
│   ├── lobby/
│   │   ├── lobby_page.dart      // čekání na protihráče
│   │   └── room_service.dart    // vytváření/joinování room
│   └── game/
│       ├── game_page.dart       // fullscreen canvas
│       ├── game_bloc.dart       // WS stav, input, haptics
│       ├── physics/
│       │   ├── ring_body.dart
│       │   ├── physics_world.dart
│       │   └── flick_detector.dart
│       ├── rendering/
│       │   ├── game_painter.dart    // CustomPainter
│       │   └── ring_fx.dart         // glow, particle při šťouchnutí
│       └── network/
│           ├── broadcast_service.dart   // Supabase channel wrapper
│           └── sync_service.dart        // ring_hint logika
├── shared/
│   ├── haptic_engine.dart
│   └── supabase_client.dart
```

---

## Supabase DB schéma

```sql
-- Users
create table users (
  id         uuid primary key references auth.users,
  name       text not null,
  avatar_url text,
  created_at timestamptz default now()
);

-- Friendships
create table friendships (
  id       uuid primary key default gen_random_uuid(),
  user_a   uuid references users not null,
  user_b   uuid references users not null,
  status   text check (status in ('pending','accepted')) default 'pending',
  created_at timestamptz default now(),
  unique(user_a, user_b)
);

-- Rooms
create table rooms (
  id         uuid primary key default gen_random_uuid(),
  host_id    uuid references users not null,
  guest_id   uuid references users,
  created_at timestamptz default now()
);

-- Invites
create table invites (
  token      text primary key,
  from_id    uuid references users not null,
  to_id      uuid references users,      -- null = otevřený invite link
  room_id    uuid references rooms not null,
  expires_at timestamptz not null,
  used       boolean default false
);
```

---

## Invite flow

```
Hráč A klikne "Pozvat kamaráda"
  → POST /invite (server-side Supabase function)
  → vrátí token + deep link: contact.ol1n.com/invite/{token}
  → Hráč A sdílí link (share sheet iOS)

Hráč B klikne link
  → Universal Link otevře appku
  → AppRouter přečte token z URL
  → GET /invite/{token} → ověří platnost
  → Hráč B joině room_id z tokenu
  → Oba vstoupí do Lobby → game start
```

---

## Implementační fáze

### Fáze 1 — Fyzika offline (3–4 dny)
- [ ] `RingBody`, `PhysicsWorld`, `FlickDetector`
- [ ] `GamePainter` — prsten, finger glow, stěny
- [ ] Lokální single-player test (1 prst ovládá prsten)
- [ ] Haptic engine — intensity z resistance
- [ ] Ladění fyzikálních konstant (drag, elasticity, stiffness)

### Fáze 2 — Supabase setup (1–2 dny)
- [ ] Supabase projekt, DB migrace
- [ ] Flutter Supabase client init
- [ ] Auth (Apple Sign In + email magic link)
- [ ] `BroadcastService` wrapper

### Fáze 3 — Multiplayer (3–4 dny)
- [ ] Broadcast `finger` input v game loop
- [ ] Příjem remote finger → aplikace síly
- [ ] Flick přes síť (impulse v payloadu)
- [ ] `SyncService` — ring_hint každé 2s od hostitele
- [ ] Soft lerp korekce na guestu
- [ ] Presence — zobrazení "protihráč připojen"

### Fáze 4 — Sociální vrstva (3–4 dny)
- [ ] Friends roster page
- [ ] Přidání přítele (search by name / username)
- [ ] Online status přes Supabase Presence
- [ ] Invite generování + deep link
- [ ] Universal Links konfigurace (iOS `apple-app-site-association`)
- [ ] Lobby screen (čekání + avatar protihráče)

### Fáze 5 — Polish (2–3 dny)
- [ ] Particle efekt při šťouchnutí
- [ ] Zvuky (kontakt prstenu se stěnou, šťouchnutí)
- [ ] Animovaný prsten v idle stavu (dýchání / pulzování)
- [ ] Disconnect handling — "Protihráč se odpojil"
- [ ] Dark mode, minimalistický UI

---

## Fyzikální konstanty — výchozí hodnoty k ladění

```dart
const kRingMass       = 1.0;
const kRingRadius     = 44.0;
const kDrag           = 0.018;
const kElasticity     = 0.72;
const kWallFriction   = 0.86;
const kStiffness      = 180.0;
const kContactZone    = 1.6;    // násobek radius
const kFlickThreshold = 300.0;  // px/s
const kFlickScale     = 0.008;
const kSyncInterval   = 2.0;    // sekundy mezi ring_hint
const kSyncLerp       = 0.12;
```

---

## AGENTS.md hint pro Claude Code

```markdown
## CONTACT app

Flutter projekt. Fyzika v `lib/features/game/physics/`.
Supabase Broadcast v `lib/features/game/network/`.
Piš Dart komentáře česky, testy anglicky.
Fyzikální konstanty jsou v `lib/features/game/physics/constants.dart` — neměň bez komentáře proč.
Každý Broadcast payload musí mít `ts: DateTime.now().millisecondsSinceEpoch` pro budoucí lag měření.
```

---

## Poznámky

- **Desync je OK** — appka není kompetitivní, zážitek je důležitější než pixel-perfect sync
- **Latency budget:** Supabase Broadcast ~20–50ms, pro haptiku to stačí
- **Škálování:** Supabase Realtime zvládne stovky concurrent rooms bez ops práce
- **Budoucí rozšíření:** více hráčů (3+) = více prstů na stejném prstenu, jen rozšíř broadcast schéma
