source "https://rubygems.org"

ruby "~> 4.0.0"

gem "bootsnap", require: false
gem "faraday"
gem "puma", ">= 5.0"
gem "rails", "~> 8.1.4"
gem "redis"
gem "sqlite3", ">= 2.1"

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "flog", require: false
  gem "reek", require: false
  gem "rspec-rails"
  gem "rubocop-rails", require: false
  gem "vcr"
  gem "webmock"
end
