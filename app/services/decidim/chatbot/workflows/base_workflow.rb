# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class BaseWorkflow
        include Decidim::TranslatableAttributes
        include Decidim::SanitizeHelper

        WHATSAPP_MAX_IMAGE_BYTES = 5 * 1024 * 1024
        PREFERRED_IMAGE_VARIANTS = [:thumbnail, :thumb, :small, :default, :big, :profile].freeze

        def initialize(adapter:, message:, **options)
          @adapter = adapter
          @message = message
          @options = options.with_indifferent_access
        end

        attr_reader :adapter, :message, :options, :force_welcome

        delegate :send_message!, :build_message, :received_message, to: :adapter
        delegate :setting, :sender, to: :message
        delegate :organization, to: :setting
        delegate :current_workflow, :parent_workflow, to: :sender

        def start(force_welcome = false) # rubocop:disable Style/OptionalBooleanParameter
          @force_welcome = force_welcome
          mark_as_read

          if received_message.user_text? || force_welcome
            process_user_input
          elsif received_message.actionable?
            case received_message.button_id
            when "exit"
              exit_workflow
            when "reset"
              reset_workflows
            else
              process_action_input
            end
          else
            process_unprocessable_input
          end
        rescue StandardError => e
          send_message!(I18n.t(Chatbot.generic_error_message, default: Chatbot.generic_error_message)) if Chatbot.generic_error_message.present?
          send_message!("Error details: *#{e.message}*\n\n#{e.backtrace.first(5).join("\n")}") unless Rails.env.production?
          raise e
        end

        protected

        # Messages started by the user are processed here (text based)
        def process_user_input
          raise NotImplementedError
        end

        # Actions started by the user are processed here (button clicks, etc.)
        def process_action_input
          raise NotImplementedError
        end

        # Messages that cannot be processed as user input or action input are processed here
        def process_unprocessable_input
          send_message!(
            type: :interactive_buttons,
            body_text: I18n.t("decidim.chatbot.workflows.base.unprocessable_input"),
            buttons: [
              {
                id: "reset",
                title: I18n.t("decidim.chatbot.workflows.base.buttons.reset")
              },
              {
                id: "exit",
                title: I18n.t("decidim.chatbot.workflows.base.buttons.exit")
              }
            ].tap do |buttons|
              buttons.delete_if { |button| button[:id] == "exit" } if parent_workflow.nil?
            end
          )
        end

        def mark_as_read
          adapter.mark_as_read! if received_message.acknowledgeable?
          message.mark_as_read! if message
        end

        def mark_as_responding
          adapter.mark_as_responding! if received_message.acknowledgeable?
        end

        # Delegate the workflow to another workflow class so subsequent messages are handled there
        # Pushes the new workflow onto the stack, preserving the current workflow history
        # To replace the entire stack instead, call sender.clear_workflow_stack first
        def delegate_workflow(workflow_class, conf = {})
          sender.push_to_workflow_stack!(workflow_class, conf)
          sender.current_workflow.new(adapter:, message:, **conf).start(true)
        end

        def reset_workflows
          sender.clear_workflow_stack!
          send_message!(I18n.t(Chatbot.reset_workflows_message, default: Chatbot.reset_workflows_message)) if Chatbot.reset_workflows_message.present?
        end

        def exit_workflow(with_welcome = true) # rubocop:disable Style/OptionalBooleanParameter
          # Pop current workflow from stack
          sender.pop_from_workflow_stack!
          conf = sender.current_workflow_options

          # Restart the workflow, which will now be the previous one in the stack (or the start workflow if the stack is empty)
          sender.current_workflow.new(adapter:, message:, **conf.symbolize_keys).start(true) if with_welcome
        end

        # Helper to access the workflow configuration, which is a combination of the setting's config and the options passed when delegating the workflow
        # The options passed when delegating the workflow take precedence over the setting's config, allowing to override specific values for specific users or flows.
        def config
          @config ||= (setting.config || {}).with_indifferent_access.merge(options)
        end

        def current_page
          config[:page].to_i.positive? ? config[:page].to_i : 1
        end

        def per_page
          10
        end

        # TODO: Propose deterministic random ordering in Decidim::Randomable for stable pagination.
        def order_randomly(scope, seed)
          connection = scope.klass.connection
          quoted_seed = connection.quote(seed)

          scope.order(
            Arel.sql("md5(#{scope.table_name}.#{scope.primary_key}::text || #{quoted_seed})")
          )
        end

        # Prepare a message to be sent to the user, applying necessary sanitization and formatting.
        # Accepts a string or hash with languages
        def sanitize_text(text, truncate = 1024)
          translated = translated_attribute(text)
          # Convert HTML line breaks and block elements to newlines before stripping tags
          sanitized = translated.to_s
                                .gsub(%r{<br\s*/?>}i, "\n") # <br>, <br/>, <br /> -> newline
                                .gsub(%r{<h[1-6][^>]*>(.*?)</h[1-6]>}im, "*\\1*\n\n") # <h*>title</h*> -> *title* with newlines
                                .gsub(%r{</p>}i, "\n\n") # </p> -> double newline for paragraphs
                                .gsub(/<p[^>]*>/i, "") # Remove opening <p> tags
                                .gsub(%r{</div>}i, "\n") # </div> -> newline
                                .gsub(/<div[^>]*>/i, "") # Remove opening <div> tags
          strip_tags(sanitized).strip.gsub(/\n{3,}/, "\n\n").truncate(truncate)
        end

        def image_url(path)
          ActionController::Base.helpers.image_pack_url(path, host: "https://#{organization.host}")
        end

        def resource_url(resource, fallback_image: false)
          case resource
          when Decidim::Organization
            "https://#{resource.host}"
          when Decidim::Participable, Decidim::Resourceable
            Decidim::ResourceLocatorPresenter.new(resource).url
          else
            resource_image_url(resource, fallback_image: fallback_image)
          end
        end

        def resource_image_url(resource, fallback_image: false)
          fallback_image_url = fallback_image && image_url("media/images/chatbot-card-placeholder.png")
          return fallback_image_url unless resource.try(:attached?)

          uploader, content_type, file_size = attachment_image_metadata(resource)
          resolve_image_url_from_metadata(uploader, content_type, file_size, fallback_image_url)
        end

        def attachment_image_metadata(resource)
          case resource
          when Decidim::Attachment
            decidim_attachment_image_metadata(resource)
          when ActiveStorage::Attached
            active_storage_attachment_image_metadata(resource)
          else
            [nil, nil, nil]
          end
        end

        def decidim_attachment_image_metadata(resource)
          attachment_file = resource.file
          attachment_blob = attachment_file.blob if attachment_file.respond_to?(:blob)
          content_type = attachment_blob&.content_type || attachment_file&.content_type
          file_size = attachment_blob&.byte_size
          file_size ||= attachment_file.size if attachment_file.respond_to?(:size)
          file_size ||= resource.file_size

          [resource.attached_uploader(:file), content_type, file_size]
        end

        def active_storage_attachment_image_metadata(resource)
          [resource.record.attached_uploader(resource.name), resource.blob&.content_type, resource.blob&.byte_size]
        end

        def resolve_image_url_from_metadata(uploader, content_type, file_size, fallback_image_url)
          return fallback_image_url unless uploader && content_type&.in?(%w(image/jpeg image/png))

          variant_url = preferred_variant_image_url(uploader)
          return variant_url if variant_url.present?

          return fallback_image_url if file_size.to_i.zero? || file_size.to_i > WHATSAPP_MAX_IMAGE_BYTES

          absolute_url(uploader.url)
        end

        def preferred_variant_image_url(uploader)
          return unless uploader.respond_to?(:variants)

          variant_key = preferred_variant_key(uploader.variants.keys)
          return unless variant_key
          return unless variant_size_within_limit?(uploader, variant_key)

          absolute_url(uploader.url(variant: variant_key, host: "https://#{organization.host}"))
        end

        def variant_size_within_limit?(uploader, variant_key)
          variant_size = fetch_variant_size(uploader, variant_key)
          variant_size.present? && variant_size <= WHATSAPP_MAX_IMAGE_BYTES
        end

        def fetch_variant_size(uploader, variant_key)
          return uploader.versions[variant_key]&.file&.size if uploader.respond_to?(:versions)

          return uploader.variant(variant_key)&.blob&.byte_size if uploader.respond_to?(:variant)

          nil
        end

        def preferred_variant_key(available_keys)
          keys = available_keys.map(&:to_sym)
          PREFERRED_IMAGE_VARIANTS.find { |key| keys.include?(key) }
        end

        def absolute_url(url)
          return if url.blank?
          return url if url.match?(%r{\Ahttps?://}i)

          "https://#{organization.host}#{url}"
        end
      end
    end
  end
end
