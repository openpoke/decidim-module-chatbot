# frozen_string_literal: true

require "rails"
require "decidim/core"

module Decidim
  module Chatbot
    # This is the engine that runs on the public interface of Chatbot.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Chatbot

      routes do
        scope :webhooks do
          get ":provider", to: "webhooks#verify", as: :verify_webhook
          post ":provider", to: "webhooks#receive", as: :receive_webhook
        end
      end

      initializer "decidim-chatbot.admin_mount_routes" do
        Decidim::Core::Engine.routes do
          mount Decidim::Chatbot::Engine, at: "/chatbot", as: "decidim_chatbot"
        end
      end

      initializer "decidim-chatbot.default_workflows" do
        # Register workflows available for starting chatbot conversations
        Decidim::Chatbot.start_workflows_registry.register(:organization_welcome) do |manifest|
          manifest.workflow_class = "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow"
        end
        Decidim::Chatbot.start_workflows_registry.register(:participatory_space) do |manifest|
          manifest.workflow_class = "Decidim::Chatbot::Workflows::ParticipatorySpaceWorkflow"
        end
      end

      initializer "decidim-chatbot.default_providers" do
        Decidim::Chatbot.providers_registry.register(:whatsapp) do |manifest|
          manifest.adapter_class = "Decidim::Chatbot::Providers::Whatsapp::Adapter"
        end
      end

      initializer "decidim-chatbot.shakapacker.assets_path" do
        Decidim.register_assets_path File.expand_path("app/packs", root)
      end

      initializer "decidim-chatbot.data_migrate", after: "decidim_core.data_migrate" do
        DataMigrate.configure do |config|
          config.data_migrations_path << root.join("db/data").to_s
        end
      end
    end
  end
end
