# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module WhatsappMessages
  LoginError = Class.new(StandardError)
  SendError = Class.new(StandardError)
  ConfigError = Class.new(StandardError)
  ConnectionError = Class.new(StandardError)

  module_function

  def configured?(account)
    config = encrypted_config(account)

    config.present? &&
      config['api_url'].present? &&
      config['email'].present? &&
      config['password'].present? &&
      config['whatsapp_id'].present?
  end

  def send_message(account:, number:, body:)
    config = encrypted_config(account)

    raise ConfigError, 'WhatsApp no esta configurado.' unless configured?(account)

    token = login(config)
    payload = {
      number: normalize_number(number, config['country_code']),
      body:,
      whatsappId: config['whatsapp_id'].to_i
    }

    response = post_json(config['api_url'], '/api/messages/send-by-number', payload, token:)

    return response if response.is_a?(Net::HTTPSuccess)

    raise SendError, response.body.presence || "Error enviando WhatsApp: #{response.code}"
  end

  def test_connection!(config)
    raise ConfigError, 'Completa todos los datos de WhatsApp.' unless config_present?(config)

    token = login(config)
    response = get_json(config['api_url'], "/whatsapp/#{config['whatsapp_id']}", token:)

    raise ConnectionError, response.body.presence || "Error consultando WhatsApp ID: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    status = data['status'].to_s.downcase

    return true if status.in?(%w[connected open authenticated])

    raise ConnectionError, "El API responde, pero WhatsApp no esta conectado. Estado actual: #{data['status'].presence || 'desconocido'}."
  rescue JSON::ParserError
    raise ConnectionError, 'El API de WhatsApp respondio, pero no devolvio una respuesta valida.'
  end

  def encrypted_config(account)
    EncryptedConfig.find_by(account:, key: EncryptedConfig::WHATSAPP_API_KEY)&.value || {}
  end

  def login(config)
    response = post_json(config['api_url'], '/auth/login', {
                           email: config['email'],
                           password: config['password']
                         })

    raise LoginError, response.body.presence || "Error iniciando sesion WhatsApp: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch('token')
  rescue KeyError, JSON::ParserError
    raise LoginError, 'El API de WhatsApp no devolvio token.'
  end

  def normalize_number(number, country_code = '504')
    digits = number.to_s.gsub(/\D/, '')
    digits = digits.delete_prefix('00')
    country_code = country_code.to_s.gsub(/\D/, '').presence || '504'

    digits.start_with?(country_code) ? digits : "#{country_code}#{digits}"
  end

  def config_present?(config)
    config.present? &&
      config['api_url'].present? &&
      config['email'].present? &&
      config['password'].present? &&
      config['whatsapp_id'].present?
  end

  def post_json(api_url, path, payload, token: nil)
    uri = URI.join("#{api_url.delete_suffix('/')}/", path.delete_prefix('/'))
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{token}" if token.present?
    request.body = payload.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 20, open_timeout: 10) do |http|
      http.request(request)
    end
  end

  def get_json(api_url, path, token:)
    uri = URI.join("#{api_url.delete_suffix('/')}/", path.delete_prefix('/'))
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/json'
    request['Authorization'] = "Bearer #{token}" if token.present?

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 20, open_timeout: 10) do |http|
      http.request(request)
    end
  end
end
