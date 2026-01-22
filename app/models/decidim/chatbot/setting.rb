# frozen_string_literal: true

module Decidim
  module Chatbot
    class Setting < ApplicationRecord
      belongs_to :organization, class_name: "Decidim::Organization", foreign_key: :decidim_organization_id
      has_many :senders, class_name: "Decidim::Chatbot::Sender", dependent: :destroy
      has_many :messages, class_name: "Decidim::Chatbot::Message", dependent: :destroy

      validates :provider, presence: true, uniqueness: { scope: :decidim_organization_id }

      def adapter_manifest
        @adapter_manifest ||= Decidim::Chatbot.providers_registry.find(provider.to_sym)
      end

      def workflow
        @workflow ||= Decidim::Chatbot.start_workflows_registry.find(start_workflow.to_sym).workflow
      end

      def enabled?
        configuration[:enabled] == true
      end

      def participatory_space
        return @participatory_space if defined?(@participatory_space)

        @participatory_space = find_participatory_space
      end

      def selected_component
        return @selected_component if defined?(@selected_component)

        @selected_component = find_selected_component
      end

      def write_action
        configuration[:write_action]
      end

      def toggle_enabled!
        self.config = (config || {}).merge("enabled" => !enabled?)
        save!
        reset_memoization!
        enabled?
      end

      def reset_memoization!
        @configuration = nil
        @participatory_space = nil
        @selected_component = nil
      end

      private

      def configuration
        @configuration ||= (config || {}).with_indifferent_access
      end

      def find_participatory_space
        type = configuration[:participatory_space_type]
        id = configuration[:participatory_space_id]
        return nil if type.blank? || id.blank?

        klass = type.safe_constantize
        klass&.find_by(id: id)
      end

      def find_selected_component
        return nil unless participatory_space && configuration[:component_id].present?

        participatory_space.components.find_by(id: configuration[:component_id])
      end
    end
  end
end
