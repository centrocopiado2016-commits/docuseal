# frozen_string_literal: true

class PersonalizationSettingsController < ApplicationController
  ALLOWED_KEYS = [
    AccountConfig::FORM_COMPLETED_BUTTON_KEY,
    AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY,
    AccountConfig::SUBMITTER_INVITATION_REMINDER_EMAIL_KEY,
    AccountConfig::SUBMITTER_DOCUMENTS_COPY_EMAIL_KEY,
    AccountConfig::SUBMITTER_COMPLETED_EMAIL_KEY,
    AccountConfig::FORM_COMPLETED_MESSAGE_KEY,
    *(Docuseal.multitenant? ? [] : [AccountConfig::POLICY_LINKS_KEY])
  ].freeze
  USER_ALLOWED_KEYS = [
    AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY,
    AccountConfig::SUBMITTER_INVITATION_REMINDER_EMAIL_KEY,
    AccountConfig::SUBMITTER_DOCUMENTS_COPY_EMAIL_KEY,
    AccountConfig::SUBMITTER_COMPLETED_EMAIL_KEY
  ].freeze

  InvalidKey = Class.new(StandardError)

  helper_method :personalization_config_for

  before_action :load_and_authorize_account_config, only: :create

  def show
    authorize!(:read, :personalization_settings) unless can?(:read, AccountConfig)
  end

  def create
    normalize_config_value!

    current_user.admin? ? save_account_config! : save_user_config!

    redirect_back(fallback_location: settings_personalization_path, notice: I18n.t('settings_have_been_saved'))
  end

  private

  def load_and_authorize_account_config
    @account_config = if current_user.admin?
                        current_account.account_configs.find_or_initialize_by(key: account_config_params[:key])
                      else
                        AccountConfig.new(account: current_account, key: account_config_params[:key])
                      end

    @account_config.assign_attributes(account_config_params)

    if current_user.admin?
      authorize!(:create, @account_config)
      raise InvalidKey unless ALLOWED_KEYS.include?(@account_config.key)
    else
      authorize!(:manage, current_user.user_configs.build)
      raise InvalidKey unless USER_ALLOWED_KEYS.include?(@account_config.key)
    end

    @account_config
  end

  def personalization_config_for(key)
    return AccountConfigs.find_or_initialize_for_key(current_account, key) if current_user.admin?

    user_config = current_user.user_configs.find_by(key: UserConfig.personalization_key(key))

    AccountConfig.new(
      account: current_account,
      key:,
      value: user_config&.value || AccountConfig::DEFAULT_VALUES[key]&.call
    )
  end

  def normalize_config_value!
    return unless @account_config.value.is_a?(Hash)

    @account_config.value = @account_config.value.reject do |_, v|
      v.blank? && v != false
    end
  end

  def save_account_config!
    if @account_config.value != false && @account_config.value.blank?
      @account_config.destroy!
    else
      @account_config.save!
    end
  end

  def save_user_config!
    user_config = current_user.user_configs.find_or_initialize_by(
      key: UserConfig.personalization_key(@account_config.key)
    )

    if @account_config.value != false && @account_config.value.blank?
      user_config.destroy! if user_config.persisted?
    else
      user_config.value = @account_config.value
      user_config.save!
    end
  end

  def account_config_params
    attrs = params.require(:account_config).permit(:key, :value, { value: {} }, { value: [] })

    return attrs if attrs[:value].is_a?(String)

    attrs[:value]&.transform_values! do |value|
      if value.in?(%w[true false])
        value == 'true'
      else
        value
      end
    end

    attrs
  end
end
