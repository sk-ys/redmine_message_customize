require File.dirname(__FILE__) + '/../test_helper'

class CustomMessageSettingTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses, :roles, :custom_message_settings
  include Redmine::I18n

  def setup
    User.current = User.find_by(login: 'admin')
    @custom_message_setting = CustomMessageSetting.find(1)
    MessageCustomize::Locale.reload!(['en', 'ja'])
    set_language_if_valid 'en'
    Rails.application.config.i18n.load_path = (Rails.application.config.i18n.load_path + Dir.glob(Rails.root.join('plugins', 'redmine_message_customize', 'config', 'locales', 'custom_messages', '*.rb'))).uniq

    setup_project
  end

  def setup_project
    @project = Project.find(1)
    @custom_message_setting.value = @custom_message_setting.value.merge(
      { project_settings: { :"#{@project.identifier}" => {
        enabled: 'true',
        custom_messages: { 'en' => { 'label_home' => 'Home4' }, 'de' => { 'label_home' => 'Home5' }},
        timestamp: Time.now.to_i.to_s
      }}}
    )
  end

  def test_validate_with_unused_keys_should_invalid
    @custom_message_setting.value = { custom_messages: { 'en' => {'foo' => 'bar' }} }
    assert_not @custom_message_setting.valid?
    assert_equal "#{l(:error_unused_keys)} keys: [foo]", @custom_message_setting.errors[:base].first
  end

  def test_validate_with_unusable_type_of_keys_should_invalid
    @custom_message_setting.value = { custom_messages: { 'en' => {'date' => {'order' => 'foobar' }}} }
    assert_not @custom_message_setting.valid?
    assert_equal "#{l(:error_unusable_type_of_keys)} keys: [date.order]", @custom_message_setting.errors[:base].first
  end

  def test_validate_with_not_available_languages_should_invalid
    @custom_message_setting.value = { custom_messages: { 'foo' => {'label_home' => 'Home' }} }
    assert_not @custom_message_setting.valid?
    assert_equal "#{l(:error_unavailable_languages)} [foo]", @custom_message_setting.errors[:base].first
  end

  def test_validate_with_invalid_yaml_should_invalid
    @custom_message_setting.value = { custom_messages: "---\nen:\n  label_home: Home3\ninvalid-string" }
    assert_not @custom_message_setting.valid?
    assert_equal "The format of yaml is invalid. (<unknown>): could not find expected ':' while scanning a simple key at line 4 column 1", @custom_message_setting.errors[:base].first
  end

  def test_find_or_default
    assert_equal @custom_message_setting, CustomMessageSetting.find_or_default
  end

  def test_enabled?
    @custom_message_setting.value = { enabled: 'true' }
    assert @custom_message_setting.enabled?

    @custom_message_setting.value = { enabled: 'false' }
    assert_not @custom_message_setting.enabled?

    @custom_message_setting.value = { enabled: nil }
    assert @custom_message_setting.enabled?
  end

  def test_enabled_with_project
    @custom_message_setting.value = @custom_message_setting.value.merge(
      { project_settings: { :"#{@project.identifier}" => { enabled: 'true' }}})
    assert @custom_message_setting.enabled?(@project)

    @custom_message_setting.value = @custom_message_setting.value.merge(
      { project_settings: { :"#{@project.identifier}" => { enabled: 'false' }}})
    assert_not @custom_message_setting.enabled?(@project)

    @custom_message_setting.value = @custom_message_setting.value.merge(
      { project_settings: { :"#{@project.identifier}" => { enabled: nil }}})
    assert @custom_message_setting.enabled?(@project)
  end

  def test_custom_messages
    assert_equal @custom_message_setting.value['custom_messages'], @custom_message_setting.custom_messages
    assert_equal ({'label_home' => 'Home1'}), @custom_message_setting.custom_messages('en')
    assert_equal ({}), @custom_message_setting.custom_messages('foo')
  end

  def test_custom_messages_for_project_when_check_enabled_is_true_without_project
    assert_equal({'label_home' => 'Home1'}, @custom_message_setting.custom_messages('en', false, nil))
    assert_equal({'label_home' => 'Home2'}, @custom_message_setting.custom_messages('ja', false, nil))
    assert_equal({}, @custom_message_setting.custom_messages('de', false, nil))
  end

  def test_custom_messages_for_project_when_check_enabled_is_true_with_project
    assert_equal({'label_home' => 'Home4'}, @custom_message_setting.custom_messages('en', false, @project))
    assert_equal({}, @custom_message_setting.custom_messages('ja', false, @project))
    assert_equal({'label_home' => 'Home5'}, @custom_message_setting.custom_messages('de', false, @project))
    assert_equal({}, @custom_message_setting.custom_messages('en', false, Project.find(2)))
  end

  def test_custom_messages_with_timestamp
    assert_equal ({'label_home' => 'Home1', 'redmine_message_customize_timestamp' => @custom_message_setting.updated_on.to_i.to_s}), @custom_message_setting.custom_messages_with_timestamp('en')
    assert_equal ({'redmine_message_customize_timestamp' => @custom_message_setting.updated_on.to_i.to_s}), @custom_message_setting.custom_messages_with_timestamp('foo')
  end

  def test_custom_messages_with_timestamp_with_project
    assert_equal ({'label_home' => 'Home1', 'redmine_message_customize_timestamp' => @custom_message_setting.updated_on.to_i.to_s}), @custom_message_setting.custom_messages_with_timestamp('en')

    @custom_message_setting.update_active_project(@project)
    assert_equal ({'label_home' => 'Home4', 'redmine_message_customize_timestamp' => @custom_message_setting.updated_on.to_i.to_s}), @custom_message_setting.custom_messages_with_timestamp('en')

    @custom_message_setting.update_active_project(Project.find(2))
    assert_equal ({'label_home' => 'Home1', 'redmine_message_customize_timestamp' => @custom_message_setting.updated_on.to_i.to_s}), @custom_message_setting.custom_messages_with_timestamp('en')
  end

  def test_latest_messages_applied_should_return_true_if_new_record
    @custom_message_setting.destroy
    custom_message_setting = CustomMessageSetting.find_or_default
    assert custom_message_setting.latest_messages_applied?('en')
  end

  def test_latest_messages_applied_should_return_true_if_redmine_message_customize_timestamp_equal_updated_on
    assert_equal @custom_message_setting.updated_on.to_i.to_s, I18n.backend.send(:translations)[:en][:redmine_message_customize_timestamp]
    assert @custom_message_setting.latest_messages_applied?('en')
  end

  def test_latest_messages_applied_should_return_true_if_redmine_message_customize_timestamp_not_equal_updated_on
    @custom_message_setting.update_with_custom_messages({'label_home' => 'Changed home'}, 'en')

    assert_not_equal @custom_message_setting.updated_on.to_i.to_s, I18n.backend.send(:translations)[:en][:redmine_message_customize_timestamp]
    assert_not @custom_message_setting.latest_messages_applied?('en')
  end

  def test_latest_messages_applied_should_return_true_if_redmine_message_customize_timestamp_equal_updated_on_with_project
    assert_equal @custom_message_setting.updated_on.to_i.to_s, I18n.backend.send(:translations)[:en][:redmine_message_customize_timestamp]
    assert @custom_message_setting.latest_messages_applied?('en')
    assert_not @custom_message_setting.latest_messages_applied?('en', @project)

    @custom_message_setting.update_active_project(@project)
    # updated_on param is updated by CustomMessageSetting::update_active_project
    assert_not @custom_message_setting.latest_messages_applied?('en', @project)
    MessageCustomize::Locale.reload!('en')
    assert @custom_message_setting.latest_messages_applied?('en', @project)

    @custom_message_setting.update_active_project(nil)
    assert @custom_message_setting.latest_messages_applied?('en')
    assert_not @custom_message_setting.latest_messages_applied?('en', @project)
  end

  def test_custom_messages_with_check_enabled
    assert @custom_message_setting.enabled?
    assert_equal ({'label_home' => 'Home1'}), @custom_message_setting.custom_messages('en', true)
    assert_equal ({'label_home' => 'Home1'}), @custom_message_setting.custom_messages('en', false)

    @custom_message_setting.toggle_enabled!
    assert_not @custom_message_setting.enabled?
    assert_equal ({}), @custom_message_setting.custom_messages('en', true)
    assert_equal ({'label_home' => 'Home1'}), @custom_message_setting.custom_messages('en', false)
  end

  def test_custom_messages_with_check_enabled_with_project
    assert @custom_message_setting.enabled?(@project)
    assert_equal ({'label_home' => 'Home4'}), @custom_message_setting.custom_messages('en', true, @project)
    assert_equal ({'label_home' => 'Home4'}), @custom_message_setting.custom_messages('en', false, @project)

    @custom_message_setting.toggle_enabled!(@project)
    assert_not @custom_message_setting.enabled?(@project)
    assert_equal ({}), @custom_message_setting.custom_messages('en', true, @project)
    assert_equal ({'label_home' => 'Home4'}), @custom_message_setting.custom_messages('en', false, @project)
  end

  def test_custom_messages_to_yaml
    assert_equal "---\nen:\n  label_home: Home1\nja:\n  label_home: Home2\n", @custom_message_setting.custom_messages_to_yaml

    @custom_message_setting.value = { custom_messages: {} }
    assert_equal '', @custom_message_setting.custom_messages_to_yaml

    @custom_message_setting.value = { custom_messages: 'test' }
    assert_equal 'test', @custom_message_setting.custom_messages_to_yaml
  end

  def test_custom_messages_to_yaml_with_project
    assert_equal "---\nen:\n  label_home: Home4\nde:\n  label_home: Home5\n", @custom_message_setting.custom_messages_to_yaml(@project)
  end

  def test_update_with_custom_messages_if_custom_messages_is_exist
    flatten_hash = {'label_home' => 'Home3', 'time.am' => 'foo'}

    assert @custom_message_setting.update_with_custom_messages(flatten_hash, 'en')
    assert_equal ({'label_home' => 'Home3', 'time' => { 'am' => 'foo'}}), @custom_message_setting.custom_messages('en')
  end
  def test_update_with_custom_messages_if_custom_messages_is_blank
    assert @custom_message_setting.update_with_custom_messages({}, 'en')
    assert_not @custom_message_setting.custom_messages.key('en')
  end

  def test_update_with_custom_messages_if_custom_messages_is_exist_with_project
    flatten_hash = {'label_home' => 'Home3', 'time.am' => 'foo'}

    assert @custom_message_setting.update_with_custom_messages(flatten_hash, 'en', @project)
    assert_equal ({'label_home' => 'Home3', 'time' => { 'am' => 'foo'}}), @custom_message_setting.custom_messages('en', false, @project)
  end
  def test_update_with_custom_messages_if_custom_messages_is_blank_with_project
    assert @custom_message_setting.update_with_custom_messages({}, 'en', @project)
    assert_not @custom_message_setting.custom_messages('en', false, @project).key('en')
  end

  def test_update_with_custom_messages_yaml_if_yaml_is_valid
    yaml = "---\nen:\n  label_home: Home3"
    assert @custom_message_setting.update_with_custom_messages_yaml(yaml)
    assert_equal ({ 'label_home' => 'Home3' }), @custom_message_setting.custom_messages('en')
  end

  def test_toggle_enabled!
    assert @custom_message_setting.enabled?
    assert_equal 'Home1', l(:label_home)

    @custom_message_setting.toggle_enabled!
    assert_not @custom_message_setting.enabled?
    MessageCustomize::Locale.reload!('en')
    assert_equal 'Home', l(:label_home)

    @custom_message_setting.toggle_enabled!
    assert @custom_message_setting.enabled?
    MessageCustomize::Locale.reload!('en')
    assert_equal 'Home1', l(:label_home)
  end

  def test_toggle_enabled_with_project
    @custom_message_setting.update_active_project(@project)

    assert @custom_message_setting.enabled?(@project)
    MessageCustomize::Locale.reload!('en')
    assert_equal 'Home4', l(:label_home)

    @custom_message_setting.toggle_enabled!(@project)
    assert_not @custom_message_setting.enabled?(@project)
    MessageCustomize::Locale.reload!('en')
    assert_equal 'Home1', l(:label_home)

    @custom_message_setting.toggle_enabled!(@project)
    assert @custom_message_setting.enabled?(@project)
    MessageCustomize::Locale.reload!('en')
    assert_equal 'Home4', l(:label_home)

    @custom_message_setting.update_active_project(nil)

    assert @custom_message_setting.enabled?
    MessageCustomize::Locale.reload!('en')
    assert_equal 'Home1', l(:label_home)
  end

  def test_flatten_hash_should_return_hash_with_flat_keys
    flatten_hash = CustomMessageSetting.flatten_hash({time: {am: 'foo'}})
    assert_equal ({:'time.am' => 'foo'}), flatten_hash
  end

  def test_flatten_hash_should_return_nest_hash
    nested_hash = CustomMessageSetting.nested_hash({:'time.am' => 'foo'})
    assert_equal ({'time' => {'am' => 'foo'}}), nested_hash
  end
end
