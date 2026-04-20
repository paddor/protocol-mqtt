# frozen_string_literal: true

require "test_helper"

describe Protocol::MQTT::Packet do
  def round_trip(pkt, version:)
    bytes = pkt.encode(version: version)
    assert_equal Encoding::BINARY, bytes.encoding, "encoded packet must be BINARY"
    assert bytes.frozen?, "encoded packet must be frozen"
    decoded, consumed = M::Packet.decode(bytes, version: version)
    assert_equal bytes.bytesize, consumed
    assert_equal pkt, decoded
    decoded
  end


  # ---- pingreq / pingresp / disconnect / auth --------------------------

  it "round-trips PINGREQ across v3 and v5" do
    [3, 5].each { |v| round_trip(M::Packet::Pingreq.new, version: v) }
  end


  it "round-trips PINGRESP across v3 and v5" do
    [3, 5].each { |v| round_trip(M::Packet::Pingresp.new, version: v) }
  end


  it "matches the PINGREQ wire bytes" do
    bytes = M::Packet::Pingreq.new.encode(version: 3)
    assert_equal "\xC0\x00".b, bytes
  end


  it "emits a 2-byte DISCONNECT on v3" do
    bytes = M::Packet::Disconnect.new.encode(version: 3)
    assert_equal "\xE0\x00".b, bytes
  end


  it "emits an empty DISCONNECT on v5 equivalent to normal" do
    round_trip(M::Packet::Disconnect.new, version: 5)
  end


  it "round-trips DISCONNECT with reason and properties (v5)" do
    pkt = M::Packet::Disconnect.new(
      reason_code: M::ReasonCodes::SERVER_SHUTTING_DOWN,
      properties: { reason_string: "bye", user_property: [["k", "v"]] },
    )
    round_trip(pkt, version: 5)
  end


  it "rejects AUTH on v3" do
    assert_raises(M::ProtocolError) { M::Packet::Auth.new.encode(version: 3) }
  end


  it "round-trips AUTH on v5" do
    round_trip(M::Packet::Auth.new, version: 5)
    round_trip(
      M::Packet::Auth.new(
        reason_code: M::ReasonCodes::CONTINUE_AUTHENTICATION,
        properties: { authentication_method: "SCRAM-SHA-256", authentication_data: "data".b },
      ),
      version: 5,
    )
  end


  # ---- puback family ---------------------------------------------------

  [M::Packet::Puback, M::Packet::Pubrec, M::Packet::Pubrel, M::Packet::Pubcomp].each do |klass|
    name = klass.name.split("::").last


    it "round-trips #{name} on v3" do
      round_trip(klass.new(packet_id: 42), version: 3)
    end


    it "encodes the shortest form of #{name} on v5" do
      bytes = klass.new(packet_id: 42).encode(version: 5)
      # shortest form: 2-byte body (packet id only), reason=SUCCESS implied
      assert_equal 4, bytes.bytesize
      round_trip(klass.new(packet_id: 42), version: 5)
    end


    it "round-trips #{name} on v5 with reason only" do
      round_trip(
        klass.new(packet_id: 7, reason_code: M::ReasonCodes::PACKET_IDENTIFIER_NOT_FOUND),
        version: 5,
      )
    end


    it "round-trips #{name} on v5 with properties" do
      round_trip(
        klass.new(
          packet_id: 1,
          reason_code: M::ReasonCodes::UNSPECIFIED_ERROR,
          properties: { reason_string: "oops" },
        ),
        version: 5,
      )
    end
  end


  it "encodes PUBREL with the 0b0010 flags nibble" do
    bytes = M::Packet::Pubrel.new(packet_id: 1).encode(version: 3)
    assert_equal 0x62, bytes.getbyte(0)
  end


  # ---- publish ---------------------------------------------------------

  it "round-trips a QoS 0 PUBLISH on v3" do
    pkt = M::Packet::Publish.new(topic: "a/b", payload: "hi")
    round_trip(pkt, version: 3)
  end


  it "round-trips a QoS 1 PUBLISH on v3" do
    pkt = M::Packet::Publish.new(topic: "a/b", payload: "hi", qos: 1, packet_id: 5)
    round_trip(pkt, version: 3)
  end


  it "round-trips a QoS 2 retain+dup PUBLISH on v5" do
    pkt = M::Packet::Publish.new(
      topic: "a/b", payload: "p", qos: 2, packet_id: 5,
      retain: true, dup: true,
      properties: { content_type: "text/plain", user_property: [["k", "v"]] },
    )
    decoded = round_trip(pkt, version: 5)
    assert decoded.retain
    assert decoded.dup
  end


  it "preserves a BINARY payload byte-for-byte" do
    payload = (0..255).map(&:chr).join.b
    pkt = M::Packet::Publish.new(topic: "a", payload: payload)
    decoded = round_trip(pkt, version: 5)
    assert_equal payload, decoded.payload
    assert_equal Encoding::BINARY, decoded.payload.encoding
  end


  it "builds the PUBLISH flags nibble from qos/retain/dup" do
    pkt = M::Packet::Publish.new(topic: "a", payload: "", qos: 2, packet_id: 1, retain: true, dup: true)
    assert_equal 0b1101, pkt.flags_nibble(5)
  end


  it "rejects a PUBLISH with QoS = 3" do
    bytes = M::Packet::Publish.new(topic: "a", payload: "x", qos: 2, packet_id: 1).encode(version: 3)
    # flip QoS bits to 11
    b0 = bytes.getbyte(0) | 0b0110
    mangled = (+bytes).force_encoding(Encoding::BINARY)
    mangled.setbyte(0, b0)
    assert_raises(M::MalformedPacket) { M::Packet.decode(mangled, version: 3) }
  end


  it "rejects a QoS > 0 PUBLISH with no packet id" do
    assert_raises(ArgumentError) { M::Packet::Publish.new(topic: "a", payload: "x", qos: 1) }
  end


  it "rejects a QoS 0 PUBLISH with a packet id" do
    assert_raises(ArgumentError) { M::Packet::Publish.new(topic: "a", payload: "x", qos: 0, packet_id: 1) }
  end


  # ---- connect / connack ----------------------------------------------

  it "round-trips a minimal CONNECT on v3" do
    round_trip(M::Packet::Connect.new(client_id: "c1"), version: 3)
  end


  it "round-trips a minimal CONNECT on v5" do
    round_trip(M::Packet::Connect.new(client_id: "c1"), version: 5)
  end


  it "round-trips a fully-populated CONNECT on v5" do
    pkt = M::Packet::Connect.new(
      client_id: "c1",
      clean_start: false,
      keep_alive: 30,
      username: "u",
      password: "p".b,
      will: {
        topic: "d/c1",
        payload: "bye".b,
        qos: 1,
        retain: true,
        properties: { will_delay_interval: 10 },
      },
      properties: { session_expiry_interval: 3600, receive_maximum: 100 },
    )
    round_trip(pkt, version: 5)
  end


  it "round-trips a will on v3 without carrying will properties" do
    pkt = M::Packet::Connect.new(
      client_id: "c1",
      will: { topic: "d/c1", payload: "bye".b, qos: 0, retain: false },
    )
    decoded = round_trip(pkt, version: 3)
    assert_equal({}, decoded.will[:properties])  # v3 never carries will properties
  end


  it "round-trips CONNACK on v3" do
    pkt = M::Packet::Connack.new(session_present: false, reason_code: M::ReasonCodes::V3Connack::ACCEPTED)
    round_trip(pkt, version: 3)
  end


  it "round-trips CONNACK on v5 with properties" do
    pkt = M::Packet::Connack.new(
      session_present: true,
      reason_code: M::ReasonCodes::SUCCESS,
      properties: { assigned_client_identifier: "abc", maximum_qos: 1, receive_maximum: 10 },
    )
    round_trip(pkt, version: 5)
  end


  # ---- subscribe / suback ---------------------------------------------

  it "round-trips SUBSCRIBE with a single filter (v3)" do
    pkt = M::Packet::Subscribe.new(packet_id: 1, filters: [{ filter: "a/#", qos: 1 }])
    round_trip(pkt, version: 3)
  end


  it "round-trips SUBSCRIBE with v5 options" do
    pkt = M::Packet::Subscribe.new(
      packet_id: 2,
      filters: [
        { filter: "a/+", qos: 2, no_local: true, retain_as_published: true, retain_handling: 2 },
        { filter: "b", qos: 0 },
      ],
      properties: { subscription_identifier: [17] },
    )
    round_trip(pkt, version: 5)
  end


  it "rejects an empty SUBSCRIBE filter list" do
    assert_raises(ArgumentError) { M::Packet::Subscribe.new(packet_id: 1, filters: []) }
  end


  it "validates the SUBSCRIBE flags nibble" do
    bytes = M::Packet::Subscribe.new(packet_id: 1, filters: [{ filter: "a", qos: 0 }]).encode(version: 3)
    mangled = (+bytes).force_encoding(Encoding::BINARY)
    mangled.setbyte(0, 0x80)  # flags = 0 instead of 0b0010
    assert_raises(M::MalformedPacket) { M::Packet.decode(mangled, version: 3) }
  end


  it "round-trips SUBACK on v3" do
    pkt = M::Packet::Suback.new(
      packet_id: 1,
      reason_codes: [M::ReasonCodes::V3Suback::MAX_QOS_0, M::ReasonCodes::V3Suback::FAILURE],
    )
    round_trip(pkt, version: 3)
  end


  it "round-trips SUBACK on v5" do
    pkt = M::Packet::Suback.new(
      packet_id: 1,
      reason_codes: [M::ReasonCodes::GRANTED_QOS_2, M::ReasonCodes::NOT_AUTHORIZED],
      properties: { reason_string: "ok-ish" },
    )
    round_trip(pkt, version: 5)
  end


  # ---- unsubscribe / unsuback -----------------------------------------

  it "round-trips UNSUBSCRIBE on v3" do
    pkt = M::Packet::Unsubscribe.new(packet_id: 3, filters: ["a", "b/#"])
    round_trip(pkt, version: 3)
  end


  it "round-trips UNSUBSCRIBE on v5" do
    pkt = M::Packet::Unsubscribe.new(
      packet_id: 3,
      filters: ["a", "b/#"],
      properties: { user_property: [["k", "v"]] },
    )
    round_trip(pkt, version: 5)
  end


  it "round-trips UNSUBACK on v3" do
    pkt = M::Packet::Unsuback.new(packet_id: 9)
    round_trip(pkt, version: 3)
  end


  it "round-trips UNSUBACK on v5" do
    pkt = M::Packet::Unsuback.new(
      packet_id: 9,
      reason_codes: [M::ReasonCodes::SUCCESS, M::ReasonCodes::NO_SUBSCRIPTION_EXISTED],
    )
    round_trip(pkt, version: 5)
  end


  # ---- factory errors --------------------------------------------------

  it "rejects an unknown packet type on decode" do
    # type 0 is reserved, not registered
    bytes = "\x00\x00".b
    assert_raises(M::MalformedPacket) { M::Packet.decode(bytes, version: 3) }
  end


  it "rejects a truncated packet on decode" do
    assert_raises(M::MalformedPacket) { M::Packet.decode("\xC0\x05".b, version: 3) }
  end
end
