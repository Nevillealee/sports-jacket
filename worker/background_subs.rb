#background_subs.rb

module BackgroundSubs

    def get_subs_last_hour(params)
        puts "params = #{params.inspect}"
        uri = params["uri"]
        myuri = URI.parse(uri)
        my_conn =  PG.connect(myuri.hostname, myuri.port, nil, nil, myuri.path[1..-1], myuri.user, myuri.password)
        puts my_conn.inspect
        my_header = params["headers"]

        my_temp_update = "update subscriptions set address_id = $1, customer_id = $2, created_at = $3, updated_at = $4, next_charge_scheduled_at = $5, cancelled_at = $6, product_title = $7, price = $8, quantity = $9, status = $10, shopify_product_id = $11, shopify_variant_id = $12, sku = $13, order_interval_unit = $14, order_interval_frequency = $15, charge_interval_frequency = $16, order_day_of_month = $17, order_day_of_week = $18, raw_line_item_properties = $19, expire_after_specific_number_charges = $20 where subscription_id = $21"
        my_conn.prepare('statement2', "#{my_temp_update}")



        one_hour_ago = DateTime.now - (1.0/24)
        one_hour_ago_str = one_hour_ago.strftime("%Y-%m-%dT%H:00:00")
        puts "one hour ago = #{one_hour_ago_str}"

        #my_today = Date.today
        my_today = "2018-08-03T14:00:00"

        subscriptions = HTTParty.get("https://api.rechargeapps.com/subscriptions/count?updated_at_min=\'#{one_hour_ago_str}\'", :headers => my_header)
            
        my_count = subscriptions['count'].to_i
        puts "We have #{my_count} subscriptions updated this past hour"
            
        page_size = 250
        num_pages = (my_count/page_size.to_f).ceil
        1.upto(num_pages) do |page|
            mysubs = HTTParty.get("https://api.rechargeapps.com/subscriptions?updated_at_min=\'#{one_hour_ago_str}\'&limit=250&page=#{page}", :headers => my_header)
            local_sub = mysubs['subscriptions']
            local_sub.each do |sub|
                puts "-------------------"
                puts sub.inspect
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
                properties = sub['properties'].to_json
                expire_after = sub['expire_after_specific_number_charges']



                temp_select = "select * from subscriptions where subscription_id = \'#{subscription_id}\'"
                temp_result = my_conn.exec(temp_select)
                if !temp_result.num_tuples.zero?
                    temp_result.each do |myrow|
                        puts myrow.inspect
                        #order_id = myrow['order_id']
                        puts "updating subscription ID #{subscription_id}"
    
                        indy_result = my_conn.exec_prepared('statement2', [ address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, cancelled_at, product_title, price, quantity, status, shopify_product_id, shopify_variant_id, sku, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, properties, expire_after, subscription_id])
                        puts indy_result.inspect

                    end
                else
                    puts "Sorry can't insert because it does not exist in the database"

                end




                puts "-------------------"

                end
                puts "Done with page #{page}"
                sleep 4
            end
            puts "All done with last hour's updated subscriptions"

        

    end

end