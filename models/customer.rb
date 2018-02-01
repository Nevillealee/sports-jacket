require_relative '../lib/recharge_active_record'
require_relative '../lib/async'
require_relative 'application_record'

class Customer < ActiveRecord::Base
  include ApplicationRecord
  include Async
  include RechargeActiveRecordInclude

  self.primary_key = :customer_id

  has_many :subscriptions
  has_many :orders, through: :subscriptions
  has_many :charges

  def self.from_recharge(attributes, *args)
    key_map = { 'hash' => 'customer_hash' }
    remapped = attributes.map { |k, v| [key_map[k] || k, v] }.to_h
    logger.debug remapped
    Customer.new(remapped, *args)
  end

  def self.api_map
    # helper functions
    identity = ->(x) { x }
    to_s = ->(x) { x.to_s }
    to_i = ->(x) { x.to_i }
    recharge_time = ->(time) { time.try(:strftime, '%FT%T') }
    to_time = ->(str) { str.nil? ? nil : Time.parse(str) }
    to_f = ->(x) { x.to_f }
    [
      {
        remote_key: 'id',
        local_key: 'customer_id',
        inbound: identity,
        outbound: to_i,
      },
      {
        remote_key: 'hash',
        local_key: 'customer_hash',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'shopify_customer_id',
        local_key: 'shopify_customer_id',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'email',
        local_key: 'email',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'created_at',
        local_key: 'created_at',
        inbound: to_time,
        outbound: recharge_time,
      },
      {
        remote_key: 'updated_at',
        local_key: 'updated_at',
        inbound: to_time,
        outbound: recharge_time,
      },
      {
        remote_key: 'first_name',
        local_key: 'first_name',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'last_name',
        local_key: 'last_name',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'billing_address1',
        local_key: 'billing_address1',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'billing_address2',
        local_key: 'billing_address2',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'billing_zip',
        local_key: 'billing_zip',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'billing_city',
        local_key: 'billing_city',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'billing_company',
        local_key: 'billing_company',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'billing_province',
        local_key: 'billing_province',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'billing_country',
        local_key: 'billing_country',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'billing_phone',
        local_key: 'billing_phone',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'processor_type',
        local_key: 'processor_type',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'status',
        local_key: 'status',
        inbound: identity,
        outbound: identity,
      },
    ]
  end

  def _as_recharge
    {
      id: customer_id.to_i,
      hash: customer_hash,
      email: email,
      shopify_customer_id: shopify_customer_id,
      created_at: created_at.try(:strftime, '%FT%T'),
      updated_at: created_at.try(:strftime, '%FT%T'),
      first_name: first_name,
      last_name: last_name,
      billing_first_name: first_name,
      billing_last_name: last_name,
      billing_company: billing_company,
      billing_address1: billing_address1,
      billing_address2: billing_address2,
      billing_zip: billing_zip,
      billing_city: billing_city,
      billing_province: billing_province,
      billing_country: billing_country,
      billing_phone: billing_phone,
      processor_type: processor_type
    }
  end
end
