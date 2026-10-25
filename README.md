# Peekaboo

Hold a hotkey and a small popup shows live readouts: the weather where you are, and the
battery level of your Mac and the devices around it. Let go and it disappears. It's a menu bar app with no Dock icon and
takes no focus, so the app you were typing in stays active.

(Peekaboo was called Battery Peek. The installer migrates an old install and your config.)

It shows:

- **Weather**, on the left: temperature, conditions, feels-like, wind, humidity, and cloud
  cover.
- **This Mac**, with charging state and time remaining.
- **Bluetooth devices**: AirPods (buds and case), Magic Keyboard, mouse, trackpad.
- **Logitech devices on a Bolt or Unifying receiver**, read live over HID++, so
  the levels match Logi Options+ (the mouse and keyboard you can't see over
  Bluetooth).

## Install

Needs macOS 13 or later and the Swift command-line tools (`xcode-select --install`).

```bash
git clone https://github.com/sougou/peekaboo.git ~/code/peekaboo
cd ~/code/peekaboo
scripts/install.sh
```

This builds the app, copies it to `~/Applications/Peekaboo.app`, and starts it at
login. Then hold **⌃⌥B** (Control + Option + B).

If you had Battery Peek installed, the script stops and removes it, and copies your
`~/.config/battery-peek/config.json` to `~/.config/peekaboo/config.json` so your hotkey
carries over.

Remove it with `scripts/uninstall.sh`. A battery icon in the menu bar offers
"Show for 3 seconds" and "Quit".

### Settings

Create `~/.config/peekaboo/config.json`. Every key is optional:

```json
{
  "hotkey": "f16",
  "units": "F",
  "location": { "name": "San Jose", "latitude": 37.33, "longitude": -121.89 }
}
```

- `hotkey`: see below. The default is `ctrl+opt+b`.
- `units`: `"F"` or `"C"`. The default is Fahrenheit in the US and Celsius elsewhere.
- `location`: pins the weather to a place. Without it, Peekaboo uses an approximate
  location from your IP address (see Privacy).

Hotkey modifiers: `cmd`, `ctrl`, `opt` (or `alt`), `shift`. Keys: letters, digits, `space`,
`f1`-`f20`. Function keys can be used alone, such as `"f16"`; letters, digits, and `space`
need at least one modifier, or the hotkey would swallow your typing.
Restart the app after changing it (`killall Peekaboo`, then reopen it, or log out and in).

## How it works

- The hotkey uses Carbon's hot key API, which reports key-down and key-up and needs no
  Accessibility or Input Monitoring permission.
- The popup is a borderless, non-activating panel that ignores the mouse.
- **Weather:** [Open-Meteo](https://open-meteo.com)'s free forecast API (no key) for the
  place from your config, or else an approximate location from your IP address. The
  reading is cached for 30 minutes and the IP lookup for 24 hours, in
  `~/Library/Caches/peekaboo/weather.json`, so opening the popup never waits on the
  network. If a request fails, the weather panel just doesn't show.
- **Mac:** the power-source API (IOKit).
- **Bluetooth:** `system_profiler` for connected devices and AirPods' left, right, and
  case levels, plus `BatteryPercent` from the IORegistry for keyboards, mice, and
  trackpads. Slow, so it's cached and refreshed every minute in the background.
- **Logitech:** the receiver's vendor HID interface (usage page `0xFF00`) carries HID++
  messages and never keystrokes, so reading it needs no Input Monitoring permission. The
  app pings each of the six pairing slots, asks for the device name (feature `0x0005`)
  and battery (features `0x1004` or `0x1000`). All queries are read-only. A sleeping
  device can take a couple of seconds to answer, which is another reason this is cached.
  A device that misses a refresh keeps its last reading for 10 minutes, so it doesn't blink
  out of the list. It works alongside Logi Options+.

## Privacy

Peekaboo has no accounts, no analytics, and no server of its own. Battery readings are
local: the power-source API, `system_profiler`, the IORegistry, and read-only HID++
queries to a USB receiver. The only network requests are for weather:

- **Open-Meteo** gets your location rounded to about a kilometre (two decimal places).
- **An IP lookup** (ipwho.is, then ipapi.co, then get.geojs.io if the first fails) gets your
  IP address, as any web request does, to find an approximate location. Pin a `location`
  in the config and this lookup never happens.

## Development

```bash
swift build
swift run core-checks            # unit checks for parsing, HID++ framing, hotkeys
swift run hidpp-probe            # prints what the Logitech receiver reports, step by step
.build/debug/Peekaboo --list     # what the popup would show (weather and batteries)
.build/debug/Peekaboo --snapshot popup.png   # render the popup to a PNG
.build/debug/Peekaboo --show 4               # show the popup for 4 seconds, then quit
```

The command-line Swift tools don't include XCTest or the Swift Testing macros, so
`core-checks` is a plain executable that exits non-zero on failure.

## Limits

- Logitech support covers HID++ 2.0 devices with the unified battery (`0x1004`) or battery
  status (`0x1000`) feature. Older HID++ 1.0 devices, and devices on direct Bluetooth, aren't
  read over HID++ (direct-Bluetooth ones show through the Bluetooth path when macOS reports
  a level).
- The app is signed ad hoc, so macOS may ask you to allow it again after you rebuild.
- Tested on macOS 27 with an MX Master 3S and a Signature Slim Solar+ on a Bolt receiver.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
