# frozen_string_literal: true

require "test_helper"

describe Protocol::MQTT::Codec do
  it "round-trips u8/u16/u32 integers" do
    w = M::Codec::Writer.new
    w.write_u8(0x7E).write_u16(0xBEEF).write_u32(0xDEAD_BEEF)
    r = M::Codec::Reader.new(w.bytes)
    assert_equal 0x7E, r.read_u8
    assert_equal 0xBEEF, r.read_u16
    assert_equal 0xDEAD_BEEF, r.read_u32
    assert r.eof?
  end


  it "round-trips UTF-8 strings" do
    w = M::Codec::Writer.new
    w.write_utf8("hello")
    r = M::Codec::Reader.new(w.bytes)
    out = r.read_utf8
    assert_equal "hello", out
    assert_equal Encoding::UTF_8, out.encoding
  end


  it "round-trips binary data" do
    payload = [0x00, 0xFF, 0x10, 0x20].pack("C*")
    w = M::Codec::Writer.new.write_binary(payload)
    r = M::Codec::Reader.new(w.bytes)
    assert_equal payload, r.read_binary
  end


  it "round-trips string pairs" do
    w = M::Codec::Writer.new.write_string_pair("k", "v")
    r = M::Codec::Reader.new(w.bytes)
    assert_equal ["k", "v"], r.read_string_pair
  end


  it "round-trips VBI values" do
    w = M::Codec::Writer.new.write_vbi(16_384)
    r = M::Codec::Reader.new(w.bytes)
    assert_equal 16_384, r.read_vbi
  end


  it "raises MalformedPacket when reader is truncated" do
    r = M::Codec::Reader.new("ab")
    assert_raises(M::MalformedPacket) { r.read_u32 }
  end


  it "rejects UTF-8 strings longer than 65_535 bytes" do
    big = "x" * 70_000
    assert_raises(M::ProtocolError) { M::Codec::Writer.new.write_utf8(big) }
  end


  it "tracks reader position and remaining bytes" do
    r = M::Codec::Reader.new("abcdef")
    assert_equal 0, r.pos
    assert_equal 6, r.remaining
    r.read(2)
    assert_equal 2, r.pos
    assert_equal 4, r.remaining
    r.read_rest
    assert r.eof?
  end
end
