# frozen_string_literal: true

module Decidim
  module Chatbot
    class ProvidersManifest
      include ActiveModel::Model
      include Decidim::AttributeObject::Model

      attribute :name, Symbol
      attribute :adapter_class, String

      def adapter
        adapter_class.safe_constantize
      end
    end
  end
end
