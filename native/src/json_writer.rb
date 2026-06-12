# Hand-written JSON serialization helpers (spinel has no JSON library).
#
# Only what the protocol needs: escaped strings, fixed-precision floats,
# and small object/array assembly via plain string concatenation. Pure
# Ruby, no FFI — unit-testable under CRuby + minitest.

module JsonWriter
  # Escape a string for inclusion in a JSON double-quoted value.
  #: (String) -> String
  def self.escape(s)
    out = ""
    s.each_char do |c|
      if c == "\""
        out += "\\\""
      elsif c == "\\"
        out += "\\\\"
      elsif c == "\n"
        out += "\\n"
      elsif c == "\t"
        out += "\\t"
      elsif c == "\r"
        out += "\\r"
      else
        out += c
      end
    end
    out
  end

  # A quoted, escaped JSON string literal.
  #: (String) -> String
  def self.quote(s)
    "\"" + escape(s) + "\""
  end

  # Fixed 4-decimal float, matching the protocol's "%.4f" rule.
  #: (Float) -> String
  def self.f4(x)
    sprintf("%.4f", x)
  end
end
