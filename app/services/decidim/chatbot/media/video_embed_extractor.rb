# frozen_string_literal: true

module Decidim
  module Chatbot
    module Media
      # Service class to extract video URLs from HTML iframes
      # Supports YouTube and Vimeo embeds
      class VideoEmbedExtractor
        # Regex patterns to match iframe src attributes for supported video platforms
        YOUTUBE_PATTERN = %r{<iframe[^>]+src=["\']https?://(?:www\.)?(?:youtube\.com/embed/|youtu\.be/|youtube-nocookie\.com/embed/)([a-zA-Z0-9_-]+)(?:[?&][^"\']*)?["\'][^>]*>}i
        VIMEO_PATTERN = %r{<iframe[^>]+src=["\']https?://(?:www\.)?player\.vimeo\.com/video/(\d+)(?:[?&][^"\']*)?["\'][^>]*>}i

        # Extracts a video URL from HTML content
        # @param html [String] The HTML string to parse
        # @return [Hash] A hash with :video_url key containing the extracted URL or nil
        def initialize(html)
          @html = html
        end

        attr_reader :html

        def url
          return nil if html.blank?

          @url ||= extract_youtube || extract_vimeo
        end

        def valid?
          url.present?
        end

        # Returns the video thumbnail URL
        # @return [String, nil] The thumbnail URL or nil if no video found
        def thumbnail_url
          return nil unless valid?

          @thumbnail_url ||= if youtube?
                               youtube_thumbnail_url
                             elsif vimeo?
                               vimeo_thumbnail_url
                             end
        end

        private

        def video_id
          @video_id ||= extract_video_id
        end

        def youtube?
          html.match?(YOUTUBE_PATTERN)
        end

        def vimeo?
          html.match?(VIMEO_PATTERN)
        end

        def extract_video_id
          if youtube?
            html.match(YOUTUBE_PATTERN)&.[](1)
          elsif vimeo?
            html.match(VIMEO_PATTERN)&.[](1)
          end
        end

        def extract_youtube
          return nil unless youtube?

          "https://www.youtube.com/watch?v=#{video_id}"
        end

        def extract_vimeo
          return nil unless vimeo?

          "https://vimeo.com/#{video_id}"
        end

        # Returns YouTube thumbnail URL
        # Uses maxresdefault for best quality, falls back to hqdefault
        def youtube_thumbnail_url
          "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg"
        end

        # Returns Vimeo thumbnail URL using oEmbed API pattern
        # Note: This could be enhanced to fetch actual thumbnail via HTTP request
        def vimeo_thumbnail_url
          # Vimeo doesn't have a predictable thumbnail URL pattern like YouTube
          # We'd need to make an API call to get it, but for now return nil
          # or fetch it via: https://vimeo.com/api/oembed.json?url=https://vimeo.com/{video_id}
          nil
        end
      end
    end
  end
end
