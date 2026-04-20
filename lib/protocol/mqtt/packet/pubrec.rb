# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"
require_relative "../reason_codes"

module Protocol
  module MQTT
    class Packet
      # PUBREC (§3.5) — QoS 2 first acknowledgement. Same body shape as PUBACK.
      class Pubrec < Packet
        TYPE_ID = PUBREC

        attr_reader :packet_id, :reason_code, :properties


        def initialize(packet_id:, reason_code: ReasonCodes::SUCCESS, properties: {})
          @packet_id = packet_id
          @reason_code = reason_code
          @properties = properties
        end


        def encode_body(version)
          w = Codec::Writer.new
          w.write_u16(@packet_id)
          if version == 5 && !(@properties.empty? && @reason_code == ReasonCodes::SUCCESS)
            w.write_u8(@reason_code)
            w.write(Property.encode(@properties)) unless @properties.empty?
          end
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          packet_id = reader.read_u16
          if version == 5 && !reader.eof?
            reason_code = reader.read_u8
            properties = reader.eof? ? {} : Property.decode(reader)
            new(packet_id: packet_id, reason_code: reason_code, properties: properties)
          else
            new(packet_id: packet_id)
          end
        end


        def ==(other)
          other.is_a?(Pubrec) &&
            other.packet_id == @packet_id &&
            other.reason_code == @reason_code &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @packet_id, @reason_code, @properties].hash
        end
      end

      register(PUBREC, Pubrec)
    end
  end
end
