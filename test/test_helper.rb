# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "nextgen"

# Explicitly require generators since they're ignored by Zeitwerk
require "nextgen/generators/multi_tenancy_generator"

require "minitest"
require "webmock/minitest"
require "minitest/autorun"
