#background_subs.rb
require_relative '../lib/recharge_limit'

module BackgroundSubs
    include ReChargeLimits

    def special_handling_sub_line_items(uri, id)
        myuri = URI.parse(uri)
        my_conn =  PG.connect(myuri.hostname, myuri.port, nil, nil, myuri.path[1..-1], myuri.user, myuri.password)
        my_delete = "delete from sub_line_items where subscription_id = \'#{id}\'"  
        my_conn.exec(my_delete) 
        my_conn.close
    
      end

      def insert_sub_line_items(uri, properties, subscription_id)
        myuri = URI.parse(uri)
        my_conn =  PG.connect(myuri.hostname, myuri.port, nil, nil, myuri.path[1..-1], myuri.user, myuri.password)
        my_insert = "insert into sub_line_items (subscription_id, name, value) values ($1, $2, $3)"
    
        my_conn.prepare('statement1', "#{my_insert}")

        properties.each do |temp|
            temp_name = temp['name']
            temp_value = temp['value']
            puts "#{temp_name}, #{temp_value}"
            if !temp_value.nil? && !temp_name.nil?
              
              my_conn.exec_prepared('statement1', [ subscription_id, temp_name, temp_value ])
              puts "inserted subscription #{subscription_id}"
          
            end
        end
        my_conn.close
      end

    def twenty_five_min
        min_ago = 25
        minutes_ago = DateTime.now - (min_ago/1440.0)
        twenty_five_minutes_ago_str = minutes_ago.strftime("%Y-%m-%dT%H:%M:%S")
        puts "Twenty five minutes ago = #{twenty_five_minutes_ago_str}"
        Resque.logger.info "Twenty five minutes ago = #{twenty_five_minutes_ago_str}"
        return twenty_five_minutes_ago_str

    end


    def get_new_subs_last_hour(params)
        Resque.logger = Logger.new("#{Dir.getwd}/logs/get_subs_last_time_period.log")
        uri = params['uri']
        myuri = URI.parse(uri)
        my_conn =  PG.connect(myuri.hostname, myuri.port, nil, nil, myuri.path[1..-1], myuri.user, myuri.password)
        puts my_conn.inspect
        my_header = params["headers"]
        Resque.logger.info "BackgroundSubs#get_all_new_subs_last_hour: #{params}"

        #Upsert statement
        my_insert = "insert into subscriptions (subscription_id, address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, cancelled_at, product_title, price, quantity, status, shopify_product_id, shopify_variant_id, sku, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, raw_line_item_properties, expire_after_specific_number_charges) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21) on conflict (subscription_id) do update set address_id = EXCLUDED.address_id, customer_id = EXCLUDED.customer_id, created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at, next_charge_scheduled_at = EXCLUDED.next_charge_scheduled_at, cancelled_at = EXCLUDED.cancelled_at, product_title = EXCLUDED.product_title, price = EXCLUDED.price, quantity = EXCLUDED.quantity, status = EXCLUDED.status, shopify_product_id = EXCLUDED.shopify_product_id, shopify_variant_id = EXCLUDED.shopify_variant_id, sku = EXCLUDED.sku, order_interval_unit = EXCLUDED.order_interval_unit, order_interval_frequency = EXCLUDED.order_interval_frequency, charge_interval_frequency = EXCLUDED.charge_interval_frequency, order_day_of_month = EXCLUDED.order_day_of_month, order_day_of_week = EXCLUDED.order_day_of_week, raw_line_item_properties = EXCLUDED.raw_line_item_properties, expire_after_specific_number_charges = EXCLUDED.expire_after_specific_number_charges"
        my_conn.prepare('statement1', "#{my_insert}")

        #one_hour_ago = DateTime.now - (1.0/24)
        #one_hour_ago_str = one_hour_ago.strftime("%Y-%m-%dT%H:00:00")
        #puts "one hour ago = #{one_hour_ago_str}"
        #Resque.logger.info "one hour ago = #{one_hour_ago_str}"

        

        twenty_five_minutes_ago_str = twenty_five_min


        subscriptions = HTTParty.get("https://api.rechargeapps.com/subscriptions/count?created_at_min=\'#{twenty_five_minutes_ago_str}\'", :headers => my_header)
            
        my_count = subscriptions['count'].to_i
        current_time = DateTime.now.strftime("%Y-%m-%dT%H:%M:%S")
        puts "Time now = #{current_time}"
        puts "We have #{my_count} subscriptions created_at this past 25 minutes"
        Resque.logger.info "Time now = #{current_time}"
        Resque.logger.info "We have #{my_count} subscriptions created_at this past 25minutes"

        start = Time.now    
        page_size = 250
        num_pages = (my_count/page_size.to_f).ceil
        1.upto(num_pages) do |page|
            mysubs = HTTParty.get("https://api.rechargeapps.com/subscriptions?updated_at_min=\'#{twenty_five_minutes_ago_str}\'&limit=250&page=#{page}", :headers => my_header)
            recharge_limit = mysubs.response["x-recharge-limit"]
            local_sub = mysubs['subscriptions']
            local_sub.each do |sub|
                puts "-------------------"
                puts sub.inspect
                puts "------------------"
                Resque.logger.info "-------------------"
                Resque.logger.info sub.inspect
                Resque.logger.info "------------------"

                subscription_id = sub['id']

                address_id = sub['address_id']
                customer_id = sub['customer_id']
                created_at = sub['created_at']
                updated_at = sub['updated_at']
                next_charge_scheduled_at = sub['next_charge_scheduled_at']
                cancelled_at = sub['cancelled_at']
                product_title = sub['product_title']
                price = sub['price']
                quantity = sub['quantity']
                status = sub['status']
                shopify_product_id = sub['shopify_product_id']
                shopify_variant_id = sub['shopify_variant_id']
                sku = sub['sku']
                order_interval_unit = sub['order_interval_unit']
                order_interval_frequency = sub['order_interval_frequency']
                charge_interval_frequency = sub['charge_interval_frequency']
                order_day_of_month = sub['order_day_of_month']
                order_day_of_week = sub['order_day_of_week']
                raw_properties = sub['properties']
                properties = sub['properties'].to_json
                expire_after = sub['expire_after_specific_number_charges']

                special_handling_sub_line_items(uri, subscription_id)
                insert_sub_line_items(uri, raw_properties, subscription_id)


                insert_result = my_conn.exec_prepared('statement1', [ subscription_id, address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, cancelled_at, product_title, price, quantity, status, shopify_product_id, shopify_variant_id, sku, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, properties, expire_after])
                puts insert_result.inspect
                Resque.logger.info insert_result.inspect
            end
            puts "Done with page #{page}"
            Resque.logger.info "Done with page #{page}"
            current = Time.now
            duration = (current - start).ceil
            puts "Been running #{duration} seconds"
            Resque.logger.info "Been running #{duration} seconds"
            determine_limits(recharge_limit, 0.65)
        end
        puts "All done with last 25 minutes created subscriptions"
        Resque.logger.info "All done with last 25 minutes created subscriptions"
        
        #exit

    end


    def get_subs_last_hour(params)
        puts "params = #{params.inspect}"
        #Resque.logger = Logger.new("#{Dir.getwd}/logs/get_updated_subs_last_time_period.log")
        
        uri = params["uri"]
        myuri = URI.parse(uri)
        my_conn =  PG.connect(myuri.hostname, myuri.port, nil, nil, myuri.path[1..-1], myuri.user, myuri.password)
        puts my_conn.inspect
        my_header = params["headers"]

        get_new_subs_last_hour(params)

        Resque.logger.info "**************************************"
        Resque.logger.info "Now doing updated subs pull!"
        Resque.logger.info "BackgroundSubs#get_subs_last_hour: #{params}"

        #insert new record if it does not exist and was not grabbed by earlier job
        my_insert = "insert into subscriptions (subscription_id, address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, cancelled_at, product_title, price, quantity, status, shopify_product_id, shopify_variant_id, sku, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, raw_line_item_properties, expire_after_specific_number_charges) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)"
        my_conn.prepare('statement1', "#{my_insert}")


        #Otherwise update the record
        my_temp_update = "update subscriptions set address_id = $1, customer_id = $2, created_at = $3, updated_at = $4, next_charge_scheduled_at = $5, cancelled_at = $6, product_title = $7, price = $8, quantity = $9, status = $10, shopify_product_id = $11, shopify_variant_id = $12, sku = $13, order_interval_unit = $14, order_interval_frequency = $15, charge_interval_frequency = $16, order_day_of_month = $17, order_day_of_week = $18, raw_line_item_properties = $19, expire_after_specific_number_charges = $20 where subscription_id = $21"
        my_conn.prepare('statement2', "#{my_temp_update}")

        
        #one_hour_ago = DateTime.now - (1.0/24)
        #one_hour_ago_str = one_hour_ago.strftime("%Y-%m-%dT%H:00:00")
        
        #puts "one hour ago = #{one_hour_ago_str}"
        #Resque.logger.info "one hour ago = #{one_hour_ago_str}"
        #my_today = Date.today
        #my_today = "2018-08-03T14:00:00"
        

        twenty_five_minutes_ago_str = twenty_five_min


        subscriptions = HTTParty.get("https://api.rechargeapps.com/subscriptions/count?updated_at_min=\'#{twenty_five_minutes_ago_str}\'", :headers => my_header)
            
        my_count = subscriptions['count'].to_i
        current_time = DateTime.now.strftime("%Y-%m-%dT%H:%M:%S")
        puts "Time now = #{current_time}"
        puts "We have #{my_count} subscriptions updated this past 25 minutes"
        Resque.logger.info "Time now = #{current_time}"
        Resque.logger.info "We have #{my_count} subscriptions updated this past 25 minutes"

        start = Time.now
        page_size = 250
        num_pages = (my_count/page_size.to_f).ceil
        1.upto(num_pages) do |page|
            mysubs = HTTParty.get("https://api.rechargeapps.com/subscriptions?updated_at_min=\'#{twenty_five_minutes_ago_str}\'&limit=250&page=#{page}", :headers => my_header)
            recharge_limit = mysubs.response["x-recharge-limit"]
            local_sub = mysubs['subscriptions']
            local_sub.each do |sub|
                puts "-------------------"
                puts sub.inspect
                puts "-------------------"
                Resque.logger.info "-------------------"
                Resque.logger.info sub.inspect
                Resque.logger.info "-------------------"

                #update only, API only returns the records UPDATED!
                #Why RAW SQL? SPEED! Yes Active Record is better. Its slower too
                subscription_id = sub['id']

                address_id = sub['address_id']
                customer_id = sub['customer_id']
                created_at = sub['created_at']
                updated_at = sub['updated_at']
                next_charge_scheduled_at = sub['next_charge_scheduled_at']
                cancelled_at = sub['cancelled_at']
                product_title = sub['product_title']
                price = sub['price']
                quantity = sub['quantity']
                status = sub['status']
                shopify_product_id = sub['shopify_product_id']
                shopify_variant_id = sub['shopify_variant_id']
                sku = sub['sku']
                order_interval_unit = sub['order_interval_unit']
                order_interval_frequency = sub['order_interval_frequency']
                charge_interval_frequency = sub['charge_interval_frequency']
                order_day_of_month = sub['order_day_of_month']
                order_day_of_week = sub['order_day_of_week']
                raw_properties = sub['properties']
                properties = sub['properties'].to_json
                expire_after = sub['expire_after_specific_number_charges']



                temp_select = "select * from subscriptions where subscription_id = \'#{subscription_id}\'"
                temp_result = my_conn.exec(temp_select)
                if !temp_result.num_tuples.zero?
                    temp_result.each do |myrow|
                        puts myrow.inspect
                        #order_id = myrow['order_id']
                        puts "updating subscription ID #{subscription_id}"
                        Resque.logger.info "updating subscription ID #{subscription_id}"
    
                        indy_result = my_conn.exec_prepared('statement2', [ address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, cancelled_at, product_title, price, quantity, status, shopify_product_id, shopify_variant_id, sku, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, properties, expire_after, subscription_id])
                        puts indy_result.inspect
                        Resque.logger.info indy_result.inspect

                        special_handling_sub_line_items(uri, subscription_id)
                        insert_sub_line_items(uri, raw_properties, subscription_id)

                    end
                else
                    puts "Sorry can't update because it does not exist in the database"
                    puts "Inserting record instead into database"
                    Resque.logger.info "Sorry can't update because it does not exist in the database"
                    Resque.logger.info "Inserting record instead into database"


                    insert_result = my_conn.exec_prepared('statement1', [ subscription_id, address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, cancelled_at, product_title, price, quantity, status, shopify_product_id, shopify_variant_id, sku, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, properties, expire_after])
                    puts insert_result.inspect
                    Resque.logger.info insert_result.inspect
                    special_handling_sub_line_items(uri, subscription_id)
                    insert_sub_line_items(uri, raw_properties, subscription_id)

                end




                

                end
                puts "Done with page #{page}"
                Resque.logger.info "Done with page #{page}"
                current = Time.now
                duration = (current - start).ceil
                puts "Been running #{duration} seconds"
                Resque.logger.info "Been running #{duration} seconds"
                determine_limits(recharge_limit, 0.65)
            end
            puts "All done with last 25 minutes updated subscriptions"
            Resque.logger.info "All done with last 25 minutes updated subscriptions"
            my_conn.close
        

    end

end