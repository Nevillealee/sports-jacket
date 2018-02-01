require_relative '../lib/recharge_active_record'
require_relative '../lib/async'
require_relative 'application_record'

class Charge < ActiveRecord::Base
  include ApplicationRecord
  include Async
  include RechargeActiveRecordInclude

  self.primary_key = :charge_id

  has_one :shipping_address_assoc, class_name: 'ChargeShippingAddress'
  has_many :shipping_lines, class_name: 'ChargeShippingLine'
  has_and_belongs_to_many :subscriptions, join_table: 'charge_fixed_line_items'
  belongs_to :customer

  before_save :update_subscription_id
  after_save :update_shipping_address_assoc
  after_save :update_shipping_lines

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
        local_key: 'charge_id',
        inbound: identity,
        outbound: to_i,
      },
      {
        remote_key: 'address_id',
        local_key: 'address_id',
        inbound: identity,
        outbound: to_i,
      },
      {
        remote_key: 'billing_address',
        local_key: 'billing_address',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'browser_ip',
        local_key: 'browser_ip',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'client_details',
        local_key: 'client_details',
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
        remote_key: 'customer_hash',
        local_key: 'customer_hash',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'customer_id',
        local_key: 'customer_id',
        inbound: identity,
        outbound: to_i,
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
        remote_key: 'line_items',
        local_key: 'line_items',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'line_items',
        local_key: 'raw_line_items',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'note',
        local_key: 'note',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'note_attributes',
        local_key: 'note_attributes',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'processed_at',
        local_key: 'processed_at',
        inbound: to_time,
        outbound: recharge_time,
      },
      {
        remote_key: 'scheduled_at',
        local_key: 'scheduled_at',
        inbound: to_time,
        outbound: recharge_time,
      },
      {
        remote_key: 'shipments_count',
        local_key: 'shipments_count',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'shipping_address',
        local_key: 'shipping_address',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'shopify_order_id',
        local_key: 'shopify_order_id',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'status',
        local_key: 'status',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'sub_total',
        local_key: 'sub_total',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'sub_total_price',
        local_key: 'sub_total_price',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'tags',
        local_key: 'tags',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'tax_lines',
        local_key: 'tax_lines',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'total_discounts',
        local_key: 'total_discounts',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'total_line_items_price',
        local_key: 'total_line_items_price',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'total_tax',
        local_key: 'total_tax',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'total_weight',
        local_key: 'total_weight',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'total_price',
        local_key: 'total_price',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'updated_at',
        local_key: 'updated_at',
        inbound: to_time,
        outbound: recharge_time,
      },
      {
        remote_key: 'discount_codes',
        local_key: 'discount_codes',
        inbound: identity,
        outbound: identity,
      },
    ].freeze
  end

  def self.by_subscription_id(subscription_id)
    where("line_items @> \'[{\"subscription_id\": #{subscription_id.to_i}}]\'")
  end

  def self.next_scheduled(options = {})
    after = options[:after] || Date.today
    where('scheduled_at > ?', after)
      .order(scheduled_at: :asc)
      .first
  end

  def line_items=(val)
    #logger.debug @attributes
    super(val)
  end

  private

  def update_shipping_address_assoc
  end

  def update_shipping_lines
    return unless raw_shipping_lines_changed?
    raw_shipping_lines
  end

  def update_subscription_id
    subscription_id = line_items.first['subscription_id']
  end
end
