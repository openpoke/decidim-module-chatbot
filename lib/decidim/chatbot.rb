# frozen_string_literal: true

require "decidim/chatbot/admin"
require "decidim/chatbot/engine"
require "decidim/chatbot/admin_engine"

module Decidim
  # This namespace holds the logic of the `Chatbot` module.
  module Chatbot
    autoload :ProvidersManifest, "decidim/chatbot/providers_manifest"
    autoload :StartWorkflowsManifest, "decidim/chatbot/start_workflows_manifest"

    include ActiveSupport::Configurable

    config_accessor :whatsapp_config do
      {
        verify_token: Decidim::Env.new("WHATSAPP_VERIFY_TOKEN").value,
        access_token: Decidim::Env.new("WHATSAPP_ACCESS_TOKEN").value,
        graph_api_url: Decidim::Env.new("WHATSAPP_GRAPH_API_URL", "https://graph.facebook.com/v24.0/").value
      }
    end

    # Timeout (minutes) for clearing workflows after inactivity.
    # This is to prevent workflows from being left open indefinitely if the user stops responding.
    config_accessor :workflow_clear_timeout do
      Decidim::Env.new("CHATBOT_WORKFLOW_CLEAR_TIMEOUT", 30).to_i.minutes
    end

    # Message sent to users when the chatbot is not configured or enabled.
    # return nil if you want to disable this message and just ignore incoming messages when the chatbot is not enabled.
    config_accessor :deactivated_message do
      Decidim::Env.new("CHATBOT_DEACTIVATED_MESSAGE", "decidim.chatbot.messages.deactivated").value
    end

    def self.start_workflows_registry
      @start_workflows_registry ||= ManifestRegistry.new("chatbot/start_workflows")
    end

    def self.providers_registry
      @providers_registry ||= ManifestRegistry.new("chatbot/providers")
    end
  end
end
