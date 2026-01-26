# frozen_string_literal: true

module Decidim
  module Chatbot
    class ProvidersManifest
      include ActiveModel::Model
      include Decidim::AttributeObject::Model

      attribute :name, Symbol
      attribute :adapter_class, String
      attribute :icon, String, default: "chat-1-line"

      def adapter
        adapter_class.safe_constantize
      end

      def public_name_key
        "decidim.chatbot.providers.#{name}.name"
      end

      def description_key
        "decidim.chatbot.providers.#{name}.description"
      end
    end
  end
end
