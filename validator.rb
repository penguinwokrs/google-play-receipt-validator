# frozen_string_literal: true

require 'base64'
require 'google/apis/androidpublisher_v3'

module GooglePlayStoreValidator
  class ValidationError < StandardError; end
  BASE_CLASS = Google::Apis::AndroidpublisherV3
  SERVICE_CLASS = BASE_CLASS::AndroidPublisherService
  SCOPE = [BASE_CLASS::AUTH_ANDROIDPUBLISHER].freeze

  class Receipt
    def initialize
      @auth ||= Auth.new
      @client ||= SERVICE_CLASS.new
      @client.authorization = @auth.credentials
    end

    def verify(data)
      response = @client.get_purchase_product(data['packageName'], data['productId'], data['purchaseToken'])
      return VerificationResponse.new(response, bundle_id: data['packageName'], product_id: data['productId']) if response
      raise GooglePlayStoreValidator::ValidationError
    end

    def self.verify(base64_data)
      data = JSON.parse(Base64.decode64(base64_data))
      new.verify(data)
    rescue JSON::ParserError
      raise GooglePlayStoreValidator::ValidationError
    end
  end

  class Auth
    attr_accessor :credentials

    def initialize
      Tempfile.create('json') do |temp|
        temp.write Base64.strict_decode64(Rails.application.secrets.googleplay_service_client)
        temp.rewind
        @credentials ||= Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: temp,
          scope: SCOPE
        )
      end
    end
  end

  class VerificationResponse
    attr_reader :consumption_state
    attr_reader :developer_payload
    attr_reader :kind
    attr_reader :order_id
    attr_reader :purchase_state
    attr_reader :purchase_time_millis
    attr_reader :purchase_type
    attr_reader :bundle_id
    attr_reader :product_id
    attr_reader :original_response

    def initialize(response, options = {})
      @consumption_state = response.consumption_state
      @developer_payload = response.developer_payload
      @kind = response.kind
      @order_id = response.order_id
      @purchase_state = response.purchase_state
      @purchase_time_millis = response.purchase_time_millis
      @purchase_type = response.purchase_type
      @bundle_id = options[:bundle_id]
      @product_id = options[:product_id]
      @original_response = response
    end

    def consumed?
      @consumption_state.zero?
    end

    def purchased?
      @purchase_state.zero?
    end

    def purchase_date
      @purchase_date ||= Time.zone.at(@purchase_time_millis.to_f / 1000)
    end
  end
end
