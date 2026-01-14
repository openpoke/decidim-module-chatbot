# frozen_string_literal: true

module Decidim
  module Chatbot
    class Message < ApplicationRecord
      belongs_to :setting, class_name: "Decidim::Chatbot::Setting"
      belongs_to :user, class_name: "Decidim::Chatbot::User"

      def self.from_normalized(normalized_message)
        setting = Decidim::Chatbot::Setting.find_by(organization: normalized_message.organization)
        return nil unless setting

        setting.messages.find_or_initialize_by(message_id: normalized_message.message_id) do |message|
          message.user = setting.users.find_or_initialize_by(external_id: normalized_message.user_external_id)
          message.content = normalized_message.content
          message.message_type = normalized_message.message_type
          message.button_id = normalized_message.button_id
        end
      end
    end
  end
end
