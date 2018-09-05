require_relative '../lib/logging'

module ResqueHelper
  def provide_alt_products(myprod_id, incoming_product_id, subscription_id)
      #Fix this by doing: check current product_id, determine if three-pack true/false
      #use new_product_id and three-pack true/false to get outgoing product_id
      #use outgoing product_id to create the product info: sku, variant_id, product_id, product title
      #and return that hash value to the calling method.

      my_three_pak = SwitchableProduct.find_by_product_id(myprod_id)
      puts "my_three_pak = #{my_three_pak.threepk}"
      puts "my incoming_product_id = #{incoming_product_id}"
      my_outgoing_product = MatchingProduct.where("incoming_product_id = ? and threepk = ?", incoming_product_id,  my_three_pak.threepk).first

      puts "got here"
      puts my_outgoing_product.inspect
      my_outgoing_product_id = my_outgoing_product.outgoing_product_id
      puts "my outgoing_product_id = #{my_outgoing_product_id}"

      my_new_product = AlternateProduct.find_by_product_id(my_outgoing_product_id)
      puts "new product info is #{my_new_product.inspect}"

      #Here I need to check current subscription line item properties. If need be add or modify
      #the product_collection to the chosen product_collection customers switch to.
      my_sub = Subscription.find_by_subscription_id(subscription_id)
      puts my_sub.inspect
      my_line_items = my_sub.raw_line_item_properties
      puts my_line_items.inspect
      found_collection = false

      my_line_items.map do |mystuff|
          #puts "#{key}, #{value}"
          if mystuff['name'] == 'product_collection'
              mystuff['value'] = my_new_product.product_collection
              found_collection = true
          end
      end
      puts "my_line_items = #{my_line_items.inspect}"

      if found_collection == false
           #only if I did not find the product_collection property in the line items do I need to add it
          puts "We are adding the product collection to the line item properties"
          my_line_items << {"name" => "product_collection", "value" => my_new_product.product_collection}

      else
          puts "We have already updated the product_collection value!"
      end


      stuff_to_return = { "sku" => my_new_product.sku, "product_title" => my_new_product.product_title, "shopify_product_id" => my_new_product.product_id, "shopify_variant_id" => my_new_product.variant_id, "properties" => my_line_items }

      return stuff_to_return

  end
  # Internal: returns line_items of orders belonging to the subscription_id argument that
  #           havent been shipped(status=QUEUED) and are scheduled to ship after today/same month
  #
  # myprod_id - product id of the current product collection user is subscribed to
  # new_product_id - product id of the users desired product collection
  def provide_current_orders(myprod_id, subscription_id, new_product_id)
    now = Time.zone.now
    old_product = Product.find_by(shopify_id: myprod_id)
    my_new_product = Product.find_by(shopify_id: new_product_id)
    my_new_variant = EllieVariant.find_by(product_id: new_product_id)
    updated_line_item = []
    sql_query = "SELECT * FROM orders WHERE line_items @> '[{\"subscription_id\": #{subscription_id}}]' AND status = 'QUEUED' AND scheduled_at > '#{now.strftime('%F %T')}' AND scheduled_at < '#{now.end_of_month.strftime('%F %T')}';"
    my_orders = Order.find_by_sql(sql_query)
    my_order_id = ''

    my_orders.each do |temp_order|
      temp_order.line_items.each do |l_item|
        begin
        # include?(my_new_product.title) to only alter line_item properties of product
        # being switched in event customer has multiple products in one order
        # i.e. '3 - Item collection' and 'yoga pant'
        if l_item["product_title"].include?(my_new_product.title)
          puts "current: #{old_product.title} == line_item prod title: #{l_item['product_title']}"
          puts "updating l_item with new: #{my_new_product.title}"
          l_item['shopify_product_id'] = my_new_product.shopify_id
          l_item['shopify_variant_id'] = my_new_variant.variant_id
          l_item['sku'] = my_new_variant.sku
          l_item['product_title'] = my_new_product.title
          l_item['title'] = my_new_product.title

          l_item['properties'].each do |prop|
            if prop['name'] == "product_collection"
              prop['value'] = my_new_product.title
            end
          end
          # l_item['order_id'] custom property added for PUT call params
          # to Recharge orders/order_id in subscription_switch_prepaid worker
          updated_line_item.push(l_item)
        else
          updated_line_item.push(l_item)
        end
        rescue => e
          puts "error: #{e}"
        end
      end
      my_order_id = temp_order.order_id
    end
    puts "PROVIDE CURRENT ORDERS WORKER DONE"
    response_hash = { "my_order_id" => my_order_id,
      "o_array" => updated_line_item }
    return response_hash
  end

  def provide_upgrade_product(new_product_id, subscription_id)
      my_new_product = Product.find_by shopify_id: new_product_id
      puts "(provide_upgrade_products) new product info is #{my_new_product.inspect}"
      #Here I need to check current subscription line item properties. If need be add or modify
      #the product_collection to the chosen product_collection customers switch to.
      my_sub = Subscription.find_by_subscription_id(subscription_id)
      my_variant = EllieVariant.find_by product_id: new_product_id
      puts my_sub.inspect
      my_line_items = my_sub.raw_line_item_properties
      puts my_line_items.inspect
      found_collection = false
      my_line_items.map do |mystuff|
          #puts "#{key}, #{value}"
          if mystuff['name'] == 'product_collection'
              mystuff['value'] = my_new_product.title
              found_collection = true
          end
      end

      puts "my_line_items = #{my_line_items.inspect}"

      if found_collection == false
           #only if I did not find the product_collection property in the line items do I need to add it
          puts "We are adding the product collection to the line item properties"
          my_line_items << {"name" => "product_collection", "value" => my_new_product.title}
      else
          puts "We have already updated the product_collection value!"
      end

      stuff_to_return = { "price" => my_variant.price, "sku" => my_variant.sku, "product_title" => my_new_product.title, "shopify_product_id" => my_new_product.shopify_id, "shopify_variant_id" => my_variant.variant_id, "properties" => my_line_items }
      logger.info "HASH GOING TO RECHARGE: #{stuff_to_return.inspect}"
      return stuff_to_return


  end

  def setup_subscription_update(params)
      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
      logger.info "Got the params #{params.inspect}"

      logger.warn "Deleting information in the subscriptions_updated table"
      subs_delete = "delete from subscriptions_updated"
      subs_reset = "ALTER SEQUENCE subscriptions_updated_id_seq RESTART WITH 1"
      conn.exec(subs_delete)
      conn.exec(subs_reset)
      my_now = Date.today
      my_end_month = my_now.end_of_month
      my_end_month_str = my_end_month.strftime("%Y-%m-%d 23:59:59")
      puts "my_end_month_str = #{my_end_month_str}"
      logger.info "my_end_month_str = #{my_end_month_str}"
      #alt_3pack_prod_id = ENV['ALT_ELLIE_3PACK_PRODUCT_ID']
      #alt_monthly_prod_id = ENV['ALT_MONTHLY_PRODUCT_ID']
      #monthly_box_prod_id = ENV['MONTHLY_PRODUCT_ID']
      #ellie_3pack_prod_id = ENV['ELLIE_3PACK_PRODUCT_ID']
      #logger.info "alt_monthly_prod_id = #{alt_monthly_prod_id}"

      #subs_update = "insert into subscriptions_updated (subscription_id, customer_id, updated_at, next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id) select subscription_id, customer_id, updated_at, next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id from subscriptions where status = 'ACTIVE' and next_charge_scheduled_at > \'#{my_end_month_str}\' and (shopify_product_id = \'#{alt_monthly_prod_id}\' or shopify_product_id = \'#{alt_3pack_prod_id}\' or shopify_product_id = \'#{monthly_box_prod_id}\' or shopify_product_id = \'#{ellie_3pack_prod_id}\')"
      bad_prod_id1 = "10016265938"
      bad_prod_id2 = "10870682450"
      bad_prod_id3 = "44383469586"
      bad_prod_id4 = "820544081"


      subs_update = "insert into subscriptions_updated (subscription_id, customer_id, updated_at, next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id) select subscription_id, customer_id, updated_at, next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id from subscriptions where status = 'ACTIVE' and updated_at > '2017-11-30' and (shopify_product_id = \'#{bad_prod_id1}\' or shopify_product_id = \'#{bad_prod_id2}\' or shopify_product_id = \'#{bad_prod_id3}\' or shopify_product_id = \'#{bad_prod_id4}\')"



      conn.exec(subs_update)
      conn.close
      logger.info "Done setting up subscriptions_updated table!"

  end

  def new_product_properties(my_product_id)
      stuff_to_return = {}
      new_monthly_prod = CurrentProduct.find_by prod_id_key: 'monthly_box_prod_id'
      new_monthly_prod_id = new_monthly_prod.prod_id_value
      new_alt_monthly_prod = CurrentProduct.find_by prod_id_key: 'alt_monthly_prod_id'
      new_alt_monthly_prod_id = new_alt_monthly_prod.prod_id_value
      monthly_product = UpdateProduct.find_by(product_title: 'Power Moves - 5 Item' )
      ellie_3pack = UpdateProduct.find_by(product_title: 'Power Moves - 3 Item' )


      #puts new_ellie_3pack_id

      case my_product_id
      when new_alt_monthly_prod_id
      #customer has monthly box, return Alternate Monthly Box
      stuff_to_return = {"sku" => monthly_product.sku, "product_title" => monthly_product.product_title, "shopify_product_id" => monthly_product.shopify_product_id, "shopify_variant_id" => monthly_product.shopify_variant_id}
      when new_alt3pack_prod_id
      #Customer has Ellie 3- Pack, return Alternate Ellie 3- Pack
      stuff_to_return = {"sku" => ellie_3pack.sku, "product_title" => ellie_3pack.product_title, "shopify_product_id" => ellie_3pack.shopify_product_id, "shopify_variant_id" => ellie_3pack.shopify_variant_id}
      when new_monthly_prod_id
      stuff_to_return = {"sku" => monthly_product.sku, "product_title" => monthly_product.product_title, "shopify_product_id" => monthly_product.shopify_product_id, "shopify_variant_id" => monthly_product.shopify_variant_id}
      when new_ellie_3pack_id
      stuff_to_return = {"sku" => ellie_3pack.sku, "product_title" => ellie_3pack.product_title, "shopify_product_id" => ellie_3pack.shopify_product_id, "shopify_variant_id" => ellie_3pack.shopify_variant_id}
      else
      #Give them the Alt 3-Pack
      stuff_to_return = {"sku" => ellie_3pack.sku, "product_title" => ellie_3pack.product_title, "shopify_product_id" => ellie_3pack.shopify_product_id, "shopify_variant_id" => ellie_3pack.shopify_variant_id}

      end


      return stuff_to_return
  end

  def update_subscription_product(params)
      Resque.logger = Logger.new("#{Dir.getwd}/logs/update_subs_resque.log")
      Resque.logger.info "For updating subscriptions Got params #{params.inspect}"
      my_now = Time.now
      recharge_change_header = params['recharge_change_header']
      Resque.logger.info recharge_change_header

      my_subs = SubscriptionsUpdated.where("updated = ?", false)
      my_subs.each do |sub|
          Resque.logger.info sub.inspect
          #update stuff here
          my_sub_id = sub.subscription_id
          my_product_id = sub.shopify_product_id
          my_body = new_product_properties(my_product_id)
          Resque.logger.info "New Product Properties for subscription_id #{my_sub_id} ==> #{my_body}"
          body = my_body.to_json


          my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{my_sub_id}", :headers => recharge_change_header, :body => body, :timeout => 80)
          puts my_update_sub.inspect
          Resque.logger.info my_update_sub.inspect
          if my_update_sub.code == 200
              sub.updated = true
              time_updated = DateTime.now
              time_updated_str = time_updated.strftime("%Y-%m-%d %H:%M:%S")
              sub.processed_at = time_updated_str
              sub.save


          else
              Resque.logger.warn "WARNING -- COULD NOT UPDATE subscription #{my_sub_id}"
          end
          Resque.logger.info "Sleeping 6 seconds"
          sleep 6
          my_current = Time.now
          duration = (my_current - my_now).ceil
          Resque.logger.info "Been running #{duration} seconds"
          if duration > 480
              Resque.logger.info "Been running more than 8 minutes must exit"
              exit

          end

      end
      Resque.logger.info "All Done, all subscriptions updated!"

  end


end
