# frozen_string_literal: true

module Decidim
  module Chatbot
    module ApplicationHelper
      def participatory_space_select(config, organization)
        spaces = organization.public_participatory_spaces
        grouped = spaces.group_by { |s| s.class.model_name.human(count: 2) }
                        .transform_values { |arr| arr.map { |s| [translated_attribute(s.title), s.to_gid.to_s] } }
        selected = config[:participatory_space_gid].presence || grouped.values.first&.first&.last.to_s

        config_field(:participatory_space_gid, grouped_options_for_select(grouped, selected),
                     label: :participatory_space,
                     data: { action: "change->chatbot-settings#loadComponents", chatbot_settings_target: "spaceSelect" })
      end

      def component_select(config, organization)
        spaces = organization.public_participatory_spaces
        space = spaces.find { |s| s.to_gid.to_s == config[:participatory_space_gid] } || spaces.first
        components = space ? space.components.published.where(manifest_name: "proposals") : []
        options = components.map { |c| [translated_attribute(c.name), c.id.to_s] }
        selected = config[:component_id].presence || options.first&.last.to_s

        config_field(:component_id, options_for_select(options, selected),
                     label: :component,
                     wrapper: { data: { chatbot_settings_target: "componentsWrapper" }, style: space ? "" : "display:none;" },
                     data: { chatbot_settings_target: "componentSelect" })
      end

      def delegate_workflow_select(config, exclude_workflow: nil)
        workflows = Decidim::Chatbot.start_workflows_registry.manifests
                                    .reject { |m| m.name.to_s == exclude_workflow.to_s }
                                    .map { |m| [m.title, m.name.to_s] }
        selected = config[:delegate_workflow].presence || workflows.first&.last.to_s
        options = workflows.any? ? workflows : [[t("decidim.chatbot.admin.settings.form.no_workflows_available"), ""]]

        config_field(:delegate_workflow, options_for_select(options, selected), disabled: workflows.empty?)
      end

      private

      # Renders a config select field
      def config_field(name, options_html, label: nil, wrapper: {}, **select_attrs)
        label_key = label || name
        field_id = "setting_config_#{name}"

        tag.div(class: "row column", **wrapper) do
          tag.label(for: field_id) do
            safe_join([t("decidim.chatbot.admin.settings.form.#{label_key}"),
                       select_tag("setting[config][#{name}]", options_html, id: field_id, **select_attrs)])
          end
        end
      end
    end
  end
end
