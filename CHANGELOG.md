## v1.3.1

- Code restructured to match Pick Pocket Tracker: lowercase files split by job (config, utils, data, speech, watcher, options, events, commands, init), `NS` modules, 2-space indent.
- Fix: with a long countdown, a cast bar starting just before the hit could repeat the callout.
- Login no longer warns about LittleWigs when it's installed but not loaded yet (BigWigs loads it in dungeons).
- Unknown `/hu` commands, and `/hu lead` or `/hu count` without a number, now print an error instead of opening the window.
- Addon compartment entry shows a tooltip.

## v1.3.0

- New "Count down" switch: turn the countdown off without losing your "Count down from" number.
- New "Say the seconds" switch (`/hu seconds`): leave "in 5" out of the first callout, e.g. just "Blade Combo" 5 seconds before the hit.

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
