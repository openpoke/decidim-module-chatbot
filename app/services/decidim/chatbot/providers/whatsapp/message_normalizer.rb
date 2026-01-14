# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        class MessageNormalizer
          def initialize(json)
            @json = json
            # Extract the sender's phone number from the incoming message
            @message_data = json.dig("entry", 0, "changes", 0, "value")
            @phone_number_id = @message_data.dig("metadata", "phone_number_id")
            @to = @message_data.dig("metadata", "display_phone_number")
            @from = @message_data.dig("contacts", 0, "wa_id")
            @from_name = @message_data.dig("contacts", 0, "profile", "name")
            @chat_id = json.dig("entry", 0, "id")
            return unless @message_data

            # Extract message details
            @from ||= @message_data.dig("messages", 0, "from")
            @body = @message_data.dig("messages", 0, "text", "body")
            @message_id = @message_data.dig("messages", 0, "id")
            @type = @message_data.dig("messages", 0, "type")
            return unless @type == "interactive"

            # Extract interactive message details
            interactive = @message_data.dig("messages", 0, "interactive")
            if interactive["type"] == "button_reply"
              @body = interactive.dig("button_reply", "title")
              @button_id = interactive.dig("button_reply", "id")
            elsif interactive["type"] == "list_reply"
              @body = interactive.dig("list_reply", "title")
              @button_id = interactive.dig("list_reply", "id")
            end
          end

          def acknowledgeable?
            from.present? && message_id.present?
          end

          def user_text?
            from.present? && type == "text"
          end

          def actionable?
            from.present? && type == "interactive" && button_id.present?
          end

          attr_reader :json, :message_data, :from, :from_name, :from_metadata, :message_id, :chat_id, :body, :phone_number_id, :to, :type, :button_id
        end
      end
    end
  end
end
