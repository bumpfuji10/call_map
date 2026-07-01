# frozen_string_literal: true

require_relative "call_map/version"
require_relative "call_map/definition"
require_relative "call_map/definition_collector"
require_relative "call_map/source_index"
require_relative "call_map/method_call"
require_relative "call_map/call_extractor"

module CallMap
  class Error < StandardError; end
  # Your code goes here...
end
