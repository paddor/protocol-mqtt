# frozen_string_literal: true

require "test_helper"
require "stringio"

describe Protocol::MQTT::VBI do
  BOUNDARIES = [0, 1, 127, 128, 16_383, 16_384, 2_097_151, 2_097_152, 268_435_455].freeze


  it "round-trips every 1/2/3/4-byte boundary" do
    BOUNDARIES.each do |v|
      bytes = M::VBI.encode(v)
      assert_equal Encoding::BINARY, bytes.encoding
      assert bytes.frozen?
      assert_equal v, M::VBI.decode(StringIO.new(bytes))
    end
  end


  it "encodes at the expected byte length" do
    assert_equal 1, M::VBI.encode(0).bytesize
    assert_equal 1, M::VBI.encode(127).bytesize
    assert_equal 2, M::VBI.encode(128).bytesize
    assert_equal 2, M::VBI.encode(16_383).bytesize
    assert_equal 3, M::VBI.encode(16_384).bytesize
    assert_equal 3, M::VBI.encode(2_097_151).bytesize
    assert_equal 4, M::VBI.encode(2_097_152).bytesize
    assert_equal 4, M::VBI.encode(M::VBI::MAX).bytesize
  end


  it "rejects out-of-range values" do
    assert_raises(ArgumentError) { M::VBI.encode(-1) }
    assert_raises(ArgumentError) { M::VBI.encode(M::VBI::MAX + 1) }
  end


  it "rejects a five-byte continuation sequence" do
    io = StringIO.new([0x80, 0x80, 0x80, 0x80, 0x01].pack("C*"))
    assert_raises(M::MalformedPacket) { M::VBI.decode(io) }
  end


  it "rejects a truncated continuation" do
    io = StringIO.new([0x80].pack("C*"))
    assert_raises(M::MalformedPacket) { M::VBI.decode(io) }
  end


  it "matches the §1.5.5 reference encodings" do
    assert_equal "\x00".b,              M::VBI.encode(0)
    assert_equal "\x7F".b,              M::VBI.encode(127)
    assert_equal "\x80\x01".b,          M::VBI.encode(128)
    assert_equal "\xFF\x7F".b,          M::VBI.encode(16_383)
    assert_equal "\x80\x80\x01".b,      M::VBI.encode(16_384)
    assert_equal "\xFF\xFF\x7F".b,      M::VBI.encode(2_097_151)
    assert_equal "\x80\x80\x80\x01".b,  M::VBI.encode(2_097_152)
    assert_equal "\xFF\xFF\xFF\x7F".b,  M::VBI.encode(M::VBI::MAX)
  end
end
