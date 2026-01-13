# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        module Envelopes
          class InteractiveCarousel < Base
            def body
              super.merge(
                type: "interactive",
                interactive: {
                  type: "carousel",
                  body: {
                    text: data[:body_text]
                  },
                  action: {
                    cards:
                  }
                }
              )
            end

            def cards
              data[:cards].map.with_index do |card, index|
                {
                  card_index: index,
                  type: "cta_url",
                  header: {
                    type: "image",
                    image: {
                      link: card[:image_url]
                    }
                  },
                  body: {
                    text: card[:body_text]
                  },
                  action: {
                    name: "cta_url",
                    parameters: {
                      display_text: card[:url_title],
                      url: card[:url]
                    }
                  }
                }.tap do |card_hash|
                  card_hash.delete(:body) if card[:body_text].blank?
                end
              end
            end
          end
        end
      end
    end
  end
end
