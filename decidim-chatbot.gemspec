# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/chatbot/version"

Gem::Specification.new do |s|
  s.version = Decidim::Chatbot.version
  s.authors = ["Ivan Vergés"]
  s.email = ["ivan@pokecode.net"]
  s.license = "AGPL-3.0-or-later"
  s.homepage = "https://decidim.org"
  s.metadata = {
    "bug_tracker_uri" => "https://github.com/openpoke/decidim-module-chatbot/issues",
    "documentation_uri" => "https://docs.decidim.org/",
    "funding_uri" => "https://opencollective.com/decidim",
    "homepage_uri" => "https://decidim.org",
    "source_code_uri" => "https://github.com/openpoke/decidim-module-chatbot"
  }
  s.required_ruby_version = "~> 3.3"

  s.name = "decidim-chatbot"
  s.summary = "A Decidim Chatbot module"
  s.description = "Chatbot for integrating Decidim participation in popular chat applications (ie: Whatsapp)."

  s.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").select do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w(app/ config/ db/ lib/ LICENSE-AGPLv3.txt Rakefile README.md))
    end
  end

  s.add_dependency "decidim-core", Decidim::Chatbot::COMPAT_DECIDIM_VERSION
  s.add_dependency "faraday", "> 2.0"
end
