# frozen_string_literal: true

module MessageCustomize
  module Locale
    @available_messages = {}
    CHANGE_LOAD_ORDER_LOCALES_FILE_PATH = 'config/initializers/35_change_load_order_locales.rb'

    class << self
      def available_locales
        @available_locales ||= Rails.application.config.i18n.load_path.map {|path| File.basename(path, '.*')}.uniq.sort.map(&:to_sym)
      end

      def reload!(*languages, project_id)
        available_languages = self.find_language(languages.flatten)

        if !project_id.nil?
          p = Redmine::Plugin.find(:redmine_message_customize)
          projects_dir = File.join(p.directory, 'config', 'locales', 'custom_messages', 'projects')
          current_user_language = User.current.language.presence || Setting.default_language
          locale_per_project_path = File.join(projects_dir, "#{project_id}.#{current_user_language}.yml")

          # exsample to create a locale file per project
          Dir.mkdir(projects_dir, 0664) unless Dir.exist?(projects_dir)
          unless File.exist?(locale_per_project_path)
            YAML.dump({
              'en': {
                'label_related_issues': "---#{project_id}---",
                'label_overview': "Overview - #{project_id}"
              }
            }, File.open(locale_per_project_path, 'w'))
          end

          # append locale file path
          Rails.application.config.i18n.load_path += [locale_per_project_path] if File.exist?(locale_per_project_path)
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

      def available_messages(lang)
        lang = :"#{lang}"
        self.reload!(lang) if @available_messages[lang].blank?
        @available_messages[lang] || {}
      end

      def customizable_plugin_messages?
        Rails.application.config.i18n.load_path.last.include?('redmine_message_customize')
      end
    end
  end
end
