# frozen_string_literal: true

module Decidim
  module Chatbot
    class StartWorkflowsManifest
      include ActiveModel::Model
      include Decidim::AttributeObject::Model

      attribute :name, Symbol
      attribute :workflow_class, String
      attribute :title, String

      def workflow
        workflow_class.safe_constantize
      end
    end
  end
end
