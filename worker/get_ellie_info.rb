#FAMBrands download subscription
#get_ellie_info.rb

require_relative 'worker_helper'
require_relative 'resque_helper'
require_relative '../lib/logging'

class Object
  include Logging
end

module DetermineInfo
  class InfoGetter
    include Logging

    def initialize
      recharge_regular = ENV['RECHARGE_ACCESS_TOKEN']
      @sleep_recharge = ENV['RECHARGE_SLEEP_TIME']
      @my_header = {
        "X-Recharge-Access-Token" => recharge_regular
      }
      @my_change_charge_header = {
        "X-Recharge-Access-Token" => recharge_regular,
        "Accept" => "application/json",
        "Content-Type" =>"application/json"
      }
      @uri = URI.parse(ENV['DATABASE_URL'])
      @conn = PG.connect(@uri.hostname, @uri.port, nil, nil, @uri.path[1..-1], @uri.user, @uri.password)
      @shopify_base_site = "https://#{ENV['SHOPIFY_API_KEY']}:#{ENV['SHOPIFY_SHARED_SECRET']}@#{ENV['SHOPIFY_SHOP_NAME']}.myshopify.com/admin"
    end

    def count_subscriptions
      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)

      my_insert = "insert into subscriptions (subscription_id, address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, cancelled_at, product_title, price, quantity, status, shopify_product_id, shopify_variant_id, sku, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, raw_line_item_properties) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)"
      conn.prepare('statement1', "#{my_insert}")
      my_line_item_insert = "insert into sub_line_items (subscription_id, name, value) values ($1, $2, $3)"
      conn.prepare('statement2', "#{my_line_item_insert}")

      response = HTTParty.get("https://api.rechargeapps.com/subscriptions/count", :headers => @my_header)
      my_response = JSON.parse(response)
      my_count = my_response['count'].to_i
      logger.info "We have #{my_count} subscriptions"
      my_temp_array = Array.new

      page_size = 250
      num_pages = (my_count/page_size.to_f).ceil
      1.upto(num_pages) do |page|
        mysubs = HTTParty.get("https://api.rechargeapps.com/subscriptions?limit=250&page=#{page}", :headers => @my_header)
        local_sub = mysubs['subscriptions']
        local_sub.each do |sub|
          if !sub['properties'].nil? && sub['properties'] != []
            logger.debug sub.inspect
            id = sub['id']
            address_id = sub['address_id']
            customer_id = sub['customer_id']
            created_at = sub['created_at']
            updated_at = sub['updated_at']
            #handle nils for these
            next_charge_scheduled_at = sub['next_charge_scheduled_at']
            cancelled_at = sub['cancelled_at']


            product_title = sub['product_title']
            variant_title = sub['variant_title']
            price = sub['price']
            quantity = sub['quantity']
            shopify_product_id = sub['shopify_product_id']
            shopify_variant_id = sub['shopify_variant_id']
            sku = sub['sku']
            status = sub['status']
            order_interval_unit = sub['order_interval_unit']
            order_interval_frequency  = sub['order_interval_frequency']
            charge_interval_frequency = sub['charge_interval_frequency']
            cancellation_reason = sub['cancellation_reason']

            order_day_of_week = sub['order_day_of_week']

            order_day_of_month = sub['order_day_of_month']

            properties  = sub['properties'].to_json
            conn.exec_prepared('statement1', [id, address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, cancelled_at, product_title, price, quantity, status, shopify_product_id, shopify_variant_id, sku, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, properties ])


            logger.debug sub['properties'].inspect
            my_temp_array = sub['properties']
            my_temp_array.each do |temp|
              temp_name = temp['name']
              temp_value = temp['value']
              logger.debug "#{temp_name}, #{temp_value}"
              conn.exec_prepared('statement2', [id, temp_name, temp_value])
            end
          end
        end
        logger.info "Done with page #{page}"
        logger.info "Sleeping #{@sleep_recharge}"
        sleep @sleep_recharge.to_i
      end
      conn.close


    end

    def update_line_item_properties
      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
      my_query = "select subscription_id from subscriptions"

      my_properties_insert = "insert into update_line_items (subscription_id, properties) values ($1, $2)"
      conn.prepare('statement1', "#{my_properties_insert}")
      result_set = conn.exec(my_query)
      result_set.each do |row|
        sports_jacket_present = false
        temp_jacket_size = ""
        temp_property_array = Array.new
        sub_id = row['subscription_id']
        logger.debug "InfoGetter#update_line_item_properties sub_id: #{sub_id}"
        my_properties = "select name, value from sub_line_items where subscription_id = \'#{sub_id}\'"
        properties_result = conn.exec(my_properties)
        properties_result.each do |myrow|
          myname = myrow['name']
          myvalue = myrow['value']

          logger.debug "#{myname}, #{myvalue}"
          local_json_string = {"name" => myname, "value" => myvalue}
          temp_property_array << local_json_string
          if myname == "sports-jacket"
            sports_jacket_present = true
          end
          if myname == "tops"
            temp_jacket_size = myvalue
            logger.debug "found temp_jacket_size! #{temp_jacket_size}"
          end




        end
        logger.info "sportsjacket = #{sports_jacket_present}, size = #{temp_jacket_size}"
        if !sports_jacket_present && temp_jacket_size != ""
          temp_jacket_properties = {"name" => "sports-jacket", "value" => temp_jacket_size}
          temp_property_array << temp_jacket_properties
          json_data = {"properties" => temp_property_array}.to_json
          logger.debug "InfoGetter#update_line_item_properties json_data: #{json_data.inspect}"
          #insert temp_property_array into update table
          conn.exec_prepared('statement1', [sub_id, json_data])
        end

      end
      conn.close
    end

    def delete_tables
      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)

      my_subscription_delete = "delete from subscriptions"
      my_sub_line_items_delete = "delete from sub_line_items"
      my_update_line_items = "delete from update_line_items"
      conn.exec(my_subscription_delete)
      conn.exec(my_sub_line_items_delete)
      conn.exec(my_update_line_items)
      logger.info "all done deleting subscriptions, sub_line_items, and update_line_items tables"
    end

    def testing_customer_yesterday_pull

      #GET /orders?created_at_min=2016-05-18&created_at_max=2016-06-18


      customer_count = HTTParty.get("https://api.rechargeapps.com/customers/count?updated_at_min=2017-10-06", :headers => @my_header)
      my_count = customer_count.parsed_response
      logger.debug my_count.inspect


    end


    def test_update_justin_sub

      #test subscription_id to change properties
      local_subscription_id = "5362230"
      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
      my_query = "select * from update_line_items where subscription_id = \'#{local_subscription_id}\'"
      result = conn.exec(my_query)
      result.each do |row|
        local_properties = row['properties']
        logger.debug local_properties

        property_change_recharge = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{local_subscription_id}", :headers => @my_change_charge_header, :body => local_properties)
        logger.debug property_change_recharge.inspect
      end
      logger.info "all done with test updade for justin subscription #{local_subscription_id}"
    end

    def update_subscription_sports_jacket
      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
      my_query = "select * from update_line_items where updated = \'f\'"
      result = conn.exec(my_query)
      start_time = Time.now
      result.each do |row|
        subscription_id = row['subscription_id']
        properties = row['properties']
        logger.debug "#{subscription_id}, #{properties}"
        begin
          property_change_recharge = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => @my_change_charge_header, :body => properties)

        rescue StandardError => exception
          logger.error "We can't process id #{subscription_id}"
        else
          #mark processed to true
          my_update = "update update_line_items set updated = \'t\'  where subscription_id = \'#{subscription_id}\'"
          conn.exec(my_update)
        ensure
          logger.info "Done with this record"
        end
        end_time = Time.now
        duration = (end_time - start_time).ceil
        logger.info "running #{duration} seconds"
        if duration > 480
          logger.error "We have been running #{duration} seconds, must exit"
          exit
        end
      end

    end

    def sub_testing
      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
      my_query = "select subscription_id as sub_id, raw_line_item_properties from subscriptions"
      result = conn.exec(my_query)
      result.each do |row|
        line_item = eval(row['raw_line_item_properties'])
        line_item.each do |myitem|
          temp_item = myitem.to_h
          if temp_item.has_value?("tops")
            logger.debug temp_item
          end

        end

      end

    end


    def retrieve_sub
      #7508212
      #7507789
      my_sub_id = 7508212
      #GET /subscriptions/<subscription_id>
      response = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{my_sub_id}", :headers => @my_header)
      subs = response.parsed_response
      logger.debug subs.inspect



    end

    def count_charges
      #GET /charges/count
      charge_count = HTTParty.get("https://api.rechargeapps.com/charges/count", :headers => @my_header)
      my_count = charge_count.parsed_response
      num_charges = my_count['count'].to_i
      logger.info "Number of charges is #{num_charges}"
      return num_charges
    end

    def insert_charges_into_db
      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)

      my_insert = "insert into charges (address_id, billing_address, client_details, created_at, customer_hash, customer_id, first_name, charge_id, last_name, line_items, note, note_attributes, processed_at, scheduled_at, shipments_count, shipping_address, shopify_order_id, status, sub_total, sub_total_price, tags, tax_lines, total_discounts, total_line_items_price, total_tax, total_weight, total_price, updated_at, discount_codes) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29)"
      conn.prepare('statement1', "#{my_insert}")

      my_insert_billing = "insert into charge_billing_address (address1, address2, city, company, country, first_name, last_name, phone, province, zip, charge_id) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)"
      conn.prepare('statement2', "#{my_insert_billing}")

      my_insert_client_details = "insert into charge_client_details (charge_id, browser_ip, user_agent) values ($1, $2, $3)"
      conn.prepare('statement3', "#{my_insert_client_details}")

      my_insert_fixed_line_items = "insert into charge_fixed_line_items (charge_id, grams, price, quantity, shopify_product_id, shopify_variant_id, sku, subscription_id, title, variant_title, vendor) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)"
      conn.prepare('statement4', "#{my_insert_fixed_line_items}")

      my_insert_variable_line_items = "insert into charge_variable_line_items (charge_id, name, value) values ($1, $2, $3)"
      conn.prepare('statement5', "#{my_insert_variable_line_items}")

      my_insert_charges_shipping_address = "insert into charges_shipping_address (charge_id, address1, address2, city, company, country, first_name, last_name, phone, province, zip) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)"
      conn.prepare('statement6', "#{my_insert_charges_shipping_address}")

      my_insert_charges_shipping_lines = "insert into charges_shipping_lines (charge_id, code, price, source, title, tax_lines, carrier_identifier, request_fulfillment_service_id) values ($1, $2, $3, $4, $5, $6, $7, $8)"
      conn.prepare('statement7', "#{my_insert_charges_shipping_lines}")


      charge_number = count_charges
      logger.debug "charge number: #{charge_number}"
      start = Time.now
      page_size = 250
      num_pages = (charge_number/page_size.to_f).ceil
      1.upto(num_pages) do |page|
        charges = HTTParty.get("https://api.rechargeapps.com/charges?limit=250&page=#{page}", :headers => @my_header)
        my_charges = charges.parsed_response['charges']
        my_charges.each do |charge|
          logger.debug "#{'#' * 5} CHARGE #{'#' * 35}\n#{charge.inspect}"
          # insert into database tables
          address_id = charge['address_id']
          raw_billing_address = charge['billing_address']
          billing_address = charge['billing_address'].to_json
          billing_address1 = raw_billing_address['address1']
          billing_address2 = raw_billing_address['address2']
          billing_address_city = raw_billing_address['city']
          billing_address_company = raw_billing_address['company']
          billing_address_country = raw_billing_address['country']
          billing_address_first_name = raw_billing_address['first_name']
          billing_address_last_name = raw_billing_address['last_name']
          billing_address_phone = raw_billing_address['phone']
          billing_address_province = raw_billing_address['province']
          billing_address_zip = raw_billing_address['zip']



          client_details = charge['client_details'].to_json
          raw_client_details = charge['client_details']
          browser_ip = raw_client_details['browser_ip']
          user_agent = raw_client_details['user_agent']



          created_at = charge['created_at']
          customer_hash = charge['customer_hash']
          customer_id = charge['customer_id']
          discount_codes = charge['discount_codes'].to_json
          first_name = charge['first_name']
          charge_id = charge['id']
          #insert charge_billing_address sub-table
          conn.exec_prepared('statement2', [billing_address1, billing_address2, billing_address_city, billing_address_company, billing_address_country, billing_address_first_name, billing_address_last_name, billing_address_phone, billing_address_province, billing_address_zip, charge_id ])

          conn.exec_prepared('statement3', [charge_id, browser_ip, user_agent])


          last_name = charge['last_name']
          line_items = charge['line_items'].to_json
          raw_line_items = charge['line_items'][0]
          raw_line_items['properties'].each do |myitem|
            logger.debug "InfoGetter#insert_orders_into_db line item: #{myitem}"
            myname = myitem['name']
            myvalue = myitem['value']
            if myvalue == ""
              myvalue = nil
            end
            logger.info "Inserting charge #{charge_id}: #{myname} -> #{myvalue}"
            conn.exec_prepared('statement5', [charge_id, myname, myvalue])
          end

          grams = raw_line_items['grams']
          price = raw_line_items['price']
          if grams.nil?
            grams = 0
          else
            grams = grams.to_i
          end
          if price.nil?
            price = 0.0
          else
            price = price.to_f
            price = price.round(2)
          end

          quantity = raw_line_items['quantity']
          shopify_product_id = raw_line_items['shopify_product_id']
          shopify_variant_id = raw_line_items['shopify_variant_id']
          sku = raw_line_items['sku']
          subscription_id = raw_line_items['subscription_id']
          title = raw_line_items['title']
          variant_title = raw_line_items['variant_title']
          vendor = raw_line_items['vendor']

          conn.exec_prepared('statement4', [charge_id, grams, price, quantity, shopify_product_id, shopify_variant_id, sku, subscription_id, title, variant_title, vendor])


          note = charge['note']
          note_attributes = charge['note_attributes'].to_json
          processed_at = charge['processed_at']
          scheduled_at = charge['scheduled_at']
          shipments_count = charge['shipments_count']
          shipping_address = charge['shipping_address'].to_json
          raw_shipping_address = charge['shipping_address']
          sa_address1 = raw_shipping_address['address1']
          sa_address2 = raw_shipping_address['address2']
          sa_city = raw_shipping_address['city']
          sa_company = raw_shipping_address['company']
          sa_country = raw_shipping_address['country']
          sa_first_name = raw_shipping_address['first_name']
          sa_last_name = raw_shipping_address['last_name']
          sa_phone = raw_shipping_address['phone']
          sa_province = raw_shipping_address['province']
          sa_zip = raw_shipping_address['zip']
          conn.exec_prepared('statement6', [charge_id, sa_address1, sa_address2, sa_city, sa_company, sa_country, sa_first_name, sa_last_name, sa_phone, sa_province, sa_zip])

          shipping_lines = charge['shipping_lines'][0]
          if !shipping_lines.nil?
            sl_code = shipping_lines['code']
            sl_price = shipping_lines['price'].to_f
            sl_price = sl_price.round(2)
            sl_source = shipping_lines['source']
            sl_title = shipping_lines['title']
            sl_tax_lines = shipping_lines['tax_lines'].to_json
            sl_carrier_identifier = shipping_lines['carrier_identifier']
            sl_request_fulfillment_service_id = shipping_lines['request_fulfillment_service_id']
            conn.exec_prepared('statement7', [charge_id, sl_code, sl_price, sl_source, sl_title, sl_tax_lines, sl_carrier_identifier, sl_request_fulfillment_service_id])
          end


          shopify_order_id = charge['shopify_order_id']
          status = charge['status']
          sub_total = charge['sub_total']
          sub_total_price = charge['sub_total_price']
          tags = charge['tags']
          tax_lines = charge['tax_lines']
          total_discounts = charge['total_discounts']
          total_line_items_price = charge['total_line_items_price']
          total_tax = charge['total_tax']
          total_weight = charge['total_weight']
          total_price = charge['total_price']
          updated_at = charge['updated_at']

          conn.exec_prepared('statement1', [ address_id, billing_address, client_details, created_at, customer_hash, customer_id, first_name, charge_id, last_name, line_items, note, note_attributes, processed_at, scheduled_at, shipments_count, shipping_address, shopify_order_id, status, sub_total, sub_total_price, tags, tax_lines, total_discounts, total_line_items_price, total_tax, total_weight, total_price, updated_at,  discount_codes ])




        end

        my_end = Time.now
        duration = (my_end - start).ceil
        logger.info "running #{duration} seconds"
        logger.info "done with page #{page}"
        logger.info "Sleeping #{@sleep_recharge}"
        sleep @sleep_recharge.to_i

      end
      logger.info "All done with charges"
      logger.info "Ran #{(Time.now - start).ceil} seconds"
      conn.close

    end


    def delete_tables2
      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)

      my_subscription_delete = "delete from subscriptions"
      my_sub_line_items_delete = "delete from sub_line_items"
      my_update_line_items = "delete from update_line_items"
      #conn.exec(my_subscription_delete)
      #conn.exec(my_sub_line_items_delete)
      #conn.exec(my_update_line_items)

      my_charge_delete = "delete from charges"
      my_reset_sequence = "ALTER SEQUENCE charges_id_seq RESTART WITH 1"
      conn.exec(my_charge_delete)
      conn.exec(my_reset_sequence)
      my_charge_billing_address_delete = "delete from charge_billing_address"
      my_charge_billing_address_reset = "ALTER SEQUENCE charge_billing_address_id_seq RESTART WITH 1"
      conn.exec(my_charge_billing_address_delete)
      conn.exec(my_charge_billing_address_reset)
      my_charge_client_details_delete = "delete from charge_client_details"
      my_charge_client_details_reset = "ALTER SEQUENCE charge_client_details_id_seq RESTART WITH 1"
      conn.exec(my_charge_client_details_delete)
      conn.exec(my_charge_client_details_reset)
      my_charge_fixed_line_items_delete = "delete from charge_fixed_line_items"
      my_charge_fixed_line_items_reset = "ALTER SEQUENCE charge_fixed_line_items_id_seq RESTART WITH 1"
      conn.exec(my_charge_fixed_line_items_delete)
      conn.exec(my_charge_fixed_line_items_reset)
      my_charge_variable_line_items_delete = "delete from charge_variable_line_items"
      my_charge_variable_line_items_reset = "ALTER SEQUENCE charge_fixed_line_items_id_seq RESTART WITH 1"
      conn.exec(my_charge_variable_line_items_delete)
      conn.exec(my_charge_variable_line_items_reset)
      my_charges_shipping_address_delete = "delete from charges_shipping_address"
      my_charges_shipping_address_reset = "ALTER SEQUENCE charges_shipping_address_id_seq RESTART WITH 1"
      conn.exec(my_charges_shipping_address_delete)
      conn.exec(my_charges_shipping_address_reset)
      my_charges_shipping_lines_delete = "delete from charges_shipping_lines"
      my_charges_shipping_lines_reset = "ALTER SEQUENCE charges_shipping_lines_id_seq RESTART WITH 1"
      conn.exec(my_charges_shipping_lines_delete)
      conn.exec(my_charges_shipping_lines_reset)
      my_orders_delete = "delete from orders"
      my_orders_reset = "ALTER SEQUENCE orders_id_seq RESTART WITH 1"
      conn.exec(my_orders_delete)
      conn.exec(my_orders_reset)
      my_orders_line_item_fixed_delete = "delete from order_line_items_fixed"
      my_orders_line_item_fixed_reset = "ALTER SEQUENCE order_line_items_fixed_id_seq RESTART WITH 1"
      conn.exec(my_orders_line_item_fixed_delete)
      conn.exec(my_orders_line_item_fixed_reset)
      my_orders_line_item_variable_delete = "delete from order_line_items_variable"
      my_orders_line_item_variable_reset = "ALTER SEQUENCE order_line_items_variable_id_seq RESTART WITH 1"
      conn.exec(my_orders_line_item_variable_delete)
      conn.exec(my_orders_line_item_variable_reset)
      my_orders_shipping_delete = "delete from order_shipping_address"
      my_orders_shipping_reset = "ALTER SEQUENCE order_shipping_address_id_seq RESTART WITH 1"
      conn.exec(my_orders_shipping_delete)
      conn.exec(my_orders_shipping_reset)
      my_orders_billing_delete = "delete from order_billing_address"
      my_orders_billing_reset = "ALTER SEQUENCE order_billing_address_id_seq RESTART WITH 1"
      conn.exec(my_orders_billing_delete)
      conn.exec(my_orders_billing_reset)
      customers_delete = "delete from customers"
      customers_reset = "ALTER SEQUENCE customers_id_seq RESTART WITH 1"
      conn.exec(customers_delete)
      conn.exec(customers_reset)






      logger.info "all done deleting subscriptions, sub_line_items, and update_line_items tables"

    end

    def get_three_months_ago
      my_today = Date.today
      first_month = my_today.beginning_of_month
      first_month_three_months_ago = first_month << 3
      created_at_min = first_month_three_months_ago.strftime("%Y-%m-%d")
      return created_at_min

    end

    def count_orders
      created_at_min = get_three_months_ago
      #GET /orders/count?created_at_min='2015-01-01'&created_at_max='2017-02-02'
      order_count = HTTParty.get("https://api.rechargeapps.com/orders/count?created_at_min=\'#{created_at_min}\'", :headers => @my_header)
      my_count = order_count.parsed_response
      my_count = JSON.parse(my_count)
      num_orders = my_count['count'].to_i
      return num_orders


    end

    def insert_orders_into_db

      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)

      my_insert = "insert into orders (order_id, transaction_id, charge_status, payment_processor, address_is_active, status, order_type, charge_id, address_id, shopify_id, shopify_order_id, shopify_order_number, shopify_cart_token, shipping_date, scheduled_at, shipped_date, processed_at, customer_id, first_name, last_name, is_prepaid, created_at, updated_at, email, line_items, total_price, shipping_address, billing_address) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28)"
      conn.prepare('statement1', "#{my_insert}")

      my_order_line_fixed_insert = "insert into order_line_items_fixed (order_id, shopify_variant_id, title, variant_title, subscription_id, quantity, shopify_product_id, product_title) values ($1, $2, $3, $4, $5, $6, $7, $8)"
      conn.prepare('statement2', "#{my_order_line_fixed_insert}")

      my_order_line_variable_insert = "insert into order_line_items_variable (order_id, name, value) values ($1, $2, $3)"
      conn.prepare('statement3', "#{my_order_line_variable_insert}")

      my_order_shipping_insert = "insert into order_shipping_address (order_id, province, city, first_name, last_name, zip, country, address1, address2, company, phone) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)"
      conn.prepare('statement4', "#{my_order_shipping_insert}")

      my_order_billing_insert = "insert into order_billing_address (order_id, province, city, first_name, last_name, zip, country, address1, address2, company, phone) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)"
      conn.prepare('statement5', "#{my_order_billing_insert}")


      number_orders = count_orders
      logger.info "Total order count: #{number_orders}"
      created_at_min = get_three_months_ago
      start = Time.now
      page_size = 250
      num_pages = (number_orders/page_size.to_f).ceil
      1.upto(num_pages) do |page|
        orders = HTTParty.get("https://api.rechargeapps.com/orders?created_at_min=\'#{created_at_min}\'&limit=250&page=#{page}", :headers => @my_header)
        my_orders = orders.parsed_response['orders']
        my_orders.each do |order|
          logger.debug "#{'#' * 5} ORDER #{'#' * 35}\n#{order.inspect}"
          order.each do |myord|
            logger.debug "InfoGetter#insert_orders_into_db myord: #{myord.inspect}"
          end
          order_id = order['id']
          transaction_id = order['id']
          charge_status = order['charge_status']
          payment_processor = order['payment_processor']
          address_is_active = order['address_is_active'].to_i
          status = order['status']
          type = order['type']
          charge_id = order['charge_id']
          address_id = order['address_id']
          shopify_id = order['shopify_id']
          shopify_order_id = order['shopify_order_id']
          shopify_order_number = order['shopify_order_number']
          shopify_cart_token = order['shopify_cart_token']
          shipping_date = order['shipping_date']
          scheduled_at = order['scheduled_at']
          shipped_date = order['shipped_date']
          processed_at = order['processed_at']
          customer_id = order['customer_id']
          first_name = order['first_name']
          last_name = order['last_name']
          is_prepaid = order['is_prepaid'].to_i
          created_at = order['created_at']
          updated_at = order['updated_at']
          email = order['email']
          line_items = order['line_items'].to_json
          raw_line_items = order['line_items'][0]

          shopify_variant_id = raw_line_items['shopify_variant_id']
          title = raw_line_items['title']
          variant_title = raw_line_items['variant_title']
          subscription_id = raw_line_items['subscription_id']
          quantity = raw_line_items['quantity'].to_i
          shopify_product_id = raw_line_items['shopify_product_id']
          product_title = raw_line_items['product_title']
          conn.exec_prepared('statement2', [ order_id, shopify_variant_id, title, variant_title, subscription_id, quantity, shopify_product_id, product_title ])


          variable_line_items = raw_line_items['properties']
          variable_line_items.each do |myprop|
            myname = myprop['name']
            myvalue = myprop['value']
            conn.exec_prepared('statement3', [ order_id, myname, myvalue ])
          end



          total_price = order['total_price']
          shipping_address = order['shipping_address'].to_json
          billing_address = order['billing_address'].to_json

          #insert shipping_address sub table
          raw_shipping_address = order['shipping_address']
          ord_ship_province = raw_shipping_address['province']
          ord_ship_city = raw_shipping_address['city']
          ord_ship_first_name = raw_shipping_address['first_name']
          ord_ship_last_name = raw_shipping_address['last_name']
          ord_ship_zip = raw_shipping_address['zip']
          ord_ship_country = raw_shipping_address['country']
          ord_ship_address1 = raw_shipping_address['address1']
          ord_ship_address2 = raw_shipping_address['address2']
          ord_ship_company = raw_shipping_address['company']
          ord_ship_phone = raw_shipping_address['phone']
          conn.exec_prepared('statement4', [ order_id, ord_ship_province, ord_ship_city, ord_ship_first_name, ord_ship_last_name, ord_ship_zip, ord_ship_country, ord_ship_address1, ord_ship_address2, ord_ship_company, ord_ship_phone ])

          #insert billing_address sub table
          raw_billing_address = order['billing_address']
          ord_bill_province = raw_billing_address['province']
          ord_bill_city = raw_billing_address['city']
          ord_bill_first_name = raw_billing_address['first_name']
          ord_bill_last_name = raw_billing_address['last_name']
          ord_bill_zip = raw_billing_address['zip']
          ord_bill_country = raw_billing_address['country']
          ord_bill_address1 = raw_billing_address['address1']
          ord_bill_address2 = raw_billing_address['address2']
          ord_bill_company = raw_billing_address['company']
          ord_bill_phone = raw_billing_address['phone']
          conn.exec_prepared('statement5', [ order_id, ord_bill_province, ord_bill_city, ord_bill_first_name, ord_bill_last_name, ord_bill_zip, ord_bill_country, ord_bill_address1, ord_bill_address2, ord_bill_company, ord_bill_phone ])

          #insert into orders
          conn.exec_prepared('statement1', [order_id, transaction_id, charge_status, payment_processor, address_is_active, status, order_type, charge_id, address_id, shopify_id, shopify_order_id, shopify_order_number, shopify_cart_token, shipping_date, scheduled_at, shipped_date, processed_at, customer_id, first_name, last_name, is_prepaid, created_at, updated_at, email, line_items, total_price, shipping_address, billing_address])


        end
        logger.info "Done with page #{page}"
        current = Time.now
        duration = (current - start).ceil
        logger.info "Been running #{duration} seconds"
        logger.info "Sleeping #{@sleep_recharge}"
        sleep @sleep_recharge.to_i

      end
      conn.close


    end

    def count_customers
      #GET /customers/count
      customer_count = HTTParty.get("https://api.rechargeapps.com/customers/count", :headers => @my_header)
      my_count = customer_count.parsed_response
      num_customers = my_count['count'].to_i
      return num_customers
    end

    class PullProducts
      include Logging
      extend EllieHelper
      @queue = "pull_products"

      def self.perform(params)
        logger.debug "PullProducts#perform params: #{params.inspect}"
        get_ellie_data(params)
      end
    end

    class PullCustomCollections
      include Logging
      extend EllieHelper
      @queue = "pull_custom_collections"

      def self.perform(params)
        logger.debug "PullCustomCollections#perform params: #{params.inspect}"
        get_ellie_data(params)
      end
    end

    class PullCollects
      include Logging
      extend EllieHelper
      @queue = "pull_collects"

      def self.perform(params)
        logger.debug "PullCollects#perform params: #{params.inspect}"
        get_ellie_data(params)
      end
    end

    def handle_ellie(option)
      params = {"option_value" => option, "connection" => @uri, "shopify_base_site" => @shopify_base_site, "header_info" => @my_header, "sleep_recharge" => @sleep_recharge}
      case option
      when "products"
        logger.info "Doing full pull of products"
        logger.debug "handle_ellie uri: #{@uri.inspect}"
        Resque.enqueue(PullProducts, params)
      when "collects"
        logger.info "Doing full pull of collects"
        logger.debug "handle_ellie uri: #{@uri.inspect}"
        Resque.enqueue(PullCollects, params)
      when "custom_collections"
        logger.info "Doing full pull of custom_collections"
        logger.debug "handle_ellie uri: #{@uri.inspect}"
        Resque.enqueue(PullCustomCollections, params)
      else
        logger.error "sorry, cannot understand option #{option}, doing nothing."
      end
      
    end

    def insert_customers_into_db
      num_customers = count_customers
      logger.info "We have #{num_customers} customers"

      uri = URI.parse(ENV['DATABASE_URL'])
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)

      my_insert = "insert into customers (customer_id, customer_hash, shopify_customer_id, email, created_at, updated_at, first_name, last_name, billing_address1, billing_address2, billing_zip, billing_city, billing_company, billing_province, billing_country, billing_phone, processor_type, status) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)"
      conn.prepare('statement1', "#{my_insert}")

      start = Time.now
      page_size = 250
      num_pages = (num_customers/page_size.to_f).ceil
      1.upto(num_pages) do |page|
        customers = HTTParty.get("https://api.rechargeapps.com/customers?limit=250&page=#{page}", :headers => @my_header)
        my_customers = customers.parsed_response['customers']
        my_customers.each do |mycust|
          logger.debug "#{'#' * 5} CUSTOMER #{'#' * 35}\n#{mycust.inspect}"
          customer_id = mycust['id']
          hash = mycust['hash']
          shopify_customer_id = mycust['shopify_customer_id']
          email = mycust['email']
          created_at = mycust['created_at']
          updated_at = mycust['updated_at']
          first_name = mycust['first_name']
          last_name = mycust['last_name']
          billing_address1 = mycust['billing_address1']
          billing_address2 = mycust['billing_address2']
          billing_zip = mycust['billing_zip']
          billing_city = mycust['billing_city']
          billing_company = mycust['billing_company']
          billing_province = mycust['billing_province']
          billing_country = mycust['billing_country']
          billing_phone = mycust['billing_phone']
          processor_type = mycust['processor_type']
          status = mycust['status']
          conn.exec_prepared('statement1', [customer_id, hash, shopify_customer_id, email, created_at, updated_at, first_name, last_name, billing_address1, billing_address2, billing_zip, billing_city, billing_company, billing_province, billing_country, billing_phone, processor_type, status])



        end
        logger.info "Done with page #{page}"
        current = Time.now
        duration = (current - start).ceil
        logger.info "Running #{duration} seconds"
        logger.info "Sleeping #{@sleep_recharge}"
        sleep @sleep_recharge.to_i



      end
      logger.info "All done inserting orders"



    end

    def handle_customers(option)
      params = {"option_value" => option, "connection" => @uri, "header_info" => @my_header, "sleep_recharge" => @sleep_recharge}
      if option == "full_pull"
        logger.info "Doing full pull of customers"
        #delete tables and do full pull
        logger.debug "handle_customers uri: #{@uri.inspect}"

        Resque.enqueue(PullCustomer, params)

      elsif option == "yesterday"
        logger.info "Doing partial pull of customers since yesterday"
        #params = {"option_value" => option, "connection" => @uri}
        Resque.enqueue(PullCustomer, params)
      else
        logger.error "sorry, cannot understand option #{option}, doing nothing."
      end

    end

    class PullCustomer
      extend EllieHelper
      include Logging
      @queue = "pull_customer"
      def self.perform(params)
        logger.debug "PullCustomer#perform params: #{params.inspect}"
        get_customers_full(params)

      end

    end

    def handle_shopify_customers(option)
      params = {"option_value" => option, "connection" => @uri, "shopify_base" => @shopify_base_site, "sleep_shopify" => @sleep_shopify}
      if option == "full_pull"
        logger.info "Doing full pull of shopify customers"
        #delete tables and do full pull
        logger.debug "handle_shopify_customers uri: #{@uri.inspect}"
        Resque.enqueue(PullShopifyCustomer, params)
      elsif option == "yesterday"
        logger.info "Doing partial pull of shopify customers since yesterday"
        #params = {"option_value" => option, "connection" => @uri}
        Resque.enqueue(PullShopifyCustomer, params)
      else
        logger.error "sorry, cannot understand option #{option}, doing nothing."
      end

    end

    class PullShopifyCustomer
      extend EllieHelper
      include Logging
      @queue = "pull_shopify_customer"

      def self.perform(params)
        logger.debug "PullShopifyCustomer#perform params: #{params.inspect}"
        get_shopify_customers_full(params)
      end

    end

    def handle_charges(option)
      params = {"option_value" => option, "connection" => @uri, "header_info" => @my_header, "sleep_recharge" => @sleep_recharge}
      if option == "full_pull"
        logger.info "Doing full pull of charge table and associated charge tables"
        #delete tables and do full pull

        Resque.enqueue(PullCharge, params)

      elsif option == "yesterday"
        logger.info "Doing partial pull of charge table and associated tables since yesterday"
        #params = {"option_value" => option, "connection" => @uri}
        Resque.enqueue(PullCharge, params)
      else
        logger.error "sorry, cannot understand option #{option}, doing nothing."
      end
    end


    class PullCharge
      extend EllieHelper
      include Logging

      @queue = "pull_charge"
      def self.perform(params)
        logger.debug "PullCharge#perform params: #{params.inspect}"
        get_charge_full(params)
      end
    end

    def handle_orders(option)
      params = {"option_value" => option, "connection" => @uri, "header_info" => @my_header, "sleep_recharge" => @sleep_recharge}
      if option == "full_pull"
        logger.info "Doing full pull of orders table and associated order tables"
        #delete tables and do full pull

        Resque.enqueue(PullOrder, params)

      elsif option == "yesterday"
        logger.info "Doing partial pull of orders table and associated tables since yesterday"
        Resque.enqueue(PullOrder, params)
      else
        logger.info "sorry, cannot understand option #{option}, doing nothing."
      end
    end

    class PullOrder
      extend EllieHelper
      include Logging
      @queue = "pull_order"
      def self.perform(params)
        logger.debug "PullOrder#perform params: #{params.inspect}"
        get_order_full(params)
      end
    end


    def handle_subscriptions(option)
      params = {"option_value" => option, "connection" => @uri, "header_info" => @my_header, "sleep_recharge" => @sleep_recharge}
      if option == "full_pull"
        logger.info "Doing full pull of subscription table and associated tables"
        #delete tables and do full pull

        Resque.enqueue(PullSubscription, params)

      elsif option == "yesterday"
        logger.info "Doing partial pull of subscription table and associated tables since yesterday"
        Resque.enqueue(PullSubscription, params)
      else
        logger.info "sorry, cannot understand option #{option}, doing nothing."
      end

    end

    class PullSubscription
      extend EllieHelper
      include Logging
      @queue = "pull_subscriptions"
      def self.perform(params)
        logger.info "PullSubscription#perform params: #{params.inspect}"
        get_sub_full(params)
      end
    end

    def setup_subscription_update_table
      params = {"action" => "setting up subscription_updated table"}
      Resque.enqueue(SetupSubscriptionUpdated, params)

    end

    class SetupSubscriptionUpdated
      extend ResqueHelper
      include Logging
      @queue = "setup_subscription_update"
      def self.perform(params)
        logger.info "SetupSubscriptionUpdated#perform params: #{params.inspect}"
        setup_subscription_update(params)
      end
    end

    def update_subscription_product
     params = {"action" => "updating subscription product info", "recharge_change_header" => @my_change_charge_header}
     Resque.enqueue(UpdateSubscriptionProduct, params)

    end

    class UpdateSubscriptionProduct
      extend ResqueHelper
      include Logging
      @queue = "subscription_property_update"
      def self.perform(params)
        logger.info "UpdateSubscriptionProduct#perform params: #{params.inspect}"
        update_subscription_product(params)
      end

    end

    def load_current_products
      my_delete = "delete from current_products"
      @conn.exec(my_delete)
      my_reorder = "ALTER SEQUENCE current_products_id_seq RESTART WITH 1"
      @conn.exec(my_reorder)
      my_insert = "insert into current_products (prod_id_key, prod_id_value) values ($1, $2)"
      @conn.prepare('statement1', "#{my_insert}")
      CSV.foreach('current_products.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
        #puts row.inspect
        prod_id_key = row['prod_id_key']
        prod_id_value = row['prod_id_value']

        @conn.exec_prepared('statement1', [prod_id_key, prod_id_value])
      end
        @conn.close

    end

    def load_update_products
      my_delete = "delete from update_products"
      @conn.exec(my_delete)
      my_reorder = "ALTER SEQUENCE update_products_id_seq RESTART WITH 1"
      @conn.exec(my_reorder)
      my_insert = "insert into update_products (product_title, sku, shopify_product_id, shopify_variant_id) values ($1, $2, $3, $4)"
      @conn.prepare('statement1', "#{my_insert}")
      CSV.foreach('update_products.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
        #puts row.inspect
        product_title = row['product_title']
        sku = row['sku']
        shopify_product_id = row['shopify_product_id']
        shopify_variant_id = row['shopify_variant_id']

        @conn.exec_prepared('statement1', [product_title, sku, shopify_product_id, shopify_variant_id])
      end
        @conn.close


    end

    def load_switchable_products
        SkippableProduct.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('switchable_products')

          my_insert = "insert into switchable_products (product_title, product_id, threepk) values ($1, $2, $3)"
        @conn.prepare('statement1', "#{my_insert}")
        CSV.foreach('switchable_products_aug2018.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
          #puts row.inspect
          prod_title = row['product_title']
          prod_id = row['product_id']
          mythreepk = row['3pk']

          @conn.exec_prepared('statement1', [prod_title, prod_id, mythreepk])
        end
          @conn.close

    end

    def load_matching_products
      MatchingProduct.delete_all
      ActiveRecord::Base.connection.reset_pk_sequence!('matching_products')

      my_insert = "insert into matching_products (new_product_title, incoming_product_id, threepk, outgoing_product_id) values ($1, $2, $3, $4)"
      @conn.prepare('statement1', "#{my_insert}")
      CSV.foreach('matching_products_aug2018.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
        #puts row.inspect
        title = row['new_product_title']
        incoming_prod_id = row['incoming_product_id']
        mythreepk = row['threepk']
        outgoing_prod_id = row['outgoing_product_id']

        @conn.exec_prepared('statement1', [title, incoming_prod_id, mythreepk, outgoing_prod_id])
      end
        @conn.close


    end

    def load_alternate_products
      AlternateProduct.delete_all
      ActiveRecord::Base.connection.reset_pk_sequence!('alternate_products')

      my_insert = "insert into alternate_products (product_title, product_id, variant_id, sku, product_collection) values ($1, $2, $3, $4, $5)"
      @conn.prepare('statement1', "#{my_insert}")
      CSV.foreach('alternate_products_aug2018.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
        #puts row.inspect
        title = row['product_title']
        prod_id = row['product_id']
        var_id = row['variant_id']
        sku = row['sku']
        product_collection = row['product_collection']

        @conn.exec_prepared('statement1', [title, prod_id, var_id, sku, product_collection])
      end
        @conn.close

    end


  end
end
