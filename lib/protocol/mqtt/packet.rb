# frozen_string_literal: true

require_relative "codec"
require_relative "error"
require_relative "vbi"

module Protocol
  module MQTT
    # Base class for all MQTT control packets.
    #
    # Wire layout of every packet:
    #
    #   byte 0: [ type (4 bits) | flags (4 bits) ]
    #   byte 1+: VBI remaining-length
    #   byte N+: variable header + payload (length = remaining-length)
    #
    # Subclasses implement:
    #
    #   * +TYPE_ID+ (1..15) — the type nibble
    #   * +#flags_nibble(version)+ — returns the low 4 bits of byte 0.
    #     Most packets return 0. PUBREL/SUBSCRIBE/UNSUBSCRIBE return
    #     0b0010. PUBLISH returns DUP|QoS|RETAIN.
    #   * +#encode_body(version)+ — variable header + payload bytes.
    #   * +Subclass.decode_body(reader, flags:, version:)+ — parses a
    #     Codec::Reader positioned at the start of the variable header
    #     and returns an instance.
    class Packet
      CONNECT     = 1
      CONNACK     = 2
      PUBLISH     = 3
      PUBACK      = 4
      PUBREC      = 5
      PUBREL      = 6
      PUBCOMP     = 7
      SUBSCRIBE   = 8
      SUBACK      = 9
      UNSUBSCRIBE = 10
      UNSUBACK    = 11
      PINGREQ     = 12
      PINGRESP    = 13
      DISCONNECT  = 14
      AUTH        = 15

      # Set by subclasses (filled in as they are required).
      @registry = {}

      class << self
        attr_reader :registry


        def register(type_id, klass)
          @registry[type_id] = klass
        end


        # Encode the packet's fixed header + body into a frozen BINARY
        # String.
        def encode_packet(packet, version:)
          body = packet.encode_body(version)
          head = Codec::Writer.new
          head.write_u8((packet.class::TYPE_ID << 4) | packet.flags_nibble(version))
          head.write_vbi(body.bytesize)
          (head.bytes + body).force_encoding(Encoding::BINARY).freeze
        end


        # Given bytes containing at least one full packet, decode the
        # first one. Returns [packet, bytes_consumed]. Raises
        # MalformedPacket on truncation — caller is responsible for
        # having buffered enough bytes. For streaming decode, use
        # Protocol::MQTT::Connection.
        def decode(bytes, version:)
          reader = Codec::Reader.new(bytes)
          type_flags = reader.read_u8
          type = type_flags >> 4
          flags = type_flags & 0x0F
          length = reader.read_vbi
          raise MalformedPacket, "truncated packet body" if reader.remaining < length
          body = reader.read(length)
          [decode_from_body(type, flags, body, version: version), reader.pos]
        end


        # Dispatch a pre-framed packet body to its subclass's decode_body.
        # Used by streaming decoders (see +Protocol::MQTT::Connection+).
        def decode_from_body(type, flags, body, version:)
          klass = @registry[type] or raise MalformedPacket, "unknown packet type #{type}"
          body_reader = Codec::Reader.new(body)
          pkt = klass.decode_body(body_reader, flags: flags, version: version)
          raise MalformedPacket, "#{klass.name} body overrun" unless body_reader.eof?
          pkt
        end
      end


      # Default flags nibble (overridden by PUBLISH, PUBREL, SUBSCRIBE,
      # UNSUBSCRIBE).
      def flags_nibble(_version)
        0
      end


      def encode(version:)
        Packet.encode_packet(self, version: version)
      end
    end
  end
end

# Require all packet subclasses so their TYPE_IDs register.
require_relative "packet/connect"
require_relative "packet/connack"
require_relative "packet/publish"
require_relative "packet/puback"
require_relative "packet/pubrec"
require_relative "packet/pubrel"
require_relative "packet/pubcomp"
require_relative "packet/subscribe"
require_relative "packet/suback"
require_relative "packet/unsubscribe"
require_relative "packet/unsuback"
require_relative "packet/pingreq"
require_relative "packet/pingresp"
require_relative "packet/disconnect"
require_relative "packet/auth"
