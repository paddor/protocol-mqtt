# frozen_string_literal: true

require_relative "../packet"
require_relative "../property"
require_relative "../reason_codes"

module Protocol
  module MQTT
    class Packet
      # AUTH (§3.15) — v5 only. Enhanced authentication exchange.
      #
      # Body: reason code (u8) + optional property block. Empty body is
      # equivalent to reason=SUCCESS with no props.
      class Auth < Packet
        TYPE_ID = AUTH

        attr_reader :reason_code, :properties


        def initialize(reason_code: ReasonCodes::SUCCESS, properties: {})
          @reason_code = reason_code
          @properties = properties
        end


        def encode_body(version)
          raise ProtocolError, "AUTH is v5-only" if version != 5
          if @properties.empty? && @reason_code == ReasonCodes::SUCCESS
            return "".b.freeze
          end
          w = Codec::Writer.new
          w.write_u8(@reason_code)
          w.write(Property.encode(@properties))
          w.bytes
        end


        def self.decode_body(reader, flags:, version:)
          raise ProtocolError, "AUTH is v5-only" if version != 5
          return new if reader.eof?
          reason_code = reader.read_u8
          properties = reader.eof? ? {} : Property.decode(reader)
          new(reason_code: reason_code, properties: properties)
        end


        def ==(other)
          other.is_a?(Auth) &&
            other.reason_code == @reason_code &&
            other.properties == @properties
        end
        alias eql? ==


        def hash
          [self.class, @reason_code, @properties].hash
        end
      end

      register(AUTH, Auth)
    end
  end
end
