# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"
require_relative "../reason_codes"

module Protocol
  module MQTT
    class Packet
      # UNSUBACK (§3.11).
      #
      # v3.1.1: body is just the packet id — no per-filter results.
      # v5: packet_id + property block + one reason code per filter.
      class Unsuback < Packet
        TYPE_ID = UNSUBACK

        attr_reader :packet_id, :reason_codes, :properties


        def initialize(packet_id:, reason_codes: [], properties: {})
          @packet_id = packet_id
          @reason_codes = reason_codes
          @properties = properties
        end


        def encode_body(version)
          w = Codec::Writer.new
          w.write_u16(@packet_id)
          if version == 5
            w.write(Property.encode(@properties))
            @reason_codes.each { |rc| w.write_u8(rc) }
          end
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          packet_id = reader.read_u16
          if version == 5
            properties = Property.decode(reader)
            reason_codes = []
            reason_codes << reader.read_u8 while !reader.eof?
            raise MalformedPacket, "v5 UNSUBACK must carry at least one reason code" if reason_codes.empty?
            new(packet_id: packet_id, reason_codes: reason_codes, properties: properties)
          else
            new(packet_id: packet_id)
          end
        end


        def ==(other)
          other.is_a?(Unsuback) &&
            other.packet_id == @packet_id &&
            other.reason_codes == @reason_codes &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @packet_id, @reason_codes, @properties].hash
        end
      end

      register(UNSUBACK, Unsuback)
    end
  end
end
