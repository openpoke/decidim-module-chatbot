# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      # BaseNormalizer is responsible for extracting and normalizing message data from the raw payload received from the provider's webhook.
      # Each provider may have a different payload structure, so they should implement their own Normalizer that inherits from BaseNormalizer and implements the necessary logic to extract the relevant information
      # Methods defined here provide default implementations for common checks and might be overridden by specific providers if needed.
      class BaseNormalizer
        attr_accessor :message_data, :from, :from_name, :from_locale, :from_metadata, :message_id, :chat_id, :body, :to, :type, :button_id

        # Determines if the message has enough information to be processed (e.g. has a sender and message ID)
        def acknowledgeable?
          from.present? && message_id.present? && valid_number_id?
        end

        # Determines if the message has a valid phone number ID (for providers that require it)
        def valid_number_id?
          true
        end

        # Determines if the message is a user text message (as opposed to an action or system message)
        def user_text?
          from.present? && body.present? && button_id.nil?
        end

        # Determines if the message is an actionable message (e.g. a button click)
        def actionable?
          from.present? && button_id.present?
        end
      end
    end
  end
end
