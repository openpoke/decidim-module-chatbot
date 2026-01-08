# frozen_string_literal: true

module Decidim
  module Chatbot
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /chatbot/webhooks/:provider
      # Used by some providers (e.g., WhatsApp) to verify the endpoint
      def verify
        provider = params[:provider].to_s
        return head :bad_request unless supported_provider?(provider)

        # todo: use manifests to register providers and their verification logic
        case provider
        when "whatsapp"
          verify_token = ENV["WHATSAPP_VERIFY_TOKEN"].to_s
          mode = params["hub.mode"].to_s
          token = params["hub.verify_token"].to_s
          challenge = params["hub.challenge"].to_s

          if mode == "subscribe" && token.present? && ActiveSupport::SecurityUtils.secure_compare(token, verify_token)
            render plain: challenge, status: :ok
          else
            head :forbidden
          end
        else
          head :not_implemented
        end
      end

      # POST /chatbot/webhooks/:provider
      def receive
        provider = params[:provider].to_s
        return head :bad_request unless supported_provider?(provider)

        # NOTE: Add signature verification per provider in the future.
        # For now, accept payload and respond 200 to acknowledge receipt.
        json = JSON.parse(request.raw_post)
        Rails.logger.info("Webhook received from #{provider}: #{json.inspect}")

        case provider
        when "whatsapp"
          send_whatsapp_message(json)
        end

        head :ok
      end

      private

      def supported_provider?(provider)
        %w[whatsapp].include?(provider)
      end

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

        url = "https://graph.facebook.com/v24.0/#{phone_number_id}/messages"
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
