# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fusuma/plugin/libinput/version"

Gem::Specification.new do |spec|
  spec.name = "fusuma-plugin-libinput"
  spec.version = Fusuma::Plugin::Libinput::VERSION
  spec.authors = ["iberianpig"]
  spec.email = ["yhkyky@gmail.com"]

  spec.summary = "A Fusuma plugin that reads libinput gestures via a standalone binary (no libinput-tools)."
  spec.description = "This plugin feeds Fusuma with gesture events from a small standalone " \
    "binary (fusuma-libinput-events) that talks to libinput directly and streams events as " \
    "JSON Lines. The binary is compiled ahead-of-time with spinel and depends only on libinput/" \
    "libudev, removing Fusuma's runtime dependency on the libinput-tools CLI. Ships an input " \
    "plugin that spawns the binary and a parser that turns its JSON Lines into gesture records."
  spec.homepage = "https://github.com/iberianpig/fusuma-plugin-libinput"
  spec.license = "MIT"

  spec.files = Dir["{bin,lib,exe,native,tools}/**/*", "LICENSE*", "README*", "*.gemspec"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"

  spec.add_dependency "fusuma", ">= 3.0"
  spec.metadata = {
    "rubygems_mfa_required" => "true"
  }
end
