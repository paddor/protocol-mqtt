# protocol-mqtt — MQTT 3.1.1 + 5.0 wire codec

[![CI](https://github.com/paddor/protocol-mqtt/actions/workflows/ci.yml/badge.svg)](https://github.com/paddor/protocol-mqtt/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/protocol-mqtt?color=e9573f)](https://rubygems.org/gems/protocol-mqtt)
[![License: ISC](https://img.shields.io/badge/License-ISC-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%204.0-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org)

Pure-Ruby MQTT codec. Handles MQTT 3.1.1 (OASIS 2014) and MQTT 5.0
(OASIS 2019) with a single unified packet family, version detected
after CONNECT.

This is the wire layer. For a full async MQTT client and broker built
on top of it, see [zzq](https://github.com/paddor/zzq).

Status: pre-alpha. See [the design plan](../../.claude/plans/omq-and-nnq-s-design-robust-dolphin.md) for scope.

## What's inside

- `Protocol::MQTT::VBI` — variable byte integer encode/decode (1–4 bytes).
- `Protocol::MQTT::Codec` — primitives: `u8`/`u16`/`u32`, UTF-8 string, binary data, string pair.
- `Protocol::MQTT::Property` — v5 property identifier table, encode/decode.
- `Protocol::MQTT::ReasonCodes` — full v5 reason-code taxonomy + v3.1.1 return-code bridge.
- `Protocol::MQTT::Packet` — base class + one subclass per packet type (CONNECT, CONNACK, PUBLISH, PUBACK, PUBREC, PUBREL, PUBCOMP, SUBSCRIBE, SUBACK, UNSUBSCRIBE, UNSUBACK, PINGREQ, PINGRESP, DISCONNECT, AUTH).
- `Protocol::MQTT::Connection` — wraps an `IO::Stream`; `#read_packet` and `#write_packet`. Version-aware after first CONNECT.

## License

ISC. See [LICENSE](LICENSE).
