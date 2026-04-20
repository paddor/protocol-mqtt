# frozen_string_literal: true

module Protocol
  module MQTT
    class Error < StandardError
    end


    class MalformedPacket < Error
    end


    class ProtocolError < Error
    end


    # Raised on attempts to write to a Connection after #close.
    class ClosedError < Error
    end
  end
end
