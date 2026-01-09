# frozen_string_literal: true

module Decidim
  module Chatbot
    module Whatsapp
      class Processor < Decidim::Chatbot::BaseProcessor
        attr_reader :json, :message

        # TODO: verify certificate https://developers.facebook.com/docs/graph-api/webhooks/getting-started/#mtls-for-webhooks
        def verify
          mode = params["hub.mode"]
          token = params["hub.verify_token"]
          challenge = params["hub.challenge"]
          Rails.logger.info("Verifying Whatsapp webhook with mode: #{params.inspect}")

          if mode == "subscribe" && token == Decidim::Chatbot.whatsapp_config[:verify_token]
            { status: :ok, response: challenge }
          else
            { status: :forbidden }
          end
        end

        def receive(raw_post)
          @json = JSON.parse(raw_post)
          @message = Message.new(json)

          Rails.logger.info("Webhook received from Whatsapp: #{json.inspect}")

          send_whatsapp_message if message.from_user?
          { status: :ok }
        end

        private

        def send_whatsapp_message
          # Send acknowledgment message back to the user

          body = {
            messaging_product: "whatsapp",
            recipient_type: "individual",
            to: message.from,
            type: "text",
            text: {
              body: "Received: #{message.body}"
            }
          }

          url = "#{Decidim::Chatbot.whatsapp_config[:graph_api_url]}#{message.phone_number_id}/messages"
          Faraday.post("#{url}?access_token=#{Decidim::Chatbot.whatsapp_config[:access_token]}") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = body.to_json
          end
        end
      end
    end
  end
end
