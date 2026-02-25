# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        class MessageNormalizer < BaseNormalizer
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
            if @type == "interactive"
              # Extract interactive message details
              interactive = @message_data.dig("messages", 0, "interactive")
              if interactive["type"] == "button_reply"
                @body = interactive.dig("button_reply", "title")
                @button_id = interactive.dig("button_reply", "id")
              elsif interactive["type"] == "list_reply"
                @body = interactive.dig("list_reply", "title")
                @button_id = interactive.dig("list_reply", "id")
              end
            elsif @type == "button"
              button = @message_data.dig("messages", 0, "button")
              @body = button&.dig("text")
              @button_id = button&.dig("payload")
            end
          end

          def valid_number_id?
            configured_phone_number_id = Decidim::Chatbot.whatsapp_config[:phone_number_id]
            configured_phone_number_id.present? && phone_number_id.to_s == configured_phone_number_id.to_s
          end

          def user_text?
            from.present? && type == "text"
          end

          attr_reader :json, :phone_number_id
        end
      end
    end
  end
end
