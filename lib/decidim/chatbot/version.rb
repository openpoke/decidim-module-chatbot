# frozen_string_literal: true

module Decidim
  # This holds the decidim-chatbot version.
  module Chatbot
    DECIDIM_VERSION = "0.31.0"
    COMPAT_DECIDIM_VERSION = [">= 0.31.0", "< 0.32"].freeze
    VERSION = "0.1.0"

    def self.version
      VERSION
    end
  end
end
