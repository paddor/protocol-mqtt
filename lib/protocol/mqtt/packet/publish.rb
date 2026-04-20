# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"

module Protocol
  module MQTT
    class Packet
      # PUBLISH (§3.3) — application message.
      #
      # Fixed header flags (low nibble of byte 0): DUP(3) | QoS(2..1) | RETAIN(0).
      #
      # Variable header:
      #   * topic_name (UTF-8); may be empty in v5 when topic_alias is set
      #   * packet_id (u16) — only when qos > 0
      #   * v5 property block
      # Payload: remaining bytes (application data, opaque BINARY).
      class Publish < Packet
        TYPE_ID = PUBLISH

        attr_reader :topic, :payload, :qos, :retain, :dup, :packet_id, :properties


        def initialize(topic:, payload:, qos: 0, retain: false, dup: false, packet_id: nil, properties: {})
          raise ArgumentError, "qos must be 0..2" unless (0..2).include?(qos)
          raise ArgumentError, "packet_id required for qos > 0" if qos > 0 && packet_id.nil?
          raise ArgumentError, "packet_id forbidden for qos 0" if qos == 0 && !packet_id.nil?
          @topic = topic
          @payload = payload.b
          @qos = qos
          @retain = retain
          @dup = dup
          @packet_id = packet_id
          @properties = properties
        end


        def flags_nibble(_version)
          n = 0
          n |= 0b1000 if @dup
          n |= (@qos & 0b11) << 1
          n |= 0b0001 if @retain
          n
        end


        def encode_body(version)
          w = Codec::Writer.new
          w.write_utf8(@topic)
          w.write_u16(@packet_id) if @qos > 0
          w.write(Property.encode(@properties)) if version == 5
          w.write(@payload)
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          dup    = (flags & 0b1000) != 0
          qos    = (flags >> 1) & 0b11
          retain = (flags & 0b0001) != 0
          raise MalformedPacket, "invalid QoS 3 in PUBLISH" if qos == 3
          raise MalformedPacket, "DUP must be 0 when QoS is 0" if dup && qos == 0

          topic = reader.read_utf8
          packet_id = qos > 0 ? reader.read_u16 : nil
          properties = version == 5 ? Property.decode(reader) : {}
          payload = reader.read_rest
          new(
            topic: topic, payload: payload, qos: qos, retain: retain, dup: dup,
            packet_id: packet_id, properties: properties,
          )
        end


        def ==(other)
          other.is_a?(Publish) &&
            other.topic == @topic &&
            other.payload == @payload &&
            other.qos == @qos &&
            other.retain == @retain &&
            other.dup == @dup &&
            other.packet_id == @packet_id &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @topic, @payload, @qos, @retain, @dup, @packet_id, @properties].hash
        end
      end

      register(PUBLISH, Publish)
    end
  end
end
