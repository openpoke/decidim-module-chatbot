# frozen_string_literal: true

module Decidim
  module Chatbot
    module Whatsapp
      class Processor < Decidim::Chatbot::BaseProcessor
        attr_reader :json

        def verify
          mode = params["hub.mode"]
          token = params["hub.verify_token"]
          challenge = params["hub.challenge"]

          expected_token = Decidim::Chatbot.config.whatsapp_verify_token

          if mode == "subscribe" && token == expected_token
            {
              status: :ok,
              response: challenge
            }
          else
            {
              status: :forbidden
            }
          end
        end

        def receive(raw_post)
          @json = JSON.parse(raw_post)
          Rails.logger.info("Webhook received from Whatsapp: #{json.inspect}")
          send_whatsapp_message(json)
          { status: :ok }
        end

        private

        def send_whatsapp_message(payload)
          # Extract the sender's phone number from the incoming message
          message_data = payload.dig("entry", 0, "changes", 0, "value")
          return unless message_data

          sender_phone = message_data.dig("messages", 0, "from")
          return unless sender_phone

          # Send acknowledgment message back to the user
          access_token = ENV["WHATSAPP_ACCESS_TOKEN"].to_s
          phone_number_id = message_data.dig("metadata", "phone_number_id")
          return unless access_token.present? && phone_number_id.present?

          url = "#{Decidim::Chatbot.whatsapp_config[:graph_api_url]}#{phone_number_id}/messages"
          body = {
            messaging_product: "whatsapp",
            recipient_type: "individual",
            to: sender_phone,
            type: "text",
            text: {
              body: "received: #{message_data.dig("messages", 0, "text", "body")}"
            }
          }

          Faraday.post("#{url}?access_token=#{access_token}") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = body.to_json
          end
        end
      end
    end
  end
end
