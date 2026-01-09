# frozen_string_literal: true

require "decidim/chatbot/admin"
require "decidim/chatbot/engine"
require "decidim/chatbot/admin_engine"

module Decidim
  # This namespace holds the logic of the `Chatbot` component. This component
  # allows users to create Chatbot in a participatory space.
  module Chatbot
    autoload :ProvidersManifest, "decidim/chatbot/providers_manifest"

    include ActiveSupport::Configurable

    config_accessor :provider do
      Decidim::Env.new("CHATBOT_PROVIDER").presence || "whatsapp"
    end

    config_accessor :whatsapp_config do
      {
        verify_token: Decidim::Env.new("WHATSAPP_VERIFY_TOKEN").value,
        access_token: Decidim::Env.new("WHATSAPP_ACCESS_TOKEN").value,
        graph_api_url: Decidim::Env.new("WHATSAPP_GRAPH_API_URL", "https://graph.facebook.com/v24.0/").value
      }
    end

    # Public: Stores the registry of components
    def self.providers_registry
      @providers_registry ||= ManifestRegistry.new("chatbot/providers")
    end
  end
end
