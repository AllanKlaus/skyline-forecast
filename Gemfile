source "https://rubygems.org"

ruby "~> 4.0.0"

gem "rails", "~> 8.1.4"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "faraday"
gem "redis"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails", require: false
  gem "rspec-rails"
  gem "vcr"
  gem "webmock"
end
