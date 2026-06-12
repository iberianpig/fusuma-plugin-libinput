# frozen_string_literal: true

# Unit tests for the hand-written JSON serializer.
#
# json_writer.rb is pure Ruby (no FFI), so it runs unmodified under
# CRuby — letting us test the escaping and float-formatting rules
# without building the spinel binary.
#
#   ruby test/native/test_json_writer.rb

require "minitest/autorun"
require_relative "../../native/src/json_writer"

class TestJsonWriter < Minitest::Test
  def test_escape_plain
    assert_equal "hello", JsonWriter.escape("hello")
  end

  def test_escape_double_quote
    assert_equal "a\\\"b", JsonWriter.escape("a\"b")
  end

  def test_escape_backslash
    assert_equal "a\\\\b", JsonWriter.escape("a\\b")
  end

  def test_escape_control_chars
    assert_equal "a\\nb\\tc\\rd", JsonWriter.escape("a\nb\tc\rd")
  end

  def test_quote_wraps_and_escapes
    assert_equal "\"Magic \\\"Pad\\\"\"", JsonWriter.quote("Magic \"Pad\"")
  end

  def test_f4_basic
    assert_equal "1.2568", JsonWriter.f4(1.25678)
  end

  def test_f4_one_point_zero
    assert_equal "1.0000", JsonWriter.f4(1.0)
  end

  def test_f4_negative
    assert_equal "-0.5000", JsonWriter.f4(-0.5)
  end

  def test_f4_zero
    assert_equal "0.0000", JsonWriter.f4(0.0)
  end

  # Every produced string must round-trip through a real JSON parser.
  def test_quote_is_valid_json
    require "json"
    ["plain", "with \"quotes\"", "back\\slash", "tab\tnl\n", "Müller 日本語"].each do |s|
      assert_equal s, JSON.parse(JsonWriter.quote(s))
    end
  end
end
