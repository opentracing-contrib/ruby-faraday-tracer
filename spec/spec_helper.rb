require 'bundler/setup'
require 'test/tracer'
require 'tracing/matchers'
require 'faraday/tracer'

require 'support/test-tracer'
require 'support/hash'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
