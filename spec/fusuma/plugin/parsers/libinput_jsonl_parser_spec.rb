# frozen_string_literal: true

require "spec_helper"

module Fusuma
  module Plugin
    module Parsers
      RSpec.describe LibinputJsonlParser do
        let(:parser) { described_class.new }

        def parse(line)
          parser.parse_record(Events::Records::TextRecord.new(line))
        end

        describe "#parse_record" do
          context "with a swipe update line" do
            let(:line) do
              '{"v":1,"type":"gesture","gesture":"swipe","status":"update",' \
                '"finger":3,"dx":1.25,"dy":-0.5,"dx_unaccel":3.12,' \
                '"dy_unaccel":-1.25,"scale":1.0,"rotate":0.0,"time":123}'
            end

            subject(:record) { parse(line) }

            it { is_expected.to be_a Events::Records::GestureRecord }

            it "maps gesture/status/finger" do
              expect(record.gesture).to eq "swipe"
              expect(record.status).to eq "update"
              expect(record.finger).to eq 3
            end

            it "maps dx/dy/unaccel into the delta" do
              expect(record.delta.move_x).to eq 1.25
              expect(record.delta.move_y).to eq(-0.5)
              expect(record.delta.unaccelerated_x).to eq 3.12
              expect(record.delta.unaccelerated_y).to eq(-1.25)
            end
          end

          context "with a pinch update line" do
            let(:line) do
              '{"v":1,"type":"gesture","gesture":"pinch","status":"update",' \
                '"finger":2,"dx":0.0,"dy":0.0,"dx_unaccel":0.0,"dy_unaccel":0.0,' \
                '"scale":1.5,"rotate":12.3,"time":1}'
            end

            subject(:record) { parse(line) }

            it "maps scale into zoom and rotate" do
              expect(record.gesture).to eq "pinch"
              expect(record.delta.zoom).to eq 1.5
              expect(record.delta.rotate).to eq 12.3
            end
          end

          context "with a cancelled hold-end line" do
            let(:line) do
              '{"v":1,"type":"gesture","gesture":"hold","status":"cancelled",' \
                '"finger":3,"dx":0.0,"dy":0.0,"dx_unaccel":0.0,"dy_unaccel":0.0,' \
                '"scale":1.0,"rotate":0.0,"time":1}'
            end

            it "passes the cancelled status through" do
              expect(parse(line).status).to eq "cancelled"
            end
          end

          context "with non-gesture lines" do
            it "ignores hello" do
              expect(parse('{"v":1,"type":"hello","app":"x","version":"0.1.0"}')).to be_nil
            end

            it "ignores device" do
              expect(parse('{"v":1,"type":"device","status":"added","name":"x","sysname":"event2","capabilities":["gesture"]}')).to be_nil
            end

            it "ignores fatal" do
              expect(parse('{"v":1,"type":"fatal","message":"boom"}')).to be_nil
            end
          end

          context "with malformed input" do
            it "returns nil for invalid JSON" do
              expect(parse("not json at all")).to be_nil
            end

            it "returns nil for an empty line" do
              expect(parse("")).to be_nil
            end
          end
        end

        describe "DEFAULT_SOURCE" do
          it "matches the input plugin tag" do
            expect(described_class::DEFAULT_SOURCE).to eq "libinput_events_input"
          end
        end
      end
    end
  end
end
