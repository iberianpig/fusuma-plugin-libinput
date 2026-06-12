# Command-line options.
#
# spinel's bundled optparse doesn't compile (its ARGV manipulation hits
# unsupported codegen paths), so this is a small hand-rolled parser over
# ARGV — which spinel does support (length / [] / each).
#
# Options:
#   --seat SEAT          udev seat to assign (default: seat0)
#   --keep-device PAT    keep only gesture devices whose name contains
#                        PAT (substring match); mute the rest. Empty =
#                        keep all. NOTE: substring, not regex — spinel
#                        can't compile a runtime pattern into a Regexp.
#   --enable-tap         enable tap-to-click on each device
#   --enable-dwt         enable disable-while-typing
#   --disable-dwt        disable disable-while-typing
#   --version            print version and exit
#   --help, -h           print usage and exit

require_relative "constants"

class Options
  #: () -> void
  def initialize
    @seat = "seat0"
    @keep_device = ""
    @enable_tap = false
    @enable_dwt = false
    @disable_dwt = false
  end

  #: () -> String
  def seat
    @seat
  end

  #: () -> String
  def keep_device
    @keep_device
  end

  #: () -> bool
  def enable_tap?
    @enable_tap
  end

  #: () -> bool
  def enable_dwt?
    @enable_dwt
  end

  #: () -> bool
  def disable_dwt?
    @disable_dwt
  end

  # Parse the global ARGV. Prints and exits for --version / --help.
  #
  # ARGV is referenced directly rather than passed in: spinel can't
  # infer the array type of ARGV across a method-argument boundary, but
  # handles the global fine when used in place.
  #: () -> void
  def parse
    i = 0
    while i < ARGV.length
      arg = ARGV[i]
      if arg == "--seat"
        i += 1
        @seat = ARGV[i]
      elsif arg == "--keep-device"
        i += 1
        @keep_device = ARGV[i]
      elsif arg == "--enable-tap"
        @enable_tap = true
      elsif arg == "--enable-dwt"
        @enable_dwt = true
      elsif arg == "--disable-dwt"
        @disable_dwt = true
      elsif arg == "--version"
        puts Const::APP_VERSION
        exit 0
      elsif arg == "--help" || arg == "-h"
        print_usage
        exit 0
      else
        $stderr.puts "unknown option: " + arg
      end
      i += 1
    end
  end

  private

  #: () -> void
  def print_usage
    $stderr.puts "usage: " + Const::APP_NAME + " [options]"
    $stderr.puts "  --seat SEAT          udev seat (default: seat0)"
    $stderr.puts "  --keep-device PAT    keep only gesture devices whose name contains PAT"
    $stderr.puts "  --enable-tap         enable tap-to-click"
    $stderr.puts "  --enable-dwt         enable disable-while-typing"
    $stderr.puts "  --disable-dwt        disable disable-while-typing"
    $stderr.puts "  --version            print version and exit"
    $stderr.puts "  --help, -h           show this help"
  end
end
