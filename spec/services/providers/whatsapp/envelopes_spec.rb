# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        module Envelopes
          describe Base do
            subject { described_class.new(to:, data:) }

            let(:to) { "123456789" }
            let(:data) { { body: "Hello" } }

            describe "#initialize" do
              it "stores the recipient" do
                expect(subject.to).to eq(to)
              end

              it "stores the data" do
                expect(subject.data).to eq(data)
              end
            end

            describe "#body" do
              it "returns the base envelope structure" do
                expect(subject.body).to eq({
                                             messaging_product: "whatsapp",
                                             recipient_type: "individual",
                                             to: "123456789"
                                           })
              end
            end
          end

          describe Text do
            subject { described_class.new(to:, data:) }

            let(:to) { "123456789" }
            let(:data) { { body: "Hello world" } }

            describe "#body" do
              it "returns text message structure" do
                expect(subject.body).to eq({
                                             messaging_product: "whatsapp",
                                             recipient_type: "individual",
                                             to: "123456789",
                                             type: "text",
                                             text: {
                                               body: "Hello world"
                                             }
                                           })
              end
            end
          end

          describe InteractiveButtons do
            subject { described_class.new(to:, data:) }

            let(:to) { "123456789" }
            let(:data) do
              {
                body_text: "Choose an option",
                buttons: [
                  { id: "btn1", title: "Option 1" },
                  { id: "btn2", title: "Option 2" }
                ]
              }
            end

            describe "#body" do
              it "returns interactive buttons structure" do
                body = subject.body
                expect(body[:type]).to eq("interactive")
                expect(body[:interactive][:type]).to eq("button")
                expect(body[:interactive][:body][:text]).to eq("Choose an option")
                expect(body[:interactive][:action][:buttons].length).to eq(2)
              end

              it "formats buttons correctly" do
                buttons = subject.body[:interactive][:action][:buttons]
                expect(buttons.first).to eq({
                                              type: "reply",
                                              reply: { id: "btn1", title: "Option 1" }
                                            })
              end

              context "with header_text" do
                let(:data) do
                  {
                    header_text: "Welcome",
                    body_text: "Choose an option",
                    buttons: [{ id: "btn1", title: "Option 1" }]
                  }
                end

                it "includes text header" do
                  header = subject.body[:interactive][:header]
                  expect(header[:type]).to eq("text")
                  expect(header[:text]).to eq("Welcome")
                end
              end

              context "with header_image" do
                let(:data) do
                  {
                    header_image: "https://example.com/image.jpg",
                    body_text: "Choose an option",
                    buttons: [{ id: "btn1", title: "Option 1" }]
                  }
                end

                it "includes image header" do
                  header = subject.body[:interactive][:header]
                  expect(header[:type]).to eq("image")
                  expect(header[:image]).to eq({ link: "https://example.com/image.jpg" })
                end
              end

              context "without header" do
                let(:data) do
                  {
                    body_text: "Choose an option",
                    buttons: [{ id: "btn1", title: "Option 1" }]
                  }
                end

                it "does not include header" do
                  expect(subject.body[:interactive]).not_to have_key(:header)
                end
              end

              context "with footer_text" do
                let(:data) do
                  {
                    body_text: "Choose an option",
                    footer_text: "Powered by Decidim",
                    buttons: [{ id: "btn1", title: "Option 1" }]
                  }
                end

                it "includes footer" do
                  footer = subject.body[:interactive][:footer]
                  expect(footer[:text]).to eq("Powered by Decidim")
                end
              end

              context "without footer" do
                let(:data) do
                  {
                    body_text: "Choose an option",
                    buttons: [{ id: "btn1", title: "Option 1" }]
                  }
                end

                it "does not include footer" do
                  expect(subject.body[:interactive]).not_to have_key(:footer)
                end
              end
            end
          end

          describe InteractiveCarousel do
            subject { described_class.new(to:, data:) }

            let(:to) { "123456789" }
            let(:data) do
              {
                body_text: "Check out these options",
                cards: [
                  {
                    image_url: "https://example.com/image1.jpg",
                    body_text: "Card 1 description",
                    url: "https://example.com/1",
                    url_title: "Visit Card 1"
                  },
                  {
                    image_url: "https://example.com/image2.jpg",
                    body_text: "Card 2 description",
                    url: "https://example.com/2",
                    url_title: "Visit Card 2"
                  }
                ]
              }
            end

            describe "#body" do
              it "returns interactive carousel structure" do
                body = subject.body
                expect(body[:type]).to eq("interactive")
                expect(body[:interactive][:type]).to eq("carousel")
                expect(body[:interactive][:body][:text]).to eq("Check out these options")
              end

              it "includes the correct number of cards" do
                cards = subject.body[:interactive][:action][:cards]
                expect(cards.length).to eq(2)
              end

              it "formats cards correctly" do
                cards = subject.body[:interactive][:action][:cards]
                first_card = cards.first

                expect(first_card[:card_index]).to eq(0)
                expect(first_card[:type]).to eq("cta_url")
                expect(first_card[:header][:type]).to eq("image")
                expect(first_card[:header][:image][:link]).to eq("https://example.com/image1.jpg")
                expect(first_card[:body][:text]).to eq("Card 1 description")
                expect(first_card[:action][:name]).to eq("cta_url")
                expect(first_card[:action][:parameters][:display_text]).to eq("Visit Card 1")
                expect(first_card[:action][:parameters][:url]).to eq("https://example.com/1")
              end

              it "sets correct card indices" do
                cards = subject.body[:interactive][:action][:cards]
                expect(cards[0][:card_index]).to eq(0)
                expect(cards[1][:card_index]).to eq(1)
              end

              context "when card has no body_text" do
                let(:data) do
                  {
                    body_text: "Check out these options",
                    cards: [
                      {
                        image_url: "https://example.com/image1.jpg",
                        url: "https://example.com/1",
                        url_title: "Visit"
                      }
                    ]
                  }
                end

                it "omits the body from the card" do
                  card = subject.body[:interactive][:action][:cards].first
                  expect(card).not_to have_key(:body)
                end
              end
            end
          end

          describe ReadReceipt do
            subject { described_class.new(to:, data:) }

            let(:to) { nil }
            let(:data) { { message_id: "wamid.test123" } }

            describe "#body" do
              it "returns read receipt structure" do
                expect(subject.body).to eq({
                                             messaging_product: "whatsapp",
                                             status: "read",
                                             message_id: "wamid.test123"
                                           })
              end

              it "does not include recipient" do
                expect(subject.body).not_to have_key(:to)
                expect(subject.body).not_to have_key(:recipient_type)
              end
            end
          end
        end
      end
    end
  end
end
