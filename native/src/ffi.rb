# FFI declarations for the spinel-compiled libinput reader.
#
# Three namespaces:
#   LibC    — libc helpers (stdout flush)
#   SHIM    — functions defined in shim/shim.c (linked in by the Makefile)
#   LIBINPUT — direct bindings to libinput's C API
#
# Signatures and types are transcribed from the fusuma `ffi` branch
# (git show ffi:lib/fusuma/libinput/functions.rb). libinput accessors
# that return `double` map to spinel `:double`; opaque handles map to
# `:ptr` (void *, not GC-tracked — see spinel docs/FFI.md).

module SHIM
  # Defined in shim/shim.c. No ffi_lib needed: the Makefile links the
  # compiled shim object directly.
  ffi_func :shim_setup, [], :void
  ffi_func :shim_libinput_create, [:str], :ptr
  ffi_func :shim_wait_fd, [:int, :int], :int
  ffi_func :shim_flush, [], :void
end

module LIBINPUT
  ffi_lib "input"

  # Context / event-loop core
  ffi_func :libinput_get_fd, [:ptr], :int
  ffi_func :libinput_dispatch, [:ptr], :int
  ffi_func :libinput_get_event, [:ptr], :ptr
  ffi_func :libinput_unref, [:ptr], :ptr

  # Event
  ffi_func :libinput_event_get_type, [:ptr], :int
  ffi_func :libinput_event_destroy, [:ptr], :void
  ffi_func :libinput_event_get_gesture_event, [:ptr], :ptr
  ffi_func :libinput_event_get_device, [:ptr], :ptr

  # Gesture accessors
  ffi_func :libinput_event_gesture_get_finger_count, [:ptr], :int
  ffi_func :libinput_event_gesture_get_dx, [:ptr], :double
  ffi_func :libinput_event_gesture_get_dy, [:ptr], :double
  ffi_func :libinput_event_gesture_get_dx_unaccelerated, [:ptr], :double
  ffi_func :libinput_event_gesture_get_dy_unaccelerated, [:ptr], :double
  ffi_func :libinput_event_gesture_get_scale, [:ptr], :double
  ffi_func :libinput_event_gesture_get_angle_delta, [:ptr], :double
  ffi_func :libinput_event_gesture_get_cancelled, [:ptr], :int

  # Device
  ffi_func :libinput_device_get_name, [:ptr], :str
  ffi_func :libinput_device_get_sysname, [:ptr], :str
  ffi_func :libinput_device_has_capability, [:ptr, :int], :int
  ffi_func :libinput_device_config_send_events_set_mode, [:ptr, :int], :int
  ffi_func :libinput_device_config_tap_set_enabled, [:ptr, :int], :int
  ffi_func :libinput_device_config_dwt_set_enabled, [:ptr, :int], :int
end
