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
    end
  end
end
