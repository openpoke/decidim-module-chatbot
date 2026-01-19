# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      class BaseNormalizer
        attr_accessor :message_data, :from, :from_name, :from_locale, :from_metadata, :message_id, :chat_id, :body, :to, :type, :button_id

        def acknowledgeable?
          from.present? && message_id.present?
        end

        def user_text?
          from.present? && body.present? && button_id.nil?
        end

        def actionable?
          from.present? && button_id.present?
        end
      end
    end
  end
end
