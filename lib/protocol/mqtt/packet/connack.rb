# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"
require_relative "../reason_codes"

module Protocol
  module MQTT
    class Packet
      # CONNACK (§3.2) — response to CONNECT.
      #
      # Variable header: acknowledge_flags (u8, bit 0 = session_present) +
      # reason/return code (u8) + v5 property block.
      class Connack < Packet
        TYPE_ID = CONNACK

        attr_reader :session_present, :reason_code, :properties


        def initialize(session_present: false, reason_code: ReasonCodes::SUCCESS, properties: {})
          @session_present = session_present
          @reason_code = reason_code
          @properties = properties
        end


        def encode_body(version)
          w = Codec::Writer.new
          w.write_u8(@session_present ? 1 : 0)
          w.write_u8(@reason_code)
          w.write(Property.encode(@properties)) if version == 5
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          ack_flags = reader.read_u8
          raise MalformedPacket, "reserved CONNACK flag bits must be 0" if (ack_flags & 0b11111110) != 0
          session_present = (ack_flags & 0b1) != 0
          reason_code = reader.read_u8
          properties = version == 5 ? Property.decode(reader) : {}
          new(session_present: session_present, reason_code: reason_code, properties: properties)
        end


        def ==(other)
          other.is_a?(Connack) &&
            other.session_present == @session_present &&
            other.reason_code == @reason_code &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @session_present, @reason_code, @properties].hash
        end
      end

      register(CONNACK, Connack)
    end
  end
end
