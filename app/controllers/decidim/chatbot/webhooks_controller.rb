# frozen_string_literal: true

module Decidim
  module Chatbot
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token

      before_action do
        render json: { error: "Provider [#{provider}] not supported" }, status: :bad_request unless setting&.adapter_manifest
      end

      before_action :check_enabled, only: [:receive]

      # GET /chatbot/webhooks/:provider
      # Used by some providers (e.g., WhatsApp) to verify the endpoint
      def verify
        result = adapter.verify!

        if result
          if result.is_a?(Hash)
            render json: result, status: :ok
          else
            render plain: result, status: :ok
          end
        else
          head :forbidden
        end
      end

      # POST /chatbot/webhooks/:provider
      def receive
        process_incoming_message
        head :ok
      end

      private

      def check_enabled
        return if setting&.enabled?

        Rails.logger.info("Chatbot is disabled for provider #{provider}, ignoring message")
        head :ok
      end

      def process_incoming_message
        return log_unknown_sender if sender.nil?
        return log_missing_message_id if message.message_id.nil?

        execute_workflow
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Database error processing webhook: #{e.message}")
      rescue Faraday::Error => e
        Rails.logger.error("Network error sending response: #{e.message}")
      rescue StandardError => e
        Rails.logger.error("Unexpected error processing webhook for provider #{provider}: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
      end

      def log_unknown_sender
        Rails.logger.warn("Received message from unknown sender: #{received_message.from}")
      end

      def log_missing_message_id
        Rails.logger.warn("Received message with no ID: #{message.inspect}")
      end

      def execute_workflow
        Rails.logger.info("Processing webhook for provider #{provider}, organization #{setting.organization.id}, sender #{sender.id}")
        I18n.with_locale(sender_locale) do
          sender.current_workflow.new(adapter:, message:).start
        end
      end

      def sender_locale
        sender.locale.presence || current_locale
      end

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
          sender.metadata = received_message.from_metadata || {}
          sender.metadata["locale"] = received_message.from_locale.presence || current_organization.default_locale
        end
      end

      def message
        return nil if received_message.message_id.blank?

        @message ||= setting.messages.find_or_create_by(message_id: received_message.message_id) do |message|
          message.chat_id = received_message.chat_id
          message.message_type = received_message.type
          message.sender = sender
          message.content = received_message.message_data || {}
        end
      end
    end
  end
end
