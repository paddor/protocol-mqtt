# frozen_string_literal: true

require_relative "../packet"

module Protocol
  module MQTT
    class Packet
      # PINGRESP (§3.13) — keepalive from broker. No body.
      class Pingresp < Packet
        TYPE_ID = PINGRESP


        def encode_body(_version)
          "".b.freeze
        end


        def self.decode_body(_reader, flags:, version:)
          new
        end


        def ==(other)
          other.is_a?(Pingresp)
        end
        alias eql? ==


        def hash
          self.class.hash
        end
      end

      register(PINGRESP, Pingresp)
    end
  end
end
