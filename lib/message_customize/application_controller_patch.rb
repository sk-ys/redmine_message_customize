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

        project = MessageCustomize::ApplicationControllerPatch.find_project(params, custom_message_setting)

        return if custom_message_setting.latest_messages_applied?(current_user_language, project)

        lang = current_user_language
        MessageCustomize::Locale.reload!([lang], project)

        # Update customize timestamp for project
        if project.present?
          if custom_message_setting.value[:project_settings][:"#{project.identifier}"]&.[](:"#{lang}")&.[](:timestamp).blank?
            locale_per_project_path = File.join(CustomMessageSetting.projects_dir, "#{project.identifier}.#{lang}.yml")
            if Rails.application.config.i18n.load_path.include?(locale_per_project_path)
              if File.exist?(locale_per_project_path)
                custom_message_setting.update_project_customize_timestamp(project, lang, File.mtime(locale_per_project_path))
              end
            end
          end
        end
      end

      private

      def current_user_language
        User.current.language.presence || Setting.default_language
      end
    end

    module_function

    def find_project(params, custom_message_setting)
      return nil if Setting["plugin_redmine_message_customize"][:enabled_per_project] != "1"

      project_id = params[:project_id]
      project =
        if project_id.nil? && params["id"].present?
          case params["controller"]
          when "projects"
            Project.find(params["id"])
          when "issues"
            Issue.find(params["id"]).project
          end
        else
          Project.find(project_id)
        end

      # If customization is disabled, remove project
      return nil if project.blank? ||
        project.enabled_modules.where(name: "redmine_message_customize").blank? ||
        !custom_message_setting.enabled?(project)
      return project
    rescue ActiveRecord::RecordNotFound
      return nil
    end
  end
end

ApplicationController.include(MessageCustomize::ApplicationControllerPatch)
