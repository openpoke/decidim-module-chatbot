# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        class Adapter < Decidim::Chatbot::Providers::BaseAdapter
          # TODO: verify certificate https://developers.facebook.com/docs/graph-api/webhooks/getting-started/#mtls-for-webhooks
          def verify!
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

          def build_message(data:, to: nil, type: :text)
            envelope = Envelopes.const_get(type.to_s.camelize)

            envelope.new(to:, data:)
          end

          def received_message
            @received_message ||= MessageNormalizer.new(params)
          end

          def consume_message
            params.delete("entry")
            params.delete("object")
          end

          def mark_as_read!(message)
            read_receipt = build_message(
              type: :read_receipt,
              data: {
                message_id: message.message_id
              }
            )
            send!(read_receipt)
          end

          def send!(message)
            Rails.logger.info("Sending Whatsapp message: #{message.body.inspect}")
            url = "#{Decidim::Chatbot.whatsapp_config[:graph_api_url]}#{received_message.phone_number_id}/messages"
            Faraday.post("#{url}?access_token=#{Decidim::Chatbot.whatsapp_config[:access_token]}") do |req|
              req.headers["Content-Type"] = "application/json"
              req.body = message.body.to_json
            end
          end
        end
      end
    end
  end
end
