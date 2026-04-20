# frozen_string_literal: true

require "test_helper"
require "stringio"

# Minimal IO with the surface Connection needs. StringIO supports
# #read, #write, #close, and #flush (no-op).
class BufIO < StringIO
  def read_exactly(n)
    chunk = read(n)
    raise EOFError if chunk.nil? || chunk.bytesize < n
    chunk
  end
end

describe Protocol::MQTT::Connection do
  it "round-trips a stream of packets on v3" do
    io = BufIO.new("".b)
    tx = M::Connection.new(io, version: 3)
    tx.write_packet(M::Packet::Pingreq.new)
    tx.write_packet(M::Packet::Publish.new(topic: "a/b", payload: "hi", qos: 1, packet_id: 7))
    tx.write_packet(M::Packet::Disconnect.new)

    io.rewind
    rx = M::Connection.new(io, version: 3)
    assert_equal M::Packet::Pingreq.new, rx.read_packet
    pub = rx.read_packet
    assert_equal "a/b", pub.topic
    assert_equal "hi".b, pub.payload
    assert_equal 1, pub.qos
    assert_equal 7, pub.packet_id
    assert_equal M::Packet::Disconnect.new, rx.read_packet
    assert_nil rx.read_packet  # clean EOF at boundary
  end


  it "round-trips v5 packets carrying properties" do
    pkt = M::Packet::Connack.new(
      session_present: true,
      reason_code: M::ReasonCodes::SUCCESS,
      properties: { receive_maximum: 10, user_property: [["k", "v"]] },
    )
    io = BufIO.new("".b)
    M::Connection.new(io, version: 5).write_packet(pkt)
    io.rewind
    decoded = M::Connection.new(io, version: 5).read_packet
    assert_equal pkt, decoded
  end


  it "allows the version to be switched mid-stream (post-CONNECT)" do
    io = BufIO.new("".b)
    M::Connection.new(io, version: 5).write_packet(
      M::Packet::Connect.new(client_id: "c1", properties: { session_expiry_interval: 60 }),
    )
    io.rewind
    rx = M::Connection.new(io)  # default version 3, will flip
    rx.version = 5
    pkt = rx.read_packet
    assert_equal "c1", pkt.client_id
    assert_equal 60, pkt.properties[:session_expiry_interval]
  end


  it "read_connect_packet auto-detects v5 and sets version=5" do
    io = BufIO.new("".b)
    M::Connection.new(io, version: 5).write_packet(
      M::Packet::Connect.new(client_id: "c1", properties: { session_expiry_interval: 60 }),
    )
    io.rewind
    rx = M::Connection.new(io)  # default v3
    pkt = rx.read_connect_packet
    assert_equal 5, rx.version
    assert_equal "c1", pkt.client_id
    assert_equal 60, pkt.properties[:session_expiry_interval]
  end


  it "read_connect_packet auto-detects v3 and sets version=3" do
    io = BufIO.new("".b)
    M::Connection.new(io, version: 3).write_packet(M::Packet::Connect.new(client_id: "c1"))
    io.rewind
    rx = M::Connection.new(io, version: 5)  # start v5, should flip to 3
    pkt = rx.read_connect_packet
    assert_equal 3, rx.version
    assert_equal "c1", pkt.client_id
  end


  it "read_connect_packet raises when first packet isn't CONNECT" do
    io = BufIO.new("".b)
    M::Connection.new(io, version: 3).write_packet(M::Packet::Pingreq.new)
    io.rewind
    rx = M::Connection.new(io)
    assert_raises(M::MalformedPacket) { rx.read_connect_packet }
  end


  it "raises MalformedPacket when a packet is truncated" do
    # fixed header says 10 bytes body but only 3 present
    io = BufIO.new("\xC0\x0Aabc".b)
    rx = M::Connection.new(io)
    assert_raises(M::MalformedPacket) { rx.read_packet }
  end


  it "returns nil on clean EOF" do
    rx = M::Connection.new(BufIO.new("".b))
    assert_nil rx.read_packet
  end


  it "raises MalformedPacket on an unknown packet type" do
    # type 0, remaining length 0 — type 0 is not registered
    io = BufIO.new("\x00\x00".b)
    rx = M::Connection.new(io)
    assert_raises(M::MalformedPacket) { rx.read_packet }
  end


  it "enforces max_packet_size" do
    io = BufIO.new("".b)
    M::Connection.new(io, version: 3).write_packet(
      M::Packet::Publish.new(topic: "t", payload: "x" * 500),
    )
    io.rewind
    rx = M::Connection.new(io, version: 3, max_packet_size: 100)
    assert_raises(M::MalformedPacket) { rx.read_packet }
  end


  it "raises ClosedError when writing after close" do
    rx = M::Connection.new(BufIO.new("".b))
    rx.close
    assert rx.closed?
    assert_raises(M::ClosedError) { rx.write_packet(M::Packet::Pingreq.new) }
  end


  it "handles remaining-length encoded as a 3-byte VBI" do
    payload = "x" * 16_384
    io = BufIO.new("".b)
    M::Connection.new(io, version: 3).write_packet(
      M::Packet::Publish.new(topic: "t", payload: payload),
    )
    io.rewind
    pkt = M::Connection.new(io, version: 3).read_packet
    assert_equal payload.bytesize, pkt.payload.bytesize
  end


  it "rejects a remaining-length VBI exceeding 4 bytes" do
    # Send 5 continuation bytes
    io = BufIO.new("\xC0\x80\x80\x80\x80\x01".b)
    rx = M::Connection.new(io)
    assert_raises(M::MalformedPacket) { rx.read_packet }
  end
end
