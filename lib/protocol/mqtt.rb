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

# Packet subclasses — load after Packet itself so their
# +require_relative "../packet"+ hits an already-loaded file and
# doesn't trigger a circular-require warning.
require_relative "mqtt/packet/connect"
require_relative "mqtt/packet/connack"
require_relative "mqtt/packet/publish"
require_relative "mqtt/packet/puback"
require_relative "mqtt/packet/pubrec"
require_relative "mqtt/packet/pubrel"
require_relative "mqtt/packet/pubcomp"
require_relative "mqtt/packet/subscribe"
require_relative "mqtt/packet/suback"
require_relative "mqtt/packet/unsubscribe"
require_relative "mqtt/packet/unsuback"
require_relative "mqtt/packet/pingreq"
require_relative "mqtt/packet/pingresp"
require_relative "mqtt/packet/disconnect"
require_relative "mqtt/packet/auth"

require_relative "mqtt/connection"
