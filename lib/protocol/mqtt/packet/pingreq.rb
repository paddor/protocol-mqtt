# frozen_string_literal: true

require_relative "../packet"

module Protocol
  module MQTT
    class Packet
      # PINGREQ (§3.12) — keepalive from client. No body.
      class Pingreq < Packet
        TYPE_ID = PINGREQ


        def encode_body(_version)
          "".b.freeze
        end


        def self.decode_body(_reader, flags:, version:)
          new
        end


        def ==(other)
          other.is_a?(Pingreq)
        end
        alias eql? ==


        def hash
          self.class.hash
        end
      end

      register(PINGREQ, Pingreq)
    end
  end
end
