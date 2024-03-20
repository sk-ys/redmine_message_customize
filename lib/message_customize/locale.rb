# frozen_string_literal: true

module MessageCustomize
  module Locale
    @available_messages = {}
    CHANGE_LOAD_ORDER_LOCALES_FILE_PATH = 'config/initializers/35_change_load_order_locales.rb'

    class << self
      def available_locales
        @available_locales ||= Rails.application.config.i18n.load_path.map {|path| File.basename(path, '.*')}.uniq.sort.map(&:to_sym)
      end

      def reload!(*languages, project)
        available_languages = self.find_language(languages.flatten)

        # Remove all project locale settings
        Rails.application.config.i18n.load_path.delete_if {|path| path.include?('custom_messages/projects/')}

        if project.present?
          available_languages.each do |lang|
            locale_per_project_path = File.join(CustomMessageSetting.projects_dir, "#{project.identifier}.#{lang}.yml")

            # Append project locale file path
            Rails.application.config.i18n.load_path += [locale_per_project_path] if File.exist?(locale_per_project_path)
          end
        end

        paths = Rails.application.config.i18n.load_path.select {|path| available_languages.include?(File.basename(path, '.*').to_s.split(".")[-1])}
        I18n.backend.load_translations(paths)
        if customizable_plugin_messages?
          available_languages.each{|lang| @available_messages[:"#{lang}"] = I18n.backend.send(:translations)[:"#{lang}"] || {}}
        else
          available_languages.each do |lang|
            redmine_root_locale_path = Rails.root.join('config', 'locales', "#{lang}.yml")
            if File.exist?(redmine_root_locale_path)
              loaded_yml = I18n.backend.send(:load_yml, redmine_root_locale_path)
              loaded_yml = loaded_yml.first if loaded_yml.is_a?(Array)
              @available_messages[:"#{lang}"] = (loaded_yml[lang] || loaded_yml[lang.to_sym] || {}).deep_symbolize_keys
            end
          end
        end
      end

      def find_language(language=nil)
        return nil if language.nil?

        if language.is_a?(Array)
          language.select{|l| self.find_language(l).present?}.map(&:to_s).uniq
        elsif language.present? && self.available_locales.include?(:"#{language}")
          language.to_s
        end
      end

      def available_messages(lang, project=nil)
        lang = :"#{lang}"
        self.reload!(lang, project) if @available_messages[lang].blank?
        @available_messages[lang] || {}
      end

      def customizable_plugin_messages?
        Rails.application.config.i18n.load_path.last.include?('redmine_message_customize')
      end
    end
  end
end
