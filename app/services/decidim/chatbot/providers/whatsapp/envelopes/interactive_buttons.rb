# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        module Envelopes
          # body = {
          #   messaging_product: "whatsapp",
          #   recipient_type: "individual",
          #   to: message.to,
          #   type: "interactive",
          #   interactive: {
          #     type: "button",
          #     header: { type: "text", text: "✅ Acknowledgment" },
          #     body: {
          #       text: message.body
          #     },
          #     footer: { text: "🙏 Thank you for contacting us!" },
          #     action: {
          #       buttons: [
          #         { type: "reply", reply: { id: "ack_1", title: "👍 OK" } }
          #       ]
          #     }
          #   }
          # }
          class InteractiveButtons < Base
            def body
              super.merge(
                type: "interactive",
                interactive: {
                  type: "button",
                  header: { type: "text", text: data[:header_text] },
                  body: {
                    text: data[:body_text]
                  },
                  footer: { text: data[:footer_text] },
                  action: {
                    buttons: data[:buttons].map do |button|
                      { type: "reply", reply: { id: button[:id], title: button[:title] } }
                    end
                  }
                }.tap do |interactive|
                  interactive.delete(:header) if data[:header_text].blank?
                  interactive.delete(:footer) if data[:footer_text].blank?
                end
              )
            end
          end
        end
      end
    end
  end
end
