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
        graph_api_url: Decidim::Env.new("WHATSAPP_GRAPH_API_URL", "https://graph.facebook.com/v24.0/").value,
        phone_number_id: Decidim::Env.new("WHATSAPP_PHONE_NUMBER_ID").value
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

    # Message sent to users when their workflows are cleared due to inactivity.
    # return nil if you want to disable this message.
    config_accessor :stale_cleared_message do
      Decidim::Env.new("CHATBOT_STALE_CLEARED_MESSAGE", "decidim.chatbot.messages.stale_cleared").value
    end

    config_accessor :reset_workflows_message do
      Decidim::Env.new("CHATBOT_RESET_WORKFLOWS_MESSAGE", "decidim.chatbot.messages.reset_workflows").value
    end

    config_accessor :generic_error_message do
      Decidim::Env.new("CHATBOT_GENERIC_ERROR_MESSAGE", "decidim.chatbot.messages.generic_error").value
    end

    def self.start_workflows_registry
      @start_workflows_registry ||= ManifestRegistry.new("chatbot/start_workflows")
    end

    def self.providers_registry
      @providers_registry ||= ManifestRegistry.new("chatbot/providers")
    end
  end
end
