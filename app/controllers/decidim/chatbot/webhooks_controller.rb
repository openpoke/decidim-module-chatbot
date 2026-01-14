# frozen_string_literal: true

module Decidim
  module Chatbot
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token

      before_action do
        render json: { error: "Provider [#{provider}] not supported" }, status: :bad_request unless setting&.adapter_manifest
      end

      # GET /chatbot/webhooks/:provider
      # Used by some providers (e.g., WhatsApp) to verify the endpoint
      def verify
        result = workflow.adapter.verify!

        if result.present?
          render plain: result, status: :ok
        else
          head :forbidden
        end
      end

      # POST /chatbot/webhooks/:provider
      def receive
        begin
          if sender.nil?
            # These message include control messages like read receipts, etc.
            # We log them but don't process further. This might be changed in the future.
            Rails.logger.warn("Received message from unknown sender: #{received_message.from}")
          elsif message.nil?
            Rails.logger.warn("Received message with no ID: #{message.inspect}")
          else
            Rails.logger.info("Processing webhook for provider #{provider}, organization #{setting.organization.id}, sender #{sender.id} with workflow #{sender.current_workflow}")
            sender.current_workflow.new(adapter:, message:).start
          end
        rescue StandardError => e
          Rails.logger.error("Error processing webhook for provider #{provider}: #{e.message}\n#{e.backtrace.join("\n")}")
        end
        # always respond with 200 OK to avoid repeated webhook calls (this might be changed in the future depending on provider requirements)
        head :ok
      end

      private

      delegate :received_message, to: :adapter

      def provider
        params[:provider].to_s
      end

      def setting
        @setting ||= Decidim::Chatbot::Setting.find_by(organization: current_organization, provider:)
      end

      def adapter
        @adapter ||= setting.adapter_manifest.adapter.new(params:)
      end

      def sender
        return nil if received_message.from.blank?

        @sender ||= setting.senders.find_or_create_by(from: received_message.from) do |sender|
          sender.name = received_message.from_name
          sender.metadata = received_message.from_metadata
        end
      end

      def message
        return nil if received_message.message_id.blank?

        @message ||= setting.messages.find_or_create_by(message_id: received_message.message_id) do |message|
          message.chat_id = received_message.chat_id
          message.message_type = received_message.type
          message.sender = sender
          message.content = received_message.message_data
        end
      end
    end
  end
end
