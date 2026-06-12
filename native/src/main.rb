# Phase 0 PoC entry point.
#
# Minimal proof that spinel can drive libinput end to end: create a udev
# context via the C shim, poll its fd, dispatch, and print the integer
# event type of every event. A 3-finger swipe on a touchpad should emit
# 800 (SWIPE_BEGIN), a run of 801 (SWIPE_UPDATE), then 802 (SWIPE_END).
#
# stdout = data (event type ints, later JSON), stderr = logs.

require_relative "ffi"

SHIM.shim_setup

li = SHIM.shim_libinput_create("seat0")
if li == nil
  $stderr.puts "fatal: could not create libinput context for seat0"
  $stderr.puts "       (is your user in the 'input' group? try: sudo usermod -aG input $USER)"
  exit 1
end

fd = LIBINPUT.libinput_get_fd(li)
$stderr.puts "libinput ready (fd=#{fd}); swipe/pinch/hold on the touchpad..."

# dispatch-then-wait: libinput queues DEVICE_ADDED events for every
# device on the seat at assign_seat time, so we dispatch/drain once up
# front (before the first poll) and again after each readable fd.
loop do
  LIBINPUT.libinput_dispatch(li)

  loop do
    ev = LIBINPUT.libinput_get_event(li)
    break if ev == nil

    type = LIBINPUT.libinput_event_get_type(ev)
    puts type

    LIBINPUT.libinput_event_destroy(ev)
  end

  SHIM.shim_flush

  rc = SHIM.shim_wait_fd(fd, -1)
  break if rc < 0
end

LIBINPUT.libinput_unref(li)
