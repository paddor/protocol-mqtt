# frozen_string_literal: true

require_relative "codec"
require_relative "error"
require_relative "packet"
require_relative "vbi"

module Protocol
  module MQTT
    # Streaming packet framer over a buffered IO (e.g. Async::IO::Stream).
    #
    # The only I/O coupling in the +protocol-mqtt+ gem. Reads and writes
    # whole +Packet+ objects one at a time; does not implement the MQTT
    # session state machine (that lives in the +zzq+ runtime).
    #
    # Wire version is set separately from construction because a server
    # cannot know it until the CONNECT packet has been parsed. Pattern:
    #
    #   conn = Protocol::MQTT::Connection.new(io)  # defaults to v3
    #   connect = conn.read_packet
    #   conn.version = 5  # if connect says so
    #   # ... subsequent reads/writes branch on @version
    #
    # Not fiber-safe: a single Connection should be owned by at most one
    # reader fiber and one writer fiber. Concurrent writers must
    # synchronize externally.
    class Connection
      # Default MQTT wire version (v3.1.1). Set via +#version=+ after
      # CONNECT is received.
      DEFAULT_VERSION = 3

      # @return [3, 5]
      attr_accessor :version

      # @return [#read, #read_exactly, #write, #flush, #close] underlying IO
      attr_reader :io

      # @return [Integer, nil] maximum inbound packet size in bytes; nil =
      #   unlimited. When set, a decoded remaining-length > max raises
      #   MalformedPacket before body is consumed.
      attr_accessor :max_packet_size


      def initialize(io, version: DEFAULT_VERSION, max_packet_size: nil)
        @io = io
        @version = version
        @max_packet_size = max_packet_size
        @closed = false
      end


      # Reads one complete packet from the IO.
      #
      # @return [Packet, nil] decoded packet, or +nil+ on clean EOF at a
      #   packet boundary.
      # @raise [MalformedPacket] on EOF mid-packet or a spec violation.
      def read_packet
        first = @io.read(1)
        return nil if first.nil? || first.empty?

        type_flags = first.unpack1("C")
        type = type_flags >> 4
        flags = type_flags & 0x0F

        length = read_vbi_from_io
        if @max_packet_size && (length + 2) > @max_packet_size
          raise MalformedPacket, "packet exceeds max_packet_size: #{length + 2} > #{@max_packet_size}"
        end

        body = length.zero? ? "".b : read_exactly(length)
        Packet.decode_from_body(type, flags, body, version: @version)
      end


      # Reads a CONNECT packet from the IO, auto-detecting the wire
      # version from the Protocol Level byte and setting +#version+
      # before decoding the body. Brokers use this for the first packet
      # on a newly accepted connection; after it returns, subsequent
      # +#read_packet+ / +#write_packet+ calls honor the negotiated
      # version.
      #
      # @return [Packet::Connect, nil] decoded CONNECT, or +nil+ on EOF.
      # @raise [MalformedPacket] if the first packet isn't CONNECT or
      #   the protocol level is unsupported.
      def read_connect_packet
        first = @io.read(1)
        return nil if first.nil? || first.empty?

        type_flags = first.unpack1("C")
        type = type_flags >> 4
        flags = type_flags & 0x0F
        raise MalformedPacket, "expected CONNECT, got type #{type}" unless type == Packet::CONNECT

        length = read_vbi_from_io
        if @max_packet_size && (length + 2) > @max_packet_size
          raise MalformedPacket, "packet exceeds max_packet_size: #{length + 2} > #{@max_packet_size}"
        end

        body = length.zero? ? "".b : read_exactly(length)
        level = Packet::Connect.peek_protocol_level(body)
        @version = level == 5 ? 5 : 3
        Packet.decode_from_body(type, flags, body, version: @version)
      end


      # Encodes and writes one packet, then flushes.
      #
      # @param packet [Packet]
      # @return [void]
      def write_packet(packet)
        raise ClosedError, "connection closed" if @closed
        @io.write(packet.encode(version: @version))
        @io.flush
      end


      # Close the underlying IO. Idempotent.
      def close
        return if @closed
        @closed = true
        @io.close
      end


      def closed?
        @closed
      end


      private def read_vbi_from_io
        multiplier = 1
        value = 0
        VBI::MAX_BYTES.times do
          byte = read_exactly(1).unpack1("C")
          value += (byte & 0x7F) * multiplier
          return value if (byte & 0x80).zero?
          multiplier *= 128
        end
        raise MalformedPacket, "VBI exceeds 4 bytes"
      end


      private def read_exactly(n)
        chunk =
          if @io.respond_to?(:read_exactly)
            begin
              @io.read_exactly(n)
            rescue EOFError
              nil
            end
          else
            @io.read(n)
          end
        raise MalformedPacket, "truncated: need #{n} bytes" if chunk.nil? || chunk.bytesize < n
        chunk
      end
    end
  end
end
