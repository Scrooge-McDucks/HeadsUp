<img src="assets/HeadsUp.png" alt="Heads Up icon" width="128" align="right">

# Heads Up

Heads Up says tank busters out loud, so you can keep your eyes on the fight.
When a tank buster is coming, it speaks the ability name, then counts down:

> "Blade Combo, tank buster in 5" … "3" … "2" … "1"

It doesn't add anything to the screen. Everything it does is spoken.

## How it works

Heads Up doesn't track boss abilities itself. It listens to
[BigWigs](https://www.curseforge.com/wow/addons/big-wigs) and
[LittleWigs](https://www.curseforge.com/wow/addons/littlewigs), which already
know which ability each timer belongs to. LittleWigs also marks which abilities
hit the tank. Heads Up picks out those timers and reads them aloud with your
game's text-to-speech voice.

It works for any dungeon or raid boss that BigWigs and LittleWigs cover.

## Install

1. Install BigWigs and LittleWigs.
2. Copy the `Heads Up` folder into `World of Warcraft/_retail_/Interface/AddOns/`.
3. In game, type `/hu test` to hear a sample callout.

## Before you fight

- **Keep BigWigs bars turned on for the tank busters you want.** BigWigs only
  tells Heads Up about a timer when that timer's bar is enabled. If you hide a
  bar, you won't hear its callout either.
- **LittleWigs is required for dungeon bosses.** Heads Up tells you at login if
  it's missing.
- **Abilities BigWigs doesn't know about won't be announced.** This happens with
  brand-new encounters, or abilities LittleWigs hasn't flagged yet.
- **If your saved voice isn't installed on this computer,** Heads Up uses the
  default voice and tells you once.

## Extra tank busters

LittleWigs flags most tank busters. If one is missing, add its spell ID with
`/hu add <spellID>`, or use the options window. This only works for abilities
BigWigs already shows a bar for.

## Commands

- `/hu` opens the options window. You can also open it from Options > AddOns > Heads Up.
- `/hu test` plays a full callout and countdown.
- `/hu lead <seconds>` sets when the first callout plays (default 5).
- `/hu count <n>` sets where the countdown starts, from 0 to 10 (default 3; 0 turns it off).
- `/hu add <spellID>` and `/hu remove <spellID>` manage your extra tank busters.
- `/hu toggle` turns Heads Up on or off.

## Options window

Type `/hu` to open it. On the left you'll find the on/off switch, tank-only mode,
the first callout time, the countdown start, the wording, the voice, speed and
volume. On the right are your extra spell IDs, a "You'll hear" preview, and a
Test button. Press Esc to close it.

## Settings

- **Only when I'm a tank:** on by default. Heads Up stays quiet in other roles.
- **First callout:** 5 seconds before the hit by default.
- **Count down from:** 3 by default. Set it between 0 (no countdown) and 10.
- **Wording:** "<ability>, tank buster in 5", "<ability> in 5", or "Tank buster in 5".
- **Speech speed and volume:** adjust to taste.

If the countdown starts at or above the first callout, the callout drops its
number and plays 1.5 seconds earlier. You'll hear something like
"<ability>, tank buster", then "5, 4, 3, 2, 1".

## Running the tests

See [tests/README.md](tests/README.md). With lupa installed, run:

```
python tests/run_tests.py
```

Every push and pull request runs the same tests on GitHub. Pushing a `v*` tag
runs them first, then packages and publishes the addon.
