# frozen_string_literal: true

require "minitest/autorun"
require "protocol/mqtt"

Warning[:experimental] = false

# Shorthand used throughout the spec files. `describe` blocks in
# Minitest::Spec class_eval bodies don't participate in lexical
# Module.nesting, so `include Protocol::MQTT` inside them doesn't
# surface constants. A top-level alias keeps call sites readable.
M = Protocol::MQTT
