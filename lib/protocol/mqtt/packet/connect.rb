# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"

module Protocol
  module MQTT
    class Packet
      # CONNECT (§3.1) — first packet on every connection, identifies the client.
      #
      # Variable header: protocol_name (utf8) + protocol_level (u8) +
      # connect_flags (u8) + keep_alive (u16) + v5 property block.
      #
      # Payload (ordered): client_id, [v5 will_properties], [will_topic,
      # will_payload], [username], [password].
      #
      # +will+ is either nil or a Hash:
      #
      #   { topic:, payload:, qos: 0, retain: false, properties: {} }
      class Connect < Packet
        TYPE_ID = CONNECT

        PROTOCOL_NAME = "MQTT"

        # Connect flag bits
        FLAG_USER_NAME      = 0b10000000
        FLAG_PASSWORD       = 0b01000000
        FLAG_WILL_RETAIN    = 0b00100000
        FLAG_WILL_QOS_MASK  = 0b00011000
        FLAG_WILL_QOS_SHIFT = 3
        FLAG_WILL           = 0b00000100
        FLAG_CLEAN_START    = 0b00000010

        attr_reader :client_id, :clean_start, :keep_alive, :username, :password,
                    :will, :properties


        def initialize(client_id:, clean_start: true, keep_alive: 0,
                       username: nil, password: nil, will: nil, properties: {})
          @client_id   = client_id
          @clean_start = clean_start
          @keep_alive  = keep_alive
          @username    = username
          @password    = password
          @will        = will ? normalize_will(will) : nil
          @properties  = properties
        end


        private def normalize_will(will)
          {
            topic:      will.fetch(:topic),
            payload:    will.fetch(:payload).b,
            qos:        will.fetch(:qos, 0),
            retain:     will.fetch(:retain, false),
            properties: will.fetch(:properties, {}),
          }
        end



        # Peeks the Protocol Level byte (4 = v3.1.1, 5 = v5) from a
        # raw CONNECT body. Used by brokers to pick the wire version
        # before full decode. Does not consume from +body_bytes+.
        def self.peek_protocol_level(body_bytes)
          r = Codec::Reader.new(body_bytes)
          name = r.read_utf8
          raise MalformedPacket, "expected MQTT protocol name, got #{name.inspect}" unless name == PROTOCOL_NAME
          r.read_u8
        end


        def encode_body(version)
          raise ProtocolError, "CONNECT requires version 3 or 5, got #{version}" unless [3, 5].include?(version)
          w = Codec::Writer.new
          w.write_utf8(PROTOCOL_NAME)
          w.write_u8(version == 5 ? 5 : 4)

          flags = 0
          flags |= FLAG_USER_NAME    if @username
          flags |= FLAG_PASSWORD     if @password
          flags |= FLAG_CLEAN_START  if @clean_start
          if @will
            flags |= FLAG_WILL
            flags |= (@will.fetch(:qos, 0) & 0b11) << FLAG_WILL_QOS_SHIFT
            flags |= FLAG_WILL_RETAIN if @will[:retain]
          end
          w.write_u8(flags)

          w.write_u16(@keep_alive)
          w.write(Property.encode(@properties)) if version == 5

          w.write_utf8(@client_id)
          if @will
            w.write(Property.encode(@will.fetch(:properties, {}))) if version == 5
            w.write_utf8(@will.fetch(:topic))
            w.write_binary(@will.fetch(:payload))
          end
          w.write_utf8(@username) if @username
          w.write_binary(@password) if @password
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          protocol_name = reader.read_utf8
          protocol_level = reader.read_u8
          raise MalformedPacket, "unsupported protocol name: #{protocol_name.inspect}" unless protocol_name == PROTOCOL_NAME
          wire_version = protocol_level == 5 ? 5 : protocol_level == 4 ? 3 : nil
          raise MalformedPacket, "unsupported protocol level: #{protocol_level}" unless wire_version

          connect_flags = reader.read_u8
          raise MalformedPacket, "reserved connect flag bit must be 0" if (connect_flags & 0b1) != 0
          keep_alive = reader.read_u16
          properties = wire_version == 5 ? Property.decode(reader) : {}

          client_id = reader.read_utf8

          will = nil
          if (connect_flags & FLAG_WILL) != 0
            will_qos = (connect_flags & FLAG_WILL_QOS_MASK) >> FLAG_WILL_QOS_SHIFT
            raise MalformedPacket, "invalid Will QoS 3" if will_qos == 3
            will_retain = (connect_flags & FLAG_WILL_RETAIN) != 0
            will_props = wire_version == 5 ? Property.decode(reader) : {}
            will_topic = reader.read_utf8
            will_payload = reader.read_binary
            will = {
              topic: will_topic,
              payload: will_payload,
              qos: will_qos,
              retain: will_retain,
              properties: will_props,
            }
          elsif (connect_flags & FLAG_WILL_RETAIN) != 0
            raise MalformedPacket, "Will Retain set without Will Flag"
          end

          username = (connect_flags & FLAG_USER_NAME) != 0 ? reader.read_utf8 : nil
          password = (connect_flags & FLAG_PASSWORD) != 0 ? reader.read_binary : nil

          new(
            client_id:   client_id,
            clean_start: (connect_flags & FLAG_CLEAN_START) != 0,
            keep_alive:  keep_alive,
            username:    username,
            password:    password,
            will:        will,
            properties:  properties,
          )
        end


        def ==(other)
          other.is_a?(Connect) &&
            other.client_id == @client_id &&
            other.clean_start == @clean_start &&
            other.keep_alive == @keep_alive &&
            other.username == @username &&
            other.password == @password &&
            other.will == @will &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @client_id, @clean_start, @keep_alive, @username, @password, @will, @properties].hash
        end
      end

      register(CONNECT, Connect)
    end
  end
end
