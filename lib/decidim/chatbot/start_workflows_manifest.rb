# frozen_string_literal: true

module Decidim
  module Chatbot
    class StartWorkflowsManifest
      include ActiveModel::Model
      include Decidim::AttributeObject::Model

      attribute :name, Symbol
      attribute :workflow_class, String
      attribute :settings_partial, String
      attribute :settings_attributes, Hash, default: {}

      def workflow
        workflow_class.safe_constantize
      end

      def title
        I18n.t("decidim.chatbot.workflows.#{name}.title")
      end

      # Whether the workflow has custom settings to configure
      def configurable?
        settings_partial.present?
      end

      # Returns the list of allowed config keys declared in settings_attributes
      def config_keys
        settings_attributes.keys.map(&:to_s)
      end
    end
  end
end
