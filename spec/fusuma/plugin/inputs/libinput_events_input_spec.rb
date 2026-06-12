# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

module Fusuma
  module Plugin
    module Inputs
      RSpec.describe LibinputEventsInput do
        let(:input) { described_class.new }

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

        describe "#enabled?" do
          it "is disabled by default (opt-in)" do
            stub_config({})
            expect(input.enabled?).to be false
          end

          it "is disabled when enabled: false" do
            stub_config(enabled: false)
            expect(input.enabled?).to be false
          end

          it "is enabled when enabled: true" do
            stub_config(enabled: true)
            expect(input.enabled?).to be true
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
      end
    end
  end
end
