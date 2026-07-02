# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "tempfile"

module Fusuma
  module Plugin
    module Inputs
      RSpec.describe LibinputEventsInput do
        let(:input) { described_class.new }

        # Load the given yaml as user config (on top of the gem's
        # plugin_defaults) for the duration of the block.
        def with_config(yaml)
          previous_path = Fusuma::Config.instance.custom_path
          file = Tempfile.new(["fusuma-libinput", ".yml"])
          file.write(yaml)
          file.close
          Fusuma::Config.custom_path = file.path
          yield
        ensure
          Fusuma::Config.custom_path = previous_path
          file&.unlink
        end

        # Stub config_params to return values from the given hash, nil
        # otherwise (mirroring fusuma's config lookup).
        def stub_config(values)
          allow(input).to receive(:config_params) { |key| values[key] }
        end

        # A fake binary that prints a couple of JSON lines and exits.
        def fake_executable(*lines)
          dir = Dir.mktmpdir("fusuma-libinput-spec")
          path = File.join(dir, "fusuma-libinput-events")
          body = lines.map { |l| "printf '%s\\n' '#{l}'" }.join("\n")
          File.write(path, "#!/bin/sh\n#{body}\nsleep 1\n")
          File.chmod(0o755, path)
          path
        end

        # Class-level: fusuma checks enabled? before instantiation, so a
        # disabled input's #initialize (and any side effects) never runs.
        describe ".enabled?" do
          it "is enabled by default (zero-config)" do
            with_config("plugin:\n  inputs:\n    libinput_events_input:\n      executable: x\n") do
              expect(described_class.enabled?).to be true
            end
          end

          it "is disabled when enabled: false" do
            with_config("plugin:\n  inputs:\n    libinput_events_input:\n      enabled: false\n") do
              expect(described_class.enabled?).to be false
            end
          end

          it "is enabled when enabled: true" do
            with_config("plugin:\n  inputs:\n    libinput_events_input:\n      enabled: true\n") do
              expect(described_class.enabled?).to be true
            end
          end
        end

        describe "#io" do
          context "when the executable exists" do
            let(:exe) { fake_executable('{"v":1,"type":"hello","app":"x","version":"0.1.0"}') }

            before { stub_config(enabled: true, executable: exe) }

            it "returns a readable IO streaming the binary's output" do
              expect(input.io).to be_a IO
              expect(input.io.readline(chomp: true))
                .to eq '{"v":1,"type":"hello","app":"x","version":"0.1.0"}'
            end
          end

          context "when the executable is missing" do
            before do
              stub_config(enabled: true, executable: "/nonexistent/fusuma-libinput-events")
              allow(Fusuma::MultiLogger).to receive(:warn)
            end

            it "returns a dormant IO and warns" do
              expect(input.io).to be_a IO
              expect(Fusuma::MultiLogger).to have_received(:warn).with(/not found/)
            end

            it "does not become ready for reading" do
              expect(IO.select([input.io], nil, nil, 0.1)).to be_nil
            end
          end
        end

        describe "command arguments" do
          it "builds CLI flags from config" do
            stub_config(
              enabled: true,
              seat: "seat1",
              "keep-device": "Magic",
              "enable-tap": true,
              "disable-dwt": true
            )
            args = input.send(:command_args)
            expect(args).to eq(
              ["--seat", "seat1", "--keep-device", "Magic", "--enable-tap", "--disable-dwt"]
            )
          end

          it "is empty with no relevant config" do
            stub_config(enabled: true)
            expect(input.send(:command_args)).to eq([])
          end
        end

        describe "#config_param_types" do
          it "declares enabled and the CLI options" do
            expect(input.config_param_types.keys)
              .to include(:enabled, :executable, :seat, :"keep-device", :"enable-tap")
          end
        end

        describe "gem default config injection" do
          def gesture_buffer_source
            index = Fusuma::Config::Index.new([:plugin, :buffers, :gesture_buffer])
            Fusuma::Config.instance.fetch_config_params(:source, index)[:source]
          end

          it "defaults gesture_buffer.source to libinput_jsonl_parser" do
            with_config("plugin:\n  inputs: {}\n") do
              expect(gesture_buffer_source).to eq "libinput_jsonl_parser"
            end
          end

          it "lets user config override gesture_buffer.source (opt-out)" do
            yaml = "plugin:\n  buffers:\n    gesture_buffer:\n      source: libinput_gesture_parser\n"
            with_config(yaml) do
              expect(gesture_buffer_source).to eq "libinput_gesture_parser"
            end
          end

          it "disables this input under the full opt-out config" do
            yaml = <<~CONFIG
              plugin:
                inputs:
                  libinput_command_input:
                    enabled: true
                  libinput_events_input:
                    enabled: false
                buffers:
                  gesture_buffer:
                    source: libinput_gesture_parser
            CONFIG
            with_config(yaml) do
              expect(described_class.enabled?).to be false
              expect(gesture_buffer_source).to eq "libinput_gesture_parser"
            end
          end
        end
      end
    end
  end
end
