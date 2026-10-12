## v1.2.1

- New addon icon.
- Saved voice that isn't installed on this computer falls back to the default voice, with one message.
- Speech errors are reported once instead of being silently dropped.
- Warning at login when LittleWigs isn't loaded.
- The countdown timer only runs while there are active bars.
- `/hu add` and `/hu remove` show usage when the spell ID isn't a number.
- README documents the limits: keep each tank buster's BigWigs bar enabled, and abilities BigWigs doesn't recognise aren't announced.
- Offline unit tests and a smoke-test gate in CI.

## v1.2.0

- First working build: spoken tank-buster callouts from BigWigs/LittleWigs timers, with a countdown.
- Options window (`/hu`).
