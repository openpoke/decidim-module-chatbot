# frozen_string_literal: true

module Decidim
  module Chatbot
    class Setting < ApplicationRecord
      belongs_to :organization, class_name: "Decidim::Organization", foreign_key: :decidim_organization_id
      has_many :users, class_name: "Decidim::Chatbot::User", dependent: :destroy
      has_many :messages, class_name: "Decidim::Chatbot::Message", dependent: :destroy

      def adapter_manifest
        @adapter_manifest ||= Decidim::Chatbot.providers_registry.find(provider.to_sym)
      end

      def workflow
        @workflow ||= Decidim::Chatbot.start_workflows_registry.find(start_workflow.to_sym).workflow
      end
    end
  end
end
