# frozen_string_literal: true

require "fusuma/plugin/inputs/input"

module Fusuma
  module Plugin
    module Inputs
      # Streams gesture events from the standalone fusuma-libinput-events
      # binary (a spinel-compiled libinput reader) as JSON Lines, spawned
      # as a subprocess and read line-by-line.
      #
      # Opt-in: fusuma instantiates every installed input plugin and calls
      # #io on each, so this plugin stays dormant unless the user sets
      #
      #   plugin:
      #     inputs:
      #       libinput_events_input:
      #         enable: true
      #
      # When dormant (not enabled, or the binary can't be found) it returns
      # a reader that never produces events, leaving fusuma's bundled
      # libinput_command_input to handle gestures.
      class LibinputEventsInput < Input
        DEFAULT_EXECUTABLE = "fusuma-libinput-events"

        #: () -> Hash[Symbol, Array[Class]]
        def config_param_types
          {
            enable: [TrueClass, FalseClass],
            executable: [String],
            seat: [String],
            "keep-device": [String],
            "enable-tap": [TrueClass, FalseClass],
            "enable-dwt": [TrueClass, FalseClass],
            "disable-dwt": [TrueClass, FalseClass]
          }
        end

        # @return [IO]
        def io
          @io ||= if enabled?
            path = resolve_executable
            path ? spawn_reader(path) : dormant("'#{configured_executable}' not found")
          else
            dormant("not enabled")
          end
        end

        # Stop the subprocess on shutdown (PR_SET_PDEATHSIG is a backstop).
        def shutdown
          return unless @pid

          Process.kill("TERM", @pid)
        rescue Errno::ESRCH
          # already gone
        end

        private

        #: () -> bool
        def enabled?
          config_params(:enable) == true
        end

        # @return [IO] the pipe reader for the spawned binary
        def spawn_reader(path)
          reader, writer = IO.pipe
          @pid = Process.spawn(path, *command_args, out: writer, err: :err)
          writer.close
          reader
        end

        # A reader that never becomes ready, so IO.select ignores us and
        # the bundled libinput_command_input keeps working. The writer is
        # retained so the reader never sees EOF (which would shut fusuma
        # down via Input#read_from_io).
        def dormant(reason)
          MultiLogger.warn("#{self.class.name}: #{reason}; falling back to libinput_command_input")
          reader, @dormant_writer = IO.pipe
          reader
        end

        #: () -> String
        def configured_executable
          config_params(:executable) || DEFAULT_EXECUTABLE
        end

        # Resolve the executable to a runnable path, or nil if not found.
        # Accepts an absolute path, a PATH-resolved name, or a relative
        # path that exists.
        #: () -> String?
        def resolve_executable
          exe = configured_executable
          return exe if exe.include?(File::SEPARATOR) && File.executable?(exe)

          ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
            candidate = File.join(dir, exe)
            return candidate if File.executable?(candidate)
          end
          nil
        end

        #: () -> Array[String]
        def command_args
          args = []
          seat = config_params(:seat)
          args.push("--seat", seat) if seat
          keep = config_params(:"keep-device")
          args.push("--keep-device", keep) if keep
          args.push("--enable-tap") if config_params(:"enable-tap")
          args.push("--enable-dwt") if config_params(:"enable-dwt")
          args.push("--disable-dwt") if config_params(:"disable-dwt")
          args
        end
      end
    end
  end
end
