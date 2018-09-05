require_relative '../lib/recharge_active_record'
require_relative '../lib/async'
require_relative 'application_record'

class Order < ActiveRecord::Base
  include ApplicationRecord
  include Async
  include RechargeActiveRecordInclude
  # The column 'type' uses a reserved word in active record. Calling this class
  # results in:
  #
  # ActiveRecord::SubclassNotFound: The single-table inheritance mechanism
  # failed to locate the subclass: 'CHECKOUT'. This error is raised because the
  # column 'type' is reserved for storing the class in case of inheritance.
  # Please rename this column if you didn't intend it to be used for storing the
  # inheritance class or overwrite Order.inheritance_column to use another
  # column for that information.
  #
  # See: https://stackoverflow.com/questions/17879024/activerecordsubclassnotfound-the-single-table-inheritance-mechanism-failed-to
  # self.inheritance_column = nil
  self.primary_key = :order_id

  has_one :line_items_fixed, class_name: 'OrderLineItemsFixed'
  has_one :line_items_variable, class_name: 'OrderLineItemsVariable'
  has_one :subscription, through: :line_items

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
        local_key: 'order_id',
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
        remote_key: 'address_is_active',
        local_key: 'address_is_active',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'billing_address',
        local_key: 'billing_address',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'charge_id',
        local_key: 'charge_id',
        inbound: identity,
        outbound: to_i,
      },
      {
        remote_key: 'charge_status',
        local_key: 'charge_status',
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
        remote_key: 'customer_id',
        local_key: 'customer_id',
        inbound: identity,
        outbound: to_i,
      },
      {
        remote_key: 'email',
        local_key: 'email',
        inbound: identity,
        outbound: identity,
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
        remote_key: 'is_prepaid',
        local_key: 'is_prepaid',
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
        remote_key: 'payment_processor',
        local_key: 'payment_processor',
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
        remote_key: 'shipped_date',
        local_key: 'shipped_date',
        inbound: to_time,
        outbound: recharge_time,
      },
      {
        remote_key: 'shopify_cart_token',
        local_key: 'shopify_cart_token',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'shopify_id',
        local_key: 'shopify_id',
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
        remote_key: 'shopify_order_number',
        local_key: 'shopify_order_number',
        inbound: identity,
        outbound: to_i,
      },
      {
        remote_key: 'status',
        local_key: 'status',
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
        remote_key: 'transaction_id',
        local_key: 'transaction_id',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'type',
        local_key: 'order_type',
        inbound: identity,
        outbound: identity,
      },
      {
        remote_key: 'updated_at',
        local_key: 'updated_at',
        inbound: to_time,
        outbound: recharge_time,
      },
    ]
  end

  def subscription_id
    line_items.subscription_id
  end

end
