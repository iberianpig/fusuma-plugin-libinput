# frozen_string_literal: true

require "json"
require "fusuma/plugin/parsers/parser"
require "fusuma/plugin/events/records/gesture_record"

module Fusuma
  module Plugin
    module Parsers
      # Parses the JSON Lines emitted by the fusuma-libinput-events binary
      # into GestureRecords. Non-gesture lines (hello / device / fatal)
      # and malformed lines are ignored (return nil), so they pass through
      # the pipeline harmlessly.
      class LibinputJsonlParser < Parser
        DEFAULT_SOURCE = "libinput_events_input"

        # @param record [Events::Records::TextRecord]
        # @return [Events::Records::GestureRecord, nil]
        def parse_record(record)
          data = parse_json(record.to_s)
          return nil if data.nil?
          return nil unless data["type"] == "gesture"

          delta = Events::Records::GestureRecord::Delta.new(
            data["dx"], data["dy"],
            data["dx_unaccel"], data["dy_unaccel"],
            data["scale"], data["rotate"]
          )

          Events::Records::GestureRecord.new(
            status: data["status"],
            gesture: data["gesture"],
            finger: data["finger"],
            delta: delta
          )
        end

        private

        # @return [Hash, nil]
        def parse_json(line)
          JSON.parse(line)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
