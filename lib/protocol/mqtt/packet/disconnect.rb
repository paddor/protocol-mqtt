# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"
require_relative "../reason_codes"

module Protocol
  module MQTT
    class Packet
      # DISCONNECT (§3.14).
      #
      # v3.1.1: empty body.
      # v5: reason code (1 byte) + optional property block. Empty body
      #     is equivalent to reason=NORMAL_DISCONNECTION with no props.
      class Disconnect < Packet
        TYPE_ID = DISCONNECT

        attr_reader :reason_code, :properties


        def initialize(reason_code: ReasonCodes::NORMAL_DISCONNECTION, properties: {})
          @reason_code = reason_code
          @properties = properties
        end


        def encode_body(version)
          return "".b.freeze if version == 3
          w = Codec::Writer.new
          if @properties.empty? && @reason_code == ReasonCodes::NORMAL_DISCONNECTION
            return "".b.freeze
          end
          w.write_u8(@reason_code)
          w.write(Property.encode(@properties))
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          if version == 3 || reader.eof?
            return new
          end
          reason_code = reader.read_u8
          properties = reader.eof? ? {} : Property.decode(reader)
          new(reason_code: reason_code, properties: properties)
        end


        def ==(other)
          other.is_a?(Disconnect) &&
            other.reason_code == @reason_code &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @reason_code, @properties].hash
        end
      end

      register(DISCONNECT, Disconnect)
    end
  end
end
