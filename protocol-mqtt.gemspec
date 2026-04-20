# frozen_string_literal: true

require_relative "lib/protocol/mqtt/version"

Gem::Specification.new do |s|
  s.name     = "protocol-mqtt"
  s.version  = Protocol::MQTT::VERSION
  s.authors  = ["Patrik Wenger"]
  s.email    = ["paddor@gmail.com"]
  s.summary  = "Pure Ruby MQTT 3.1.1 + 5.0 wire codec"
  s.description = "Pure Ruby implementation of the MQTT 3.1.1 and 5.0 " \
                  "packet codec: encode, decode, VBI, properties, reason " \
                  "codes. Protocol::MQTT::Connection wraps an IO::Stream " \
                  "to read and write packets. No I/O beyond IO::Stream."
  s.homepage = "https://github.com/paddor/protocol-mqtt"
  s.license  = "ISC"

  s.required_ruby_version = ">= 4.0"

  s.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "CHANGELOG.md"]

  s.add_dependency "io-stream", "~> 0.11"
end
