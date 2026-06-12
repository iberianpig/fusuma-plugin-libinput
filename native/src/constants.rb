# libinput event-type and capability constants.
#
# Transcribed from the fusuma `ffi` branch
# (git show ffi:lib/fusuma/libinput/constants.rb). Only the subset the
# reader needs. Used in case/when dispatch; spinel inlines module
# constants at their use sites.

module Const
  # Binary identity (advertised in the "hello" line)
  APP_NAME = "fusuma-libinput-events"
  APP_VERSION = "0.1.0"

  # Device events
  DEVICE_ADDED = 1
  DEVICE_REMOVED = 2

  # Gesture events
  GESTURE_SWIPE_BEGIN = 800
  GESTURE_SWIPE_UPDATE = 801
  GESTURE_SWIPE_END = 802
  GESTURE_PINCH_BEGIN = 803
  GESTURE_PINCH_UPDATE = 804
  GESTURE_PINCH_END = 805
  GESTURE_HOLD_BEGIN = 806
  GESTURE_HOLD_END = 807

  # Device capabilities (libinput_device_capability)
  CAP_KEYBOARD = 0
  CAP_POINTER = 1
  CAP_TOUCH = 2
  CAP_GESTURE = 5

  # libinput_config_send_events_mode
  SEND_EVENTS_ENABLED = 0
  SEND_EVENTS_DISABLED = 1
end
