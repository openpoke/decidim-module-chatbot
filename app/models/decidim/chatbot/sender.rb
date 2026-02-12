# frozen_string_literal: true

module Decidim
  module Chatbot
    class Sender < ApplicationRecord
      belongs_to :setting, class_name: "Decidim::Chatbot::Setting"
      belongs_to :decidim_user, class_name: "Decidim::User", optional: true

      delegate :provider, :organization, :workflow, to: :setting

      def user
        existing_user = decidim_user || Decidim::User.find_by("extended_data->>'chatbot_sender_id' = ?", id)
        return existing_user if existing_user

        new_user = Decidim::User.create!(
          # Because Decidim is picky with names and we don't want to break it with weird characters from the provider
          name: name.gsub(/[<>?%&\^*#@()\[\]=+:;"{}\\|]/, "").presence || "#{provider.titleize} #{id}",
          nickname: UserBaseEntity.nicknamize("#{name}_#{provider}", organization.id),
          organization: organization,
          tos_agreement: true,
          managed: true,
          extended_data: { chatbot_sender_id: id }
        )
        update!(decidim_user: new_user)
        new_user
      end

      def current_workflow
        workflow_stack.last&.dig("class")&.safe_constantize || workflow
      end

      def parent_workflow
        workflow_stack[-2]&.dig("class")&.safe_constantize || workflow if current_workflow != workflow
      end

      def locale
        metadata["locale"].presence || decidim_user&.locale.presence || organization.default_locale
      end

      def current_workflow_options
        workflow_stack.last&.dig("options").presence || {}
      end

      def parent_workflow_options
        workflow_stack[-2]&.dig("options").presence || {}
      end

      def current_workflow_merge!(options)
        current_workflow_options!(current_workflow_options.merge(options))
      end

      def current_workflow_options!(options)
        stack = workflow_stack.dup
        if stack.empty?
          # If stack is empty, initialize it with the current workflow
          stack << {
            "class" => workflow.name,
            "options" => options
          }
        else
          stack[-1]["options"] = options
        end
        update!(workflow_stack: stack)
      end

      # Override to ensure workflow_stack is always an array
      def workflow_stack
        self[:workflow_stack] || []
      end

      # Incorporates the current workflow stack with the parent workflow to provide a full view of the workflow history
      def full_workflow_stack
        @full_workflow_stack ||= begin
          stack = workflow_stack.dup
          if parent_workflow && (stack.empty? || stack.first["class"] != workflow.name)
            stack.unshift({
                            "class" => workflow.name,
                            "options" => {}
                          })
          end
          stack
        end
      end

      # Start a new workflow by pushing it to the stack
      def push_to_workflow_stack!(workflow_class, options = {})
        stack = workflow_stack.dup
        stack << {
          "class" => workflow_class.name,
          "options" => options
        }
        update!(workflow_stack: stack)
      end

      # Exit current workflow by popping from the stack
      def pop_from_workflow_stack!
        stack = workflow_stack.dup
        return nil if stack.empty?

        stack.pop
        update!(workflow_stack: stack)
      end

      # Reset all workflows (clear the stack)
      def clear_workflow_stack!
        update!(workflow_stack: [])
      end
    end
  end
end
