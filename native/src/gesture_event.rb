# Turns a raw libinput gesture event into a JSON Lines record.
#
# Normalization rules are ported verbatim from the fusuma `ffi` branch
# (git show ffi:lib/fusuma/libinput/gesture_event.rb):
#   - dx/dy/unaccel are only meaningful on *_UPDATE
#   - scale/angle_delta are only valid for PINCH (reading them on
#     swipe/hold is a libinput client bug)
#   - a cancelled HOLD_END is reported as status "cancelled"

require_relative "ffi"
require_relative "constants"
require_relative "json_writer"

class GestureEvent
  #: (Integer) -> bool
  def self.gesture?(event_type)
    event_type >= Const::GESTURE_SWIPE_BEGIN &&
      event_type <= Const::GESTURE_HOLD_END
  end

  #: (untyped, Integer) -> void
  def initialize(event_ptr, event_type)
    pair = gesture_status(event_type)
    @gesture = pair[0]
    @status = pair[1]

    gp = LIBINPUT.libinput_event_get_gesture_event(event_ptr)
    @finger = LIBINPUT.libinput_event_gesture_get_finger_count(gp)
    @time = LIBINPUT.libinput_event_gesture_get_time(gp)

    if @status == "update"
      @dx = LIBINPUT.libinput_event_gesture_get_dx(gp)
      @dy = LIBINPUT.libinput_event_gesture_get_dy(gp)
      @dx_unaccel = LIBINPUT.libinput_event_gesture_get_dx_unaccelerated(gp)
      @dy_unaccel = LIBINPUT.libinput_event_gesture_get_dy_unaccelerated(gp)
    else
      @dx = 0.0
      @dy = 0.0
      @dx_unaccel = 0.0
      @dy_unaccel = 0.0
    end

    # scale/rotate only valid for pinch
    if @gesture == "pinch"
      if @status == "begin"
        @scale = 1.0
      else
        @scale = LIBINPUT.libinput_event_gesture_get_scale(gp)
      end
      if @status == "update"
        @rotate = LIBINPUT.libinput_event_gesture_get_angle_delta(gp)
      else
        @rotate = 0.0
      end
    else
      @scale = 1.0
      @rotate = 0.0
    end

    @cancelled = false
    if @gesture == "hold" && @status == "end"
      @cancelled = LIBINPUT.libinput_event_gesture_get_cancelled(gp) != 0
    end
  end

  #: () -> String
  def to_line
    status = @status
    if @gesture == "hold" && @status == "end" && @cancelled
      status = "cancelled"
    end

    out = "{\"v\":1,\"type\":\"gesture\""
    out += ",\"gesture\":" + JsonWriter.quote(@gesture)
    out += ",\"status\":" + JsonWriter.quote(status)
    out += ",\"finger\":" + @finger.to_s
    out += ",\"dx\":" + JsonWriter.f4(@dx)
    out += ",\"dy\":" + JsonWriter.f4(@dy)
    out += ",\"dx_unaccel\":" + JsonWriter.f4(@dx_unaccel)
    out += ",\"dy_unaccel\":" + JsonWriter.f4(@dy_unaccel)
    out += ",\"scale\":" + JsonWriter.f4(@scale)
    out += ",\"rotate\":" + JsonWriter.f4(@rotate)
    out += ",\"time\":" + @time.to_s
    out + "}"
  end

  private

  # Map an event-type integer to [gesture, status].
  #: (Integer) -> Array[String]
  def gesture_status(t)
    case t
    when Const::GESTURE_SWIPE_BEGIN then ["swipe", "begin"]
    when Const::GESTURE_SWIPE_UPDATE then ["swipe", "update"]
    when Const::GESTURE_SWIPE_END then ["swipe", "end"]
    when Const::GESTURE_PINCH_BEGIN then ["pinch", "begin"]
    when Const::GESTURE_PINCH_UPDATE then ["pinch", "update"]
    when Const::GESTURE_PINCH_END then ["pinch", "end"]
    when Const::GESTURE_HOLD_BEGIN then ["hold", "begin"]
    when Const::GESTURE_HOLD_END then ["hold", "end"]
    else ["unknown", "unknown"]
    end
  end
end
