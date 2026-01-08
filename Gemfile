# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

# Inside the development app, the relative require has to be one level up, as
# the Gemfile is copied to the development_app folder (almost) as-is.
base_path = ""
base_path = "../" if File.basename(__dir__) == "development_app"
require_relative "#{base_path}lib/decidim/chatbot/version"

DECIDIM_VERSION = Decidim::Chatbot::DECIDIM_VERSION

gem "bootsnap", "~> 1.7"
gem "decidim", DECIDIM_VERSION
gem "decidim-chatbot", path: "."
gem "puma", ">= 6.3.1"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri
  gem "decidim-dev", DECIDIM_VERSION

  gem "brakeman", "~> 6.1"
end

group :development do
  gem "letter_opener_web"
  gem "web-console"
end
