# frozen_string_literal: true

require "test_helper"

describe Protocol::MQTT do
  it "has a version" do
    refute_nil Protocol::MQTT::VERSION
  end
end
