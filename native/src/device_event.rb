# Turns a DEVICE_ADDED / DEVICE_REMOVED event into a JSON Lines record,
# and applies per-device config (tap / dwt / mute) as devices appear.
#
# The capabilities array is assembled inline as a string rather than via
# a Ruby Array, to stay clear of spinel's empty-array type inference.

require_relative "ffi"
require_relative "constants"
require_relative "json_writer"

class DeviceEvent
  #: (Integer) -> bool
  def self.device?(event_type)
    event_type == Const::DEVICE_ADDED ||
      event_type == Const::DEVICE_REMOVED
  end

  #: (untyped, Integer) -> void
  def initialize(event_ptr, event_type)
    @added = (event_type == Const::DEVICE_ADDED)
    @device = LIBINPUT.libinput_event_get_device(event_ptr)
    # :str returns are non-copy; build the line immediately (see ffi.rb)
    @name = LIBINPUT.libinput_device_get_name(@device)
    @sysname = LIBINPUT.libinput_device_get_sysname(@device)
  end

  # Raw device pointer, for callers that apply config on DEVICE_ADDED.
  #: () -> untyped
  def device_ptr
    @device
  end

  #: () -> bool
  def added?
    @added
  end

  #: () -> String
  def to_line
    status = @added ? "added" : "removed"
    out = "{\"v\":1,\"type\":\"device\""
    out += ",\"status\":" + JsonWriter.quote(status)
    out += ",\"name\":" + JsonWriter.quote(@name)
    out += ",\"sysname\":" + JsonWriter.quote(@sysname)
    out += ",\"capabilities\":" + capabilities_json
    out + "}"
  end

  private

  #: () -> String
  def capabilities_json
    out = "["
    n = 0
    if has_cap(Const::CAP_GESTURE)
      out += "\"gesture\""
      n += 1
    end
    if has_cap(Const::CAP_POINTER)
      out += "," if n > 0
      out += "\"pointer\""
      n += 1
    end
    if has_cap(Const::CAP_KEYBOARD)
      out += "," if n > 0
      out += "\"keyboard\""
      n += 1
    end
    if has_cap(Const::CAP_TOUCH)
      out += "," if n > 0
      out += "\"touch\""
      n += 1
    end
    out + "]"
  end

  #: (Integer) -> bool
  def has_cap(code)
    LIBINPUT.libinput_device_has_capability(@device, code) != 0
  end
end
