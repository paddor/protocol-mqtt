# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"
require_relative "../reason_codes"

module Protocol
  module MQTT
    class Packet
      # SUBACK (§3.9).
      #
      # Variable header: packet_id (u16) + v5 property block.
      # Payload: one reason code byte per filter from the originating
      # SUBSCRIBE, in the same order.
      #
      # In v3.1.1 codes are: 0x00..0x02 granted QoS, 0x80 failure.
      # In v5 the full reason-code taxonomy applies.
      class Suback < Packet
        TYPE_ID = SUBACK

        attr_reader :packet_id, :reason_codes, :properties


        def initialize(packet_id:, reason_codes:, properties: {})
          raise ArgumentError, "SUBACK requires at least one reason code" if reason_codes.empty?
          @packet_id = packet_id
          @reason_codes = reason_codes
          @properties = properties
        end


        def encode_body(version)
          w = Codec::Writer.new
          w.write_u16(@packet_id)
          w.write(Property.encode(@properties)) if version == 5
          @reason_codes.each { |rc| w.write_u8(rc) }
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          packet_id = reader.read_u16
          properties = version == 5 ? Property.decode(reader) : {}
          reason_codes = []
          reason_codes << reader.read_u8 while !reader.eof?
          raise MalformedPacket, "SUBACK must carry at least one reason code" if reason_codes.empty?
          new(packet_id: packet_id, reason_codes: reason_codes, properties: properties)
        end


        def ==(other)
          other.is_a?(Suback) &&
            other.packet_id == @packet_id &&
            other.reason_codes == @reason_codes &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @packet_id, @reason_codes, @properties].hash
        end
      end

      register(SUBACK, Suback)
    end
  end
end
