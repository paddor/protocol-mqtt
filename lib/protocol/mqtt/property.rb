# frozen_string_literal: true

require_relative "codec"
require_relative "error"

module Protocol
  module MQTT
    # v5 property identifiers and property-block codec (§2.2.2).
    #
    # A property block is: VBI-length-prefixed sequence of
    # { identifier (VBI), value } pairs. Value type is fixed per
    # identifier. All identifiers appear at most once per packet except
    # 0x26 User Property, which may repeat.
    module Property
      # Value types
      BYTE        = :byte
      U16         = :u16
      U32         = :u32
      VBI_TYPE    = :vbi
      UTF8        = :utf8
      BINARY      = :binary
      STRING_PAIR = :string_pair

      # Identifier → [symbolic_name, type]
      TABLE = {
        0x01 => [:payload_format_indicator,          BYTE],
        0x02 => [:message_expiry_interval,           U32],
        0x03 => [:content_type,                      UTF8],
        0x08 => [:response_topic,                    UTF8],
        0x09 => [:correlation_data,                  BINARY],
        0x0B => [:subscription_identifier,           VBI_TYPE],
        0x11 => [:session_expiry_interval,           U32],
        0x12 => [:assigned_client_identifier,        UTF8],
        0x13 => [:server_keep_alive,                 U16],
        0x15 => [:authentication_method,             UTF8],
        0x16 => [:authentication_data,               BINARY],
        0x17 => [:request_problem_information,       BYTE],
        0x18 => [:will_delay_interval,               U32],
        0x19 => [:request_response_information,      BYTE],
        0x1A => [:response_information,              UTF8],
        0x1C => [:server_reference,                  UTF8],
        0x1F => [:reason_string,                     UTF8],
        0x21 => [:receive_maximum,                   U16],
        0x22 => [:topic_alias_maximum,               U16],
        0x23 => [:topic_alias,                       U16],
        0x24 => [:maximum_qos,                       BYTE],
        0x25 => [:retain_available,                  BYTE],
        0x26 => [:user_property,                     STRING_PAIR],
        0x27 => [:maximum_packet_size,               U32],
        0x28 => [:wildcard_subscription_available,   BYTE],
        0x29 => [:subscription_identifier_available, BYTE],
        0x2A => [:shared_subscription_available,     BYTE],
      }.freeze

      NAME_TO_ID = TABLE.to_h { |id, (name, _t)| [name, id] }.freeze

      # Every identifier allows zero-or-one occurrence EXCEPT user_property
      # (repeatable) and subscription_identifier (repeatable in PUBLISH only,
      # for multiple matching subscriptions).
      REPEATABLE = {
        0x26 => true,  # user_property
        0x0B => true,  # subscription_identifier
      }.freeze

      # Encode a Hash of { name_symbol => value, user_property: [[k,v], ...] }
      # into a full property block (VBI length prefix + body). Returns a
      # frozen BINARY String.
      def self.encode(properties)
        body = Codec::Writer.new
        properties.each do |name, value|
          id = NAME_TO_ID[name] or raise ArgumentError, "unknown property: #{name}"
          _, type = TABLE[id]
          values = REPEATABLE[id] ? Array(value) : [value]
          values.each do |v|
            body.write_vbi(id)
            encode_value(body, type, v)
          end
        end

        out = Codec::Writer.new
        out.write_vbi(body.bytesize)
        out.write(body.bytes)
        out.bytes
      end


      # Decode a property block starting at the current position of a
      # Codec::Reader. Consumes VBI length + that many bytes. Returns a
      # Hash keyed by name symbol. Unknown ids raise MalformedPacket.
      def self.decode(reader)
        length = reader.read_vbi
        raise MalformedPacket, "property block length exceeds remaining" if length > reader.remaining
        end_pos = reader.pos + length
        props = {}
        while reader.pos < end_pos
          id = reader.read_vbi
          entry = TABLE[id] or raise MalformedPacket, "unknown property id 0x#{id.to_s(16)}"
          name, type = entry
          value = decode_value(reader, type)
          if name == :user_property
            (props[:user_property] ||= []) << value
          elsif REPEATABLE[id]
            (props[name] ||= []) << value
          else
            raise MalformedPacket, "duplicate property #{name}" if props.key?(name)
            props[name] = value
          end
        end
        raise MalformedPacket, "property block overrun" if reader.pos != end_pos
        props
      end


      def self.encode_value(w, type, v)
        case type
        when BYTE
          w.write_u8(v)
        when U16
          w.write_u16(v)
        when U32
          w.write_u32(v)
        when VBI_TYPE
          w.write_vbi(v)
        when UTF8
          w.write_utf8(v)
        when BINARY
          w.write_binary(v)
        when STRING_PAIR
          w.write_string_pair(v[0], v[1])
        end
      end
      private_class_method :encode_value


      def self.decode_value(r, type)
        case type
        when BYTE        then r.read_u8
        when U16         then r.read_u16
        when U32         then r.read_u32
        when VBI_TYPE    then r.read_vbi
        when UTF8        then r.read_utf8
        when BINARY      then r.read_binary
        when STRING_PAIR then r.read_string_pair
        end
      end
      private_class_method :decode_value
    end
  end
end
