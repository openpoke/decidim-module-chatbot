# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      class BaseAdapter
        def initialize(params:)
          @params = params.dup
        end

        attr_reader :params

        def consume_message
          raise NotImplementedError
        end

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
        def mark_as_read!(_message)
          nil
        end

        # Send a message to the user
        def send!(_message)
          raise NotImplementedError
        end
      end
    end
  end
end
