# frozen_string_literal: true

module Protocol
  # MQTT wire codec. Implements MQTT 3.1.1 (OASIS 2014) and MQTT 5.0
  # (OASIS 2019). Pure codec: encode/decode of packets and primitives.
  # The only IO coupling is Protocol::MQTT::Connection, which reads and
  # writes packets over an IO::Stream.
  module MQTT
  end
end

require_relative "mqtt/version"
require_relative "mqtt/error"
require_relative "mqtt/vbi"
require_relative "mqtt/codec"
require_relative "mqtt/reason_codes"
require_relative "mqtt/property"
require_relative "mqtt/packet"
require_relative "mqtt/connection"
