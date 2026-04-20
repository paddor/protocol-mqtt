# frozen_string_literal: true

require_relative "error"
require_relative "vbi"

module Protocol
  module MQTT
    # Wire-format primitives and cursor-based Reader/Writer for parsing
    # and building MQTT packet bodies. Integers are big-endian; strings
    # and binary blobs are 2-byte-length-prefixed.
    module Codec
      # Cursor reader over a byte string.
      class Reader
        attr_reader :pos


        def initialize(bytes)
          @bytes = bytes.b
          @pos = 0
        end


        def remaining
          @bytes.bytesize - @pos
        end


        def eof?
          @pos >= @bytes.bytesize
        end


        def read(n)
          raise MalformedPacket, "truncated body: need #{n}, have #{remaining}" if remaining < n
          chunk = @bytes.byteslice(@pos, n)
          @pos += n
          chunk
        end


        def read_u8
          read(1).unpack1("C")
        end


        def read_u16
          read(2).unpack1("n")
        end


        def read_u32
          read(4).unpack1("N")
        end


        def read_vbi
          VBI.decode(self)
        end


        def read_utf8
          len = read_u16
          read(len).force_encoding(Encoding::UTF_8)
        end


        def read_binary
          len = read_u16
          read(len)
        end


        def read_string_pair
          [read_utf8, read_utf8]
        end


        def read_rest
          read(remaining)
        end
      end


      # Incremental writer producing a BINARY String.
      class Writer
        def initialize
          @buf = +"".b
        end


        def bytes
          @buf.freeze
        end


        def bytesize
          @buf.bytesize
        end


        def write(str)
          @buf << str.b
          self
        end


        def write_u8(v)
          @buf << [v].pack("C")
          self
        end


        def write_u16(v)
          @buf << [v].pack("n")
          self
        end


        def write_u32(v)
          @buf << [v].pack("N")
          self
        end


        def write_vbi(v)
          @buf << VBI.encode(v)
          self
        end


        def write_utf8(s)
          bytes = s.to_s.b
          raise ProtocolError, "UTF-8 string too long: #{bytes.bytesize}" if bytes.bytesize > 0xFFFF
          @buf << [bytes.bytesize].pack("n") << bytes
          self
        end


        def write_binary(s)
          bytes = s.to_s.b
          raise ProtocolError, "binary data too long: #{bytes.bytesize}" if bytes.bytesize > 0xFFFF
          @buf << [bytes.bytesize].pack("n") << bytes
          self
        end


        def write_string_pair(k, v)
          write_utf8(k)
          write_utf8(v)
          self
        end
      end
    end
  end
end
