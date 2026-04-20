# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"

module Protocol
  module MQTT
    class Packet
      # SUBSCRIBE (§3.8). Fixed header flags nibble is 0b0010 (MQTT-3.8.1-1).
      #
      # Variable header: packet_id (u16) + v5 property block.
      # Payload: one or more subscription entries. Each entry is a topic
      # filter (utf8) followed by an options byte.
      #
      # Options byte layout:
      #   * bits 0..1 — requested QoS (0..2)
      #   * bit 2     — No Local (v5 only)
      #   * bit 3     — Retain As Published (v5 only)
      #   * bits 4..5 — Retain Handling (v5 only; 0/1/2)
      #   * bits 6..7 — reserved (must be 0)
      #
      # Each +filters+ entry is a Hash:
      #
      #   { filter:, qos: 0, no_local: false, retain_as_published: false,
      #     retain_handling: 0 }
      class Subscribe < Packet
        TYPE_ID = SUBSCRIBE

        attr_reader :packet_id, :filters, :properties


        def initialize(packet_id:, filters:, properties: {})
          raise ArgumentError, "SUBSCRIBE requires at least one filter" if filters.empty?
          @packet_id = packet_id
          @filters = filters.map { |f| normalize_filter(f) }
          @properties = properties
        end


        private def normalize_filter(f)
          {
            filter:              f.fetch(:filter),
            qos:                 f.fetch(:qos, 0),
            no_local:            f.fetch(:no_local, false),
            retain_as_published: f.fetch(:retain_as_published, false),
            retain_handling:     f.fetch(:retain_handling, 0),
          }
        end



        def flags_nibble(_version)
          0b0010
        end


        def encode_body(version)
          w = Codec::Writer.new
          w.write_u16(@packet_id)
          w.write(Property.encode(@properties)) if version == 5
          @filters.each do |f|
            w.write_utf8(f.fetch(:filter))
            opts = f.fetch(:qos, 0) & 0b11
            if version == 5
              opts |= 0b0100 if f[:no_local]
              opts |= 0b1000 if f[:retain_as_published]
              opts |= (f.fetch(:retain_handling, 0) & 0b11) << 4
            end
            w.write_u8(opts)
          end
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          raise MalformedPacket, "SUBSCRIBE reserved flags must be 0b0010" if flags != 0b0010
          packet_id = reader.read_u16
          properties = version == 5 ? Property.decode(reader) : {}
          filters = []
          while !reader.eof?
            filter = reader.read_utf8
            opts = reader.read_u8
            qos = opts & 0b11
            raise MalformedPacket, "invalid QoS 3 in SUBSCRIBE options" if qos == 3
            entry = { filter: filter, qos: qos }
            if version == 5
              entry[:no_local]            = (opts & 0b0100) != 0
              entry[:retain_as_published] = (opts & 0b1000) != 0
              entry[:retain_handling]     = (opts >> 4) & 0b11
              raise MalformedPacket, "invalid retain_handling 3" if entry[:retain_handling] == 3
              raise MalformedPacket, "reserved SUBSCRIBE option bits must be 0" if (opts & 0b11000000) != 0
            else
              raise MalformedPacket, "reserved SUBSCRIBE option bits must be 0" if (opts & 0b11111100) != 0
            end
            filters << entry
          end
          raise MalformedPacket, "SUBSCRIBE must carry at least one filter" if filters.empty?
          new(packet_id: packet_id, filters: filters, properties: properties)
        end


        def ==(other)
          other.is_a?(Subscribe) &&
            other.packet_id == @packet_id &&
            other.filters == @filters &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @packet_id, @filters, @properties].hash
        end
      end

      register(SUBSCRIBE, Subscribe)
    end
  end
end
