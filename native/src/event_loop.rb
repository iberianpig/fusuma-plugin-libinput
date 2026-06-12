# The dispatch loop: poll the libinput fd, drain queued events, emit a
# JSON line per gesture/device event, flush, repeat.
#
# Ordering is dispatch-then-wait: libinput queues DEVICE_ADDED events
# for every seat device at startup, so we drain once before the first
# poll. As each device appears we apply the configured tap/dwt/mute
# policy (ported from the ffi branch's apply_device_config).

require_relative "ffi"
require_relative "constants"
require_relative "options"
require_relative "gesture_event"
require_relative "device_event"

class EventLoop
  #: (untyped, Options) -> void
  def initialize(li, opts)
    @li = li
    @opts = opts
  end

  #: () -> void
  def run
    fd = LIBINPUT.libinput_get_fd(@li)

    loop do
      LIBINPUT.libinput_dispatch(@li)

      loop do
        ev = LIBINPUT.libinput_get_event(@li)
        break if ev == nil

        handle(ev)
        LIBINPUT.libinput_event_destroy(ev)
      end

      SHIM.shim_flush

      rc = SHIM.shim_wait_fd(fd, -1)
      break if rc < 0
    end
  end

  private

  #: (untyped) -> void
  def handle(ev)
    type = LIBINPUT.libinput_event_get_type(ev)

    if GestureEvent.gesture?(type)
      puts GestureEvent.new(ev, type).to_line
    elsif DeviceEvent.device?(type)
      de = DeviceEvent.new(ev, type)
      puts de.to_line
      apply_config(de) if de.added?
    end
  end

  # Apply per-device policy when a device appears: optional mute of
  # gesture devices whose name doesn't match --keep-device, then
  # tap / dwt config. Mirrors the ffi branch's apply_device_config.
  #: (DeviceEvent) -> void
  def apply_config(de)
    dev = de.device_ptr

    mute_if_unmatched(de, dev)

    if @opts.enable_tap?
      LIBINPUT.libinput_device_config_tap_set_enabled(dev, 1)
    end

    if @opts.enable_dwt?
      LIBINPUT.libinput_device_config_dwt_set_enabled(dev, 1)
    elsif @opts.disable_dwt?
      LIBINPUT.libinput_device_config_dwt_set_enabled(dev, 0)
    end
  end

  # When --keep-device is set, mute gesture-capable devices whose name
  # does not contain the pattern (substring match). Non-gesture devices
  # (keyboards etc.) are left enabled so disable-while-typing keeps
  # working.
  #: (DeviceEvent, untyped) -> void
  def mute_if_unmatched(de, dev)
    pattern = @opts.keep_device
    return if pattern == ""
    return unless de.gesture_capable?
    return if de.name.include?(pattern)

    LIBINPUT.libinput_device_config_send_events_set_mode(
      dev, Const::SEND_EVENTS_DISABLED
    )
    $stderr.puts "muted unmatched device: " + de.name
  end
end
