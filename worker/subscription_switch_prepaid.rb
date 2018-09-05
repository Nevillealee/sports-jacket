require_relative 'resque_helper'

class SubscriptionSwitchPrepaid
  extend ResqueHelper
  @queue = "switch_product"

  def self.perform(params)
    puts "SUBSCRIPTIONSWITCHPREPAID BLOCK REACHED"
    puts params.inspect
    Resque.logger = Logger.new("#{Dir.getwd}/logs/prepaid_switch_resque.log")

    subscription_id = params['subscription_id']
    product_id = params['product_id']
    incoming_product_id = params['alt_product_id']
    new_product_id = AlternateProduct.find_by_product_id(params['real_alt_product_id']).product_id
    new_product = Product.find_by(shopify_id: new_product_id)
    new_variant = EllieVariant.find_by(product_id: new_product_id)

    puts "We are working on subscription #{subscription_id}"
    Resque.logger.info("We are working on subscription #{subscription_id}")
    response_hash = provide_current_orders(product_id, subscription_id, new_product_id)
    my_order_array = response_hash['o_array']
    my_order_id = response_hash['my_order_id']
    updated_line_items = []
    Resque.logger.info("new product info for subscription(#{subscription_id})'s orders are: #{my_order_array.inspect}")
    recharge_change_header = params['recharge_change_header']
    puts recharge_change_header

    my_order_array.each do |l_item|
      my_line_item = {
        "quantity" => l_item['quantity'].to_i,
        "product_id" => l_item['shopify_product_id'].to_i,
        "variant_id" => l_item['shopify_variant_id'].to_i,
        "price" => l_item['price'],
        "properties" => l_item['properties'],
        "title" => l_item['product_title'],
        "sku" => l_item['sku'],
        "variant_title" => l_item['variant_title']
      }
      updated_line_items.push(my_line_item)
    end

    my_hash = { "line_items" => updated_line_items }
    body = my_hash.to_json
    my_details = { "sku" => new_variant.sku,
                   "product_title" => new_product.title,
                   "shopify_product_id" => new_product.shopify_id,
                   "shopify_variant_id" => new_variant.variant_id,
                   "properties" => updated_line_items
                 }
    params = { "subscription_id" => subscription_id, "action" => "switching_product", "details" => my_details }
    # When updating line_items, you need to provide all the data that was in
    # line_items before, otherwise only new parameters will remain! (from Recharge docs)
    my_update_sub = HTTParty.put("https://api.rechargeapps.com/orders/#{my_order_id}", :headers => recharge_change_header, :body => body, :timeout => 80)
    puts "MY RECHARGE RESPONSE: #{my_update_sub.parsed_response}"

    Resque.logger.info(my_update_sub.inspect)
    # Below for email to customer
    update_success = false

      if my_update_sub.code == 200
        Resque.enqueue(SendEmailToCustomer, params)
        update_success = true
        puts "****** Hooray We have no errors **********"
        Resque.logger.info("****** Hooray We have no errors **********")
      else
        Resque.enqueue(SendEmailToCS, params)
        puts "We were not able to update the subscription"
        Resque.logger.info("We were not able to update the subscription")
      end

  end
end
