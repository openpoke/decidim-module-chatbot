# frozen_string_literal: true

module Decidim
  module Chatbot
    module Whatsapp
      class Message
        def initialize(json)
          @json = json
          # Extract the sender's phone number from the incoming message
          @message_data = json.dig("entry", 0, "changes", 0, "value")
          @phone_number_id = message_data.dig("metadata", "phone_number_id")
          @id = json.dig("entry", 0, "id")
          if @message_data
            @from = @message_data.dig("messages", 0, "from")
            @body = @message_data.dig("messages", 0, "text", "body")
            @message_id = @message_data.dig("messages", 0, "id")
          end
        end

        def from_user?
          from.present?
        end

        attr_reader :json, :message_data, :from, :message_id, :id, :body, :phone_number_id
      end
    end
  end
end
