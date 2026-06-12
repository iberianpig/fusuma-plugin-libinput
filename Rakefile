# frozen_string_literal: true

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# FFI-independent native parts (json_writer etc.) under CRuby + minitest.
require "rake/testtask"
Rake::TestTask.new(:native_test) do |t|
  t.test_files = FileList["test/native/**/*.rb"]
  t.warning = false
end

task default: %i[spec native_test]
