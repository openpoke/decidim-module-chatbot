# frozen_string_literal: true

module Decidim
  module Chatbot
    class Sender < ApplicationRecord
      belongs_to :setting, class_name: "Decidim::Chatbot::Setting"
      belongs_to :decidim_user, class_name: "Decidim::User", optional: true

      def current_workflow
        current_workflow_class&.safe_constantize || setting.workflow
      end

      def parent_workflow
        parent_workflow_class&.safe_constantize
      end

      def locale
        metadata["locale"].presence || decidim_user&.locale.presence || setting.organization.default_locale
      end

      def current_workflow_options
        metadata["current_workflow_options"].presence || {}
      end

      def parent_workflow_options
        metadata["parent_workflow_options"].presence || {}
      end

      def set_workflows!(current_workflow_class, parent_workflow_class = nil, **options)
        update!(
          current_workflow_class: current_workflow_class,
          parent_workflow_class: parent_workflow_class,
          metadata: metadata.merge(options)
        )
      end
    end
  end
end
