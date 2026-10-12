# Heads Up

Voice-only tank-buster warnings. No frames, no bars, nothing on screen.

> "Blade Combo, tank buster in 5" … "3" … "2" … "1"

## How it works

Heads Up sits on top of **BigWigs + LittleWigs**. BigWigs already works out
which boss ability every timer is (including from Blizzard's boss timeline,
whose spell data is hidden from addons in Midnight). LittleWigs tags abilities
as `TANK` / `TANK_HEALER` in each boss module. Heads Up listens to BigWigs'
timer messages, keeps the tank ones, and speaks them with the game's
text-to-speech.

That means any dungeon or raid boss LittleWigs/BigWigs covers works, not just
King's Rest. Your BigWigs bars must stay enabled (the default), since Heads Up
listens to them.

## Install

1. Install BigWigs and LittleWigs.
2. Copy the `Heads Up` folder to `World of Warcraft/_retail_/Interface/AddOns/`.
3. In game, `/hu test` to hear a full callout.

## King's Rest (Midnight Season 2)

| Boss | Ability | Source |
|---|---|---|
| The Golden Serpent | Tail Thrash | LittleWigs TANK_HEALER flag |
| Mchimba the Embalmer | — | no tank buster |
| The Council of Tribes | Debilitating Backhand | LittleWigs TANK flag |
| Dazar, The First King | Blade Combo | LittleWigs TANK_HEALER flag |
| Dazar, The First King | Savage Maul | Heads Up extra list (not flagged by LittleWigs) |

## Commands

- `/hu` opens the options window (also reachable from Options > AddOns > Heads Up)
- `/hu test` plays a full callout and countdown
- `/hu lead <secs>` sets when the first callout plays (default 5)
- `/hu count <n>` sets the countdown start, 0–10 (default 3, 0 = off)
- `/hu add <spellID>` / `/hu remove <spellID>` adds or removes extra tank busters
- `/hu toggle` turns it on or off

## Options window

Type `/hu`. Left side: on/off, tank-only, first callout, countdown start, wording,
voice, speed and volume. Right side: extra tank-buster spell IDs, a live
"You'll hear" preview, and a Test button. Esc closes it.

## Settings

Only when I'm a tank (on), first callout seconds (5), count down from (3,
0 = off, up to 10), wording (name + "tank buster" / name only / "tank buster" only),
speech speed and volume.

If the countdown starts at or above the first callout, the callout drops its
number and plays 1.5s earlier: "Blade Combo, tank buster… 5, 4, 3, 2, 1". The voice is your Blizzard text-to-speech voice.
