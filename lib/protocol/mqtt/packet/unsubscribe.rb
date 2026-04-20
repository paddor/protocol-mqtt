# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"

module Protocol
  module MQTT
    class Packet
      # UNSUBSCRIBE (§3.10). Fixed header flags nibble is 0b0010 (MQTT-3.10.1-1).
      #
      # Variable header: packet_id (u16) + v5 property block.
      # Payload: one or more topic filters (utf8), no options byte.
      class Unsubscribe < Packet
        TYPE_ID = UNSUBSCRIBE

        attr_reader :packet_id, :filters, :properties


        def initialize(packet_id:, filters:, properties: {})
          raise ArgumentError, "UNSUBSCRIBE requires at least one filter" if filters.empty?
          @packet_id = packet_id
          @filters = filters
          @properties = properties
        end


        def flags_nibble(_version)
          0b0010
        end


        def encode_body(version)
          w = Codec::Writer.new
          w.write_u16(@packet_id)
          w.write(Property.encode(@properties)) if version == 5
          @filters.each { |f| w.write_utf8(f) }
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          raise MalformedPacket, "UNSUBSCRIBE reserved flags must be 0b0010" if flags != 0b0010
          packet_id = reader.read_u16
          properties = version == 5 ? Property.decode(reader) : {}
          filters = []
          filters << reader.read_utf8 while !reader.eof?
          raise MalformedPacket, "UNSUBSCRIBE must carry at least one filter" if filters.empty?
          new(packet_id: packet_id, filters: filters, properties: properties)
        end


        def ==(other)
          other.is_a?(Unsubscribe) &&
            other.packet_id == @packet_id &&
            other.filters == @filters &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @packet_id, @filters, @properties].hash
        end
      end

      register(UNSUBSCRIBE, Unsubscribe)
    end
  end
end
