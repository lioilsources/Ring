# CONTACT

Mobilní multiplayer hra — dva prsty, dva lidé, jeden prsten.

Každý hráč ovládá svůj prst na sdíleném prstenu s reálnou fyzikou. Síla, tření, šťouchnutí a haptická zpětná vazba přes Supabase Realtime Broadcast.

## Stack

- **Flutter** — iOS + Android
- **Fyzika** — vlastní Dart engine, 60Hz, Euler integrace
- **Realtime** — Supabase Broadcast (~20–50ms latency)
- **Backend** — Supabase DB + Auth (Apple Sign In / magic link)
- **Haptics** — custom intensity z odporu protihráčovy síly

## Architektura

```
Zařízení A                 Supabase Realtime              Zařízení B
┌─────────────┐            ┌───────────────┐            ┌─────────────┐
│ PhysicsWorld│──finger───►│ Broadcast     │◄──finger───│ PhysicsWorld│
│ HapticEngine│◄──finger───│ game:{roomId} │───finger──►│ HapticEngine│
└─────────────┘            └───────────────┘            └─────────────┘
```

## Projekt

```
contact/          Flutter app
  lib/
    features/
      game/       fyzika, renderer, network
      auth/       Apple Sign In, magic link
      friends/    roster, invite flow
      lobby/      čekání na protihráče
Prompts/          implementační plán
```

## Spuštění

```bash
cd contact
flutter pub get
flutter run
```

Vyžaduje Supabase projekt — zkopíruj `lib/shared/supabase_client.dart` a doplň URL + anon key.
