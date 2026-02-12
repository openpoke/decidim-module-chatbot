# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      class BaseAdapter
        def initialize(params:)
          @params = params.dup
        end

        attr_reader :params

        # Extract the received message from the provider's payload
        def received_message
          raise NotImplementedError
        end

        # Build a message envelope to be sent
        def build_message(data:, to: nil, type: :text)
          raise NotImplementedError
        end

        # Verify webhook subscription (if supported by the provider)
        def verify!
          {
            status: :not_implemented
          }
        end

        # Send read acknowledgment back to the user (if supported by the provider)
        def mark_as_read!
          nil
        end

        # Send a message to the user with optional delay
        def send_message!(data)
          data = { body: data } if data.is_a?(String)
          type = data.delete(:type) || :text
          to = data.delete(:to) || received_message.from
          delay = data.delete(:delay) || 0

          message = build_message(to:, data:, type:)
          # Convert to JSON and back to ensure no SafeBuffer objects
          message_json = JSON.parse(message.body.to_json)
          Decidim::Chatbot::SendMessageJob.set(wait: delay.to_i).perform_later(
            message_json,
            self.class.name,
            params.as_json
          )
        end

        # Send a message to the user
        def send!(_message)
          raise NotImplementedError
        end
      end
    end
  end
end
