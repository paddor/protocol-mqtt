# Changelog

## v0.1.1 — 2026-04-22

- Load packet subclasses from `protocol/mqtt.rb` (the entry point)
  instead of from the bottom of `packet.rb`. Each subclass's
  `require_relative "../packet"` no longer triggers the
  "loading in progress, circular require considered harmful"
  warning on load. Pure refactor; no behavior change.

## v0.1.0 — 2026-04-20

- First release. Pure-Ruby codec and connection layer for MQTT
  3.1.1 and 5.0, extracted for reuse across client and broker
  implementations.
- Packet types: CONNECT/CONNACK, PUBLISH/PUBACK/PUBREC/PUBREL/
  PUBCOMP, SUBSCRIBE/SUBACK, UNSUBSCRIBE/UNSUBACK, PINGREQ/
  PINGRESP, DISCONNECT, AUTH (v5).
- Variable Byte Integer (VBI) encoding, v5 properties, and the
  full v5 reason-code set.
- `Protocol::MQTT::Connection` state machine — transport-agnostic,
  drives reads and writes off an `IO::Stream`-compatible duplex.
