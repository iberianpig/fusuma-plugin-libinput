# frozen_string_literal: true

require "fusuma"
require "fusuma/plugin/parsers/libinput_jsonl_parser"
require "fusuma/plugin/inputs/libinput_events_input"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
