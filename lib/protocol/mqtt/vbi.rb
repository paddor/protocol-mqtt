# frozen_string_literal: true

module Protocol
  module MQTT
    # Variable Byte Integer (MQTT spec §1.5.5). Base-128, little-endian,
    # continuation bit on byte 7. 1 to 4 bytes, max value 268,435,455.
    module VBI
      MAX = 268_435_455
      MAX_BYTES = 4


      # Returns a frozen BINARY String of 1..4 bytes.
      def self.encode(value)
        raise ArgumentError, "VBI out of range: #{value}" if value.negative? || value > MAX
        bytes = +"".b
        loop do
          digit = value % 128
          value /= 128
          digit |= 0x80 if value.positive?
          bytes << digit
          break if value.zero?
        end
        bytes.freeze
      end


      # Decodes a VBI from +io+, which must respond to #read(n). Raises
      # MalformedPacket on truncation or on a 5th continuation byte.
      def self.decode(io)
        multiplier = 1
        value = 0
        MAX_BYTES.times do
          byte = io.read(1) or raise MalformedPacket, "truncated VBI"
          byte = byte.unpack1("C")
          value += (byte & 0x7F) * multiplier
          return value if (byte & 0x80).zero?
          multiplier *= 128
        end
        raise MalformedPacket, "VBI exceeds 4 bytes"
      end
    end
  end
end
