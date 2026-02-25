# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Media
      describe VideoEmbedExtractor do
        describe "#url, #valid?, #thumbnail_url" do
          context "when html is blank" do
            it "returns nil url and is not valid" do
              expect(described_class.new(nil).url).to be_nil
              expect(described_class.new(nil).valid?).to be false
              expect(described_class.new(nil).thumbnail_url).to be_nil

              expect(described_class.new("").url).to be_nil
              expect(described_class.new("").valid?).to be false
              expect(described_class.new("").thumbnail_url).to be_nil

              expect(described_class.new("   ").url).to be_nil
              expect(described_class.new("   ").valid?).to be false
              expect(described_class.new("   ").thumbnail_url).to be_nil
            end
          end

          context "when html has no video iframe" do
            let(:html) do
              <<-HTML
                <p>This is a proposal with no video</p>
                <div>Some content here</div>
              HTML
            end

            it "returns nil url and is not valid" do
              extractor = described_class.new(html)
              expect(extractor.url).to be_nil
              expect(extractor.valid?).to be false
              expect(extractor.thumbnail_url).to be_nil
            end
          end

          context "when html contains a YouTube iframe" do
            context "with standard embed format" do
              let(:html) do
                <<-HTML
                  <p>Check out this video:</p>
                  <iframe width="560" height="315" src="https://www.youtube.com/embed/dQw4w9WgXcQ" frameborder="0" allowfullscreen></iframe>
                  <p>Great video!</p>
                HTML
              end

              it "extracts and normalizes the YouTube URL" do
                extractor = described_class.new(html)
                expect(extractor.url).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
                expect(extractor.valid?).to be true
              end

              it "extracts the YouTube thumbnail URL" do
                extractor = described_class.new(html)
                expect(extractor.thumbnail_url).to eq("https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
              end
            end

            context "with embed URL containing query parameters" do
              let(:html) do
                '<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&controls=0"></iframe>'
              end

              it "extracts the video ID and normalizes to watch URL" do
                extractor = described_class.new(html)
                expect(extractor.url).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
                expect(extractor.valid?).to be true
              end

              it "extracts the thumbnail URL" do
                extractor = described_class.new(html)
                expect(extractor.thumbnail_url).to eq("https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
              end
            end

            context "with youtu.be short URL" do
              let(:html) do
                '<iframe src="https://youtu.be/dQw4w9WgXcQ"></iframe>'
              end

              it "extracts and normalizes the YouTube URL" do
                extractor = described_class.new(html)
                expect(extractor.url).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
                expect(extractor.valid?).to be true
              end

              it "extracts the thumbnail URL" do
                extractor = described_class.new(html)
                expect(extractor.thumbnail_url).to eq("https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
              end
            end

            context "with single quotes in src attribute" do
              let(:html) do
                "<iframe src='https://www.youtube.com/embed/dQw4w9WgXcQ'></iframe>"
              end

              it "extracts the YouTube URL" do
                extractor = described_class.new(html)
                expect(extractor.url).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
                expect(extractor.valid?).to be true
              end

              it "extracts the thumbnail URL" do
                extractor = described_class.new(html)
                expect(extractor.thumbnail_url).to eq("https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
              end
            end

            context "with a youtube-nocookie.com embed URL" do
              let(:html) do
                '<iframe src="https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?autoplay=1"></iframe>'
              end

              it "extracts and normalizes the YouTube URL" do
                extractor = described_class.new(html)
                expect(extractor.url).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
                expect(extractor.valid?).to be true
              end

              it "extracts the thumbnail URL" do
                extractor = described_class.new(html)
                expect(extractor.thumbnail_url).to eq("https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
              end
            end
          end

          context "when html contains a Vimeo iframe" do
            context "with standard embed format" do
              let(:html) do
                <<-HTML
                  <p>Check out this Vimeo video:</p>
                  <iframe src="https://player.vimeo.com/video/123456789" width="640" height="360" frameborder="0" allowfullscreen></iframe>
                  <p>Amazing content!</p>
                HTML
              end

              it "extracts and normalizes the Vimeo URL" do
                extractor = described_class.new(html)
                expect(extractor.url).to eq("https://vimeo.com/123456789")
                expect(extractor.valid?).to be true
              end

              it "returns nil for thumbnail_url (Vimeo requires API call)" do
                extractor = described_class.new(html)
                expect(extractor.thumbnail_url).to be_nil
              end
            end

            context "with embed URL containing query parameters" do
              let(:html) do
                '<iframe src="https://player.vimeo.com/video/123456789?autoplay=1&title=0"></iframe>'
              end

              it "extracts the video ID and normalizes to vimeo.com URL" do
                extractor = described_class.new(html)
                expect(extractor.url).to eq("https://vimeo.com/123456789")
                expect(extractor.valid?).to be true
              end
            end

            context "with www subdomain" do
              let(:html) do
                '<iframe src="https://www.player.vimeo.com/video/987654321"></iframe>'
              end

              it "extracts the Vimeo URL" do
                extractor = described_class.new(html)
                expect(extractor.url).to eq("https://vimeo.com/987654321")
                expect(extractor.valid?).to be true
              end
            end
          end

          context "when html contains multiple video iframes" do
            let(:html) do
              <<-HTML
                <p>Check out these videos:</p>
                <iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ"></iframe>
                <iframe src="https://player.vimeo.com/video/123456789"></iframe>
              HTML
            end

            it "returns the first video found (YouTube)" do
              extractor = described_class.new(html)
              expect(extractor.url).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
              expect(extractor.valid?).to be true
              expect(extractor.thumbnail_url).to eq("https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
            end
          end

          context "when html contains mixed content with iframe" do
            let(:html) do
              <<-HTML
                <h2>My Proposal Title</h2>
                <p>This is my proposal description with <strong>bold text</strong> and <em>italic text</em>.</p>
                <ul>
                  <li>Point one</li>
                  <li>Point two</li>
                </ul>
                <iframe width="560" height="315" src="https://www.youtube.com/embed/test123" frameborder="0"></iframe>
                <p>More text after the video.</p>
              HTML
            end

            it "correctly extracts the video URL from mixed content" do
              extractor = described_class.new(html)
              expect(extractor.url).to eq("https://www.youtube.com/watch?v=test123")
              expect(extractor.valid?).to be true
              expect(extractor.thumbnail_url).to eq("https://img.youtube.com/vi/test123/maxresdefault.jpg")
            end
          end

          context "when iframe is not a video iframe" do
            let(:html) do
              '<iframe src="https://www.example.com/some-content"></iframe>'
            end

            it "returns nil url and is not valid" do
              extractor = described_class.new(html)
              expect(extractor.url).to be_nil
              expect(extractor.valid?).to be false
              expect(extractor.thumbnail_url).to be_nil
            end
          end
        end
      end
    end
  end
end
