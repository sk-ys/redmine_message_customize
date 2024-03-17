# frozen_string_literal: true

module MessageCustomize
  module ApplicationControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethod)
      base.class_eval do
        before_action :reload_customize_messages
      end
    end

    module InstanceMethod
      def reload_customize_messages
        custom_message_setting = CustomMessageSetting.find_or_default

        if Setting["plugin_redmine_message_customize"][:enabled_per_project] != "1"
          project_id = nil
        else
          project_id = params["project_id"]
          if project_id.nil? && params["id"].present?
            case params["controller"]
            when "projects"
              project_id = Project.find(params["id"]).identifier
            when "issues"
              project_id = Issue.find(params["id"]).project.identifier
            end
          end
        end

        # If customization is disabled, remove project_id
        project_id = nil unless custom_message_setting.enabled?(project_id) if project_id.present?

        return if custom_message_setting.latest_messages_applied?(current_user_language, project_id)

        MessageCustomize::Locale.reload!([current_user_language], project_id)
      end

      private

      def current_user_language
        User.current.language.presence || Setting.default_language
      end
    end
  end
end

ApplicationController.include(MessageCustomize::ApplicationControllerPatch)
