require 'simplecov'
SimpleCov.start

RSpec.configure do |config|
  config.order = :random
  config.disable_monkey_patching!
end

require_relative '../lib/is-deep'
