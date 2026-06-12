# fusuma-plugin-libinput

A [Fusuma](https://github.com/iberianpig/fusuma) plugin that reads
libinput gestures from a small **standalone binary** instead of the
`libinput debug-events` CLI.

The binary (`fusuma-libinput-events`) talks to libinput directly and
streams gesture events as **JSON Lines** on stdout. It is compiled
ahead-of-time with [spinel](https://github.com/matz/spinel) and depends
only on `libinput` / `libudev` — no `libinput-tools`, and no native Ruby
extension to build on the user's machine.

> **Status: experimental.** The binary is built locally for now (no gem
> distribution of the compiled artifact yet).

## Why

- Removes Fusuma's runtime dependency on the `libinput-tools` CLI.
- Parses a stable, machine-readable protocol (JSON Lines) instead of
  scraping human-oriented CLI text whose format changes between libinput
  versions.

## Requirements

- **libinput ≥ 1.19** and `libudev` (with development headers to build).
  Hold gestures (`get_cancelled`) require ≥ 1.19.
- Membership in the `input` group (read access to `/dev/input/*`):
  ```sh
  sudo usermod -aG input "$USER"   # then re-login
  ```
- To build the binary: a C compiler and a checkout of
  [matz/spinel](https://github.com/matz/spinel), built once
  (`make all` in the spinel repo).

## Building the binary

```sh
cd native
# point at your spinel checkout if it isn't at ~/ghq/github.com/matz/spinel
make SPINEL_DIR=/path/to/spinel
# -> native/build/fusuma-libinput-events
```

Put it somewhere on `PATH` (e.g. `~/.local/bin/`) or reference it by
absolute path in the config below.

Smoke test (no Fusuma needed):

```sh
./native/build/fusuma-libinput-events | head
# {"v":1,"type":"hello",...}
# {"v":1,"type":"device","status":"added",...}
# ...swipe/pinch/hold on the touchpad to see "gesture" lines...
```

## Fusuma configuration

This plugin is **opt-in**. Enabling it takes three changes in
`~/.config/fusuma/config.yml`:

```yaml
plugin:
  inputs:
    # 1. turn off the bundled CLI input so gestures aren't detected twice
    libinput_command_input:
      enabled: false
    # 2. enable this plugin's input (and point at the binary)
    libinput_events_input:
      enabled: true
      executable: fusuma-libinput-events   # name on PATH, or an absolute path
      # keep-device: "Magic Trackpad"      # optional, substring match
      # enable-tap: true
      # disable-dwt: true
  buffers:
    # 3. feed the gesture buffer from this plugin's parser
    gesture_buffer:
      source: libinput_jsonl_parser

# gestures as usual
swipe:
  3:
    left:
      command: 'your-command'
    right:
      command: 'your-command'
```

> `enabled: false` for inputs requires a Fusuma version with per-input
> enable support. Without it, run this plugin only where
> `libinput debug-events` is unavailable (so the bundled input produces
> nothing and there is nothing to duplicate).

### Binary CLI options

The input plugin translates config into these flags; you can also run
the binary directly with them:

| Option | Meaning |
|---|---|
| `--seat SEAT` | udev seat to assign (default `seat0`) |
| `--keep-device PAT` | keep only gesture devices whose name **contains** `PAT` (substring, not regex); mute the rest |
| `--enable-tap` | enable tap-to-click |
| `--enable-dwt` / `--disable-dwt` | toggle disable-while-typing |
| `--version`, `--help` | print and exit |

## JSON Lines protocol (v1)

stdout is data only — one JSON object per line. Logs and errors go to
stderr. Floats are fixed `%.4f`. Unknown keys may be added later, so
consumers ignore what they don't recognize.

```jsonc
{"v":1,"type":"hello","app":"fusuma-libinput-events","version":"0.1.0"}
{"v":1,"type":"device","status":"added","name":"Magic Trackpad","sysname":"event5","capabilities":["gesture","pointer"]}
{"v":1,"type":"gesture","gesture":"swipe","status":"update","finger":3,
 "dx":1.25,"dy":-0.5,"dx_unaccel":3.12,"dy_unaccel":-1.25,
 "scale":1.0,"rotate":0.0,"time":123456789}
{"v":1,"type":"fatal","message":"libinput_udev_assign_seat failed: seat0"}
```

- `gesture`: `swipe` | `pinch` | `hold`; `status`: `begin` | `update` |
  `end` | `cancelled`.
- `cancelled` is normalized by the binary (a `HOLD_END` whose
  `get_cancelled()` is set).
- `dx`/`dy`/`*_unaccel` are non-zero only on `update`; `scale`/`rotate`
  only for `pinch`.

## Development & tests

```sh
bundle install
bundle exec rake          # RSpec (parser + input) and native minitest (json_writer)
```

### Hardware-free gesture testing

`tools/fake_touchpad.c` creates a virtual multitouch touchpad via
`/dev/uinput` and injects a gesture — useful on machines without a
physical touchpad, and for CI-style checks.

```sh
cc -O2 -o tools/fake_touchpad tools/fake_touchpad.c
# run the binary in one shell, inject in another:
./native/build/fusuma-libinput-events &
./tools/fake_touchpad swipe   # or: pinch | hold
```

## Limitations

- `--keep-device` is a **substring** match (the binary can't compile a
  runtime regex), unlike Fusuma's regex `device:` option.
- The compiled binary is built locally; there is no packaged
  distribution yet.

## License

MIT
