# frozen_string_literal: true

class SmsSettingsController < ApplicationController
  before_action :load_encrypted_config
  authorize_resource :encrypted_config, only: :index
  authorize_resource :encrypted_config, parent: false, only: :create

  def index; end

  def create
    attrs = whatsapp_configs

    WhatsappMessages.test_connection!(attrs[:value])

    if @encrypted_config.update(attrs)
      redirect_to settings_sms_path, notice: I18n.t('changes_have_been_saved')
    else
      render :index, status: :unprocessable_content
    end
  rescue WhatsappMessages::ConfigError, WhatsappMessages::LoginError, WhatsappMessages::ConnectionError => e
    @encrypted_config.assign_attributes(attrs) if defined?(attrs) && attrs
    @encrypted_config.errors.add(:base, e.message)

    render :index, status: :unprocessable_content
  rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    @encrypted_config.assign_attributes(attrs) if defined?(attrs) && attrs
    @encrypted_config.errors.add(:base, "Error de conexion con WhatsApp: #{e.message}")

    render :index, status: :unprocessable_content
  end

  private

  def load_encrypted_config
    @encrypted_config =
      EncryptedConfig.find_or_initialize_by(account: current_account, key: EncryptedConfig::WHATSAPP_API_KEY)
  end

  def whatsapp_configs
    params.require(:encrypted_config).permit(value: {}).tap do |e|
      previous_value = @encrypted_config.value || {}

      if e[:value]['password'].blank? && previous_value['password'].present?
        e[:value]['password'] = previous_value['password']
      end

      e[:value].compact_blank!

      e[:value]['api_url'] = e[:value]['api_url'].to_s.delete_suffix('/') if e[:value]['api_url'].present?
      e[:value]['country_code'] = e[:value]['country_code'].presence || '504'
    end
  end
end
