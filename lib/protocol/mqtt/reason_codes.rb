# frozen_string_literal: true

module Protocol
  module MQTT
    # MQTT v5 reason codes (§2.4). Most v5 packets carry one. A v3.1.1
    # return code table is included for CONNACK translation.
    module ReasonCodes
      # Used by: all v5 packets
      SUCCESS                               = 0x00
      NORMAL_DISCONNECTION                  = 0x00
      GRANTED_QOS_0                         = 0x00
      GRANTED_QOS_1                         = 0x01
      GRANTED_QOS_2                         = 0x02
      DISCONNECT_WITH_WILL_MESSAGE          = 0x04
      NO_MATCHING_SUBSCRIBERS               = 0x10
      NO_SUBSCRIPTION_EXISTED               = 0x11
      CONTINUE_AUTHENTICATION               = 0x18
      REAUTHENTICATE                        = 0x19
      UNSPECIFIED_ERROR                     = 0x80
      MALFORMED_PACKET                      = 0x81
      PROTOCOL_ERROR                        = 0x82
      IMPLEMENTATION_SPECIFIC_ERROR         = 0x83
      UNSUPPORTED_PROTOCOL_VERSION          = 0x84
      CLIENT_IDENTIFIER_NOT_VALID           = 0x85
      BAD_USER_NAME_OR_PASSWORD             = 0x86
      NOT_AUTHORIZED                        = 0x87
      SERVER_UNAVAILABLE                    = 0x88
      SERVER_BUSY                           = 0x89
      BANNED                                = 0x8A
      SERVER_SHUTTING_DOWN                  = 0x8B
      BAD_AUTHENTICATION_METHOD             = 0x8C
      KEEP_ALIVE_TIMEOUT                    = 0x8D
      SESSION_TAKEN_OVER                    = 0x8E
      TOPIC_FILTER_INVALID                  = 0x8F
      TOPIC_NAME_INVALID                    = 0x90
      PACKET_IDENTIFIER_IN_USE              = 0x91
      PACKET_IDENTIFIER_NOT_FOUND           = 0x92
      RECEIVE_MAXIMUM_EXCEEDED              = 0x93
      TOPIC_ALIAS_INVALID                   = 0x94
      PACKET_TOO_LARGE                      = 0x95
      MESSAGE_RATE_TOO_HIGH                 = 0x96
      QUOTA_EXCEEDED                        = 0x97
      ADMINISTRATIVE_ACTION                 = 0x98
      PAYLOAD_FORMAT_INVALID                = 0x99
      RETAIN_NOT_SUPPORTED                  = 0x9A
      QOS_NOT_SUPPORTED                     = 0x9B
      USE_ANOTHER_SERVER                    = 0x9C
      SERVER_MOVED                          = 0x9D
      SHARED_SUBSCRIPTIONS_NOT_SUPPORTED    = 0x9E
      CONNECTION_RATE_EXCEEDED              = 0x9F
      MAXIMUM_CONNECT_TIME                  = 0xA0
      SUBSCRIPTION_IDENTIFIERS_NOT_SUPPORTED = 0xA1
      WILDCARD_SUBSCRIPTIONS_NOT_SUPPORTED  = 0xA2

      # v3.1.1 CONNACK return codes (§3.2.2.3)
      module V3Connack
        ACCEPTED                      = 0x00
        UNACCEPTABLE_PROTOCOL_VERSION = 0x01
        IDENTIFIER_REJECTED           = 0x02
        SERVER_UNAVAILABLE            = 0x03
        BAD_USER_NAME_OR_PASSWORD     = 0x04
        NOT_AUTHORIZED                = 0x05
      end

      # v3.1.1 SUBACK codes (§3.9.3)
      module V3Suback
        MAX_QOS_0 = 0x00
        MAX_QOS_1 = 0x01
        MAX_QOS_2 = 0x02
        FAILURE   = 0x80
      end

      # Maps v3.1.1 CONNACK return code → v5 reason code, best-effort.
      V3_CONNACK_TO_V5 = {
        V3Connack::ACCEPTED                      => SUCCESS,
        V3Connack::UNACCEPTABLE_PROTOCOL_VERSION => UNSUPPORTED_PROTOCOL_VERSION,
        V3Connack::IDENTIFIER_REJECTED           => CLIENT_IDENTIFIER_NOT_VALID,
        V3Connack::SERVER_UNAVAILABLE            => SERVER_UNAVAILABLE,
        V3Connack::BAD_USER_NAME_OR_PASSWORD     => BAD_USER_NAME_OR_PASSWORD,
        V3Connack::NOT_AUTHORIZED                => NOT_AUTHORIZED,
      }.freeze
    end
  end
end
