# The dispatch loop: poll the libinput fd, drain queued events, emit a
# JSON line per gesture/device event, flush, repeat.
#
# Ordering is dispatch-then-wait: libinput queues DEVICE_ADDED events
# for every seat device at startup, so we drain once before the first
# poll.

require_relative "ffi"
require_relative "constants"
require_relative "gesture_event"
require_relative "device_event"

class EventLoop
  #: (untyped) -> void
  def initialize(li)
    @li = li
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
      puts DeviceEvent.new(ev, type).to_line
    end
  end
end
