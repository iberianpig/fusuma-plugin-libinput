# fusuma-libinput-events — standalone libinput gesture reader.
#
# Creates a udev-backed libinput context via the C shim, then streams
# gesture and device events as JSON Lines on stdout (one JSON object per
# line). Logs and human-readable hints go to stderr.
#
require_relative "ffi"
require_relative "constants"
require_relative "options"
require_relative "json_writer"
require_relative "gesture_event"
require_relative "device_event"
require_relative "event_loop"

opts = Options.new
opts.parse

SHIM.shim_setup

li = SHIM.shim_libinput_create(opts.seat)
if li == nil
  puts "{\"v\":1,\"type\":\"fatal\",\"message\":\"libinput_udev_assign_seat failed: seat0\"}"
  SHIM.shim_flush
  $stderr.puts "fatal: could not create libinput context for seat0"
  $stderr.puts "       is your user in the 'input' group? try: sudo usermod -aG input $USER"
  exit 1
end

puts "{\"v\":1,\"type\":\"hello\",\"app\":\"" + Const::APP_NAME +
  "\",\"version\":\"" + Const::APP_VERSION + "\"}"
SHIM.shim_flush

EventLoop.new(li, opts).run

LIBINPUT.libinput_unref(li)
