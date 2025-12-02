# frozen_string_literal: true

require "rails"
require "decidim/core"

module Decidim
  module Chatbot
    # This is the engine that runs on the public interface of Chatbot.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Chatbot

      routes do
        # Add engine routes here
        # resources :Chatbot
        # root to: "Chatbot#index"
      end

      initializer "Chatbot.shakapacker.assets_path" do
        Decidim.register_assets_path File.expand_path("app/packs", root)
      end

      initializer "Chatbot.data_migrate", after: "decidim_core.data_migrate" do
        DataMigrate.configure do |config|
          config.data_migrations_path << root.join("db/data").to_s
        end
      end
    end
  end
end
