# Teen Patti

Flutter Teen Patti game (virtual chips only) with an offline AI mode and an online mode backed by an
authoritative Dart server. All game rules live in one pure-Dart package that the app, the AI and the
server share.

```
packages/teen_patti_engine   rules, hand evaluator, AI (no Flutter dependency)
server/                      WebSocket server, rooms, anti-cheat, schema.sql
lib/                         Flutter app (core / features / shared)
docs/PHASE1_PLAN.md          original architecture plan
```

## Run

Flutter is installed at `D:\dev\flutter` on this machine (add `D:\dev\flutter\bin` to `PATH`).

```
flutter pub get
flutter run -d chrome          # or -d windows
```

Online mode needs the server:

```
cd server
dart pub get
dart run bin/server.dart       # PORT=8080 by default
```

In the app: Settings > Server address (default `http://127.0.0.1:8080`; use your LAN IP from a phone,
`http://10.0.2.2:8080` from the Android emulator).

## Test

```
flutter test                                   # app: UI, offline game, online integration (in-process server)
cd packages/teen_patti_engine && dart test     # engine + AI
cd server && dart test                         # real WebSocket integration tests
dart run packages/teen_patti_engine/tool/benchmark.dart
```

## Rules implemented

Boot, blind / seen, chaal (call), raise (stake doubles up to a cap), pack (fold), show (two players left),
side show (seen player asks the previous seen player; weaker hand folds, tie = requester folds), pot limit
(forced showdown). Ranking: Trail > Pure Sequence > Sequence > Color > Pair > High Card; sequences order
A-K-Q > A-2-3 > K-Q-J > ... > 4-3-2. Show tie: the player who asked for the show loses.

## Not done / known gaps

- **PostgreSQL**: `server/schema.sql` is the target schema; only an in-memory `Store` is implemented.
  Accounts, balances and history are lost when the server restarts.
- **Audio**: the sound layer is an abstraction (`SoundService`) backed by system click sounds. No sound or
  music assets are bundled. Haptics are real.
- **Friends / presence / "online players"** need persistence and are not built; private room codes are the
  way to play with friends.
- **Auth** is guest-only (token per install). No email/social login, no logout/account screens.
- **Not run on devices**: Android/iOS builds, real-device frame rate and memory profiling were not done here
  (no Android SDK command-line tools; no Mac). Web and Windows release builds succeed.
- Result screen is an overlay on the table rather than a separate route.
- Language and notification settings are stored but have no effect yet.
