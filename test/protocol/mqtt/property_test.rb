# frozen_string_literal: true

require "test_helper"

describe Protocol::MQTT::Property do
  def assert_round_trip(props)
    bytes = M::Property.encode(props)
    reader = M::Codec::Reader.new(bytes)
    decoded = M::Property.decode(reader)
    assert reader.eof?
    assert_equal props, decoded
  end


  it "round-trips an empty block" do
    assert_round_trip({})
  end


  it "round-trips a byte property" do
    assert_round_trip(payload_format_indicator: 1)
  end


  it "round-trips u32 properties" do
    assert_round_trip(message_expiry_interval: 3600, session_expiry_interval: 0)
  end


  it "round-trips UTF-8 properties" do
    assert_round_trip(content_type: "application/json", response_topic: "r/x")
  end


  it "round-trips binary properties" do
    assert_round_trip(correlation_data: [0xDE, 0xAD].pack("C*"))
  end


  it "round-trips VBI properties" do
    assert_round_trip(subscription_identifier: [1, 128, 16_384])
  end


  it "preserves repeated user properties" do
    props = { user_property: [["a", "1"], ["b", "2"], ["a", "3"]] }
    bytes = M::Property.encode(props)
    decoded = M::Property.decode(M::Codec::Reader.new(bytes))
    assert_equal props[:user_property], decoded[:user_property]
  end


  it "rejects unknown property ids on decode" do
    w = M::Codec::Writer.new
    body = M::Codec::Writer.new.write_vbi(0x00).write_u8(1).bytes
    w.write_vbi(body.bytesize).write(body)
    assert_raises(M::MalformedPacket) { M::Property.decode(M::Codec::Reader.new(w.bytes)) }
  end


  it "rejects duplicate non-repeatable properties" do
    body = M::Codec::Writer.new
    body.write_vbi(0x01).write_u8(0)
    body.write_vbi(0x01).write_u8(1)
    out = M::Codec::Writer.new
    out.write_vbi(body.bytesize).write(body.bytes)
    assert_raises(M::MalformedPacket) { M::Property.decode(M::Codec::Reader.new(out.bytes)) }
  end


  it "rejects unknown property names on encode" do
    assert_raises(ArgumentError) { M::Property.encode(no_such_prop: 1) }
  end
end
