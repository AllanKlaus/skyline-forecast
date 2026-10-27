module ForecastHelpers
  ADDRESS = "1600 Amphitheatre Parkway, Mountain View, CA 94043".freeze
  ZIP_CODE = "94043".freeze
end

RSpec.configure do |config|
  config.include ForecastHelpers
end
