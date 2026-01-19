# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        module Envelopes
          class Text < Base
            def body
              super.merge(
                type: "text",
                text: {
                  body: data[:body]
                }
              )
            end
          end
        end
      end
    end
  end
end
