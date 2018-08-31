# product configuration manual tagging syntax
# MMYY_(main, alt1, or alt2)_(3, 5, AR3, or AR5)
require_relative '../lib/logging'
class MonthlySetup
  include Logging
  def initialize
    @sleep_shopify = ENV['SHOPIFY_SLEEP_TIME']
    @shopify_base_site = "https://#{ENV['SHOPIFY_API_KEY']}:#{ENV['SHOPIFY_SHARED_SECRET']}@#{ENV['SHOPIFY_SHOP_NAME']}.myshopify.com/admin"
    @uri = URI.parse(ENV['DATABASE_URL'])
    @conn = PG.connect(@uri.hostname, @uri.port, nil, nil, @uri.path[1..-1], @uri.user, @uri.password)
    @next_mon = Date.today >> 1
  end
  # configures switchable_products table --step 1
  def switchable_config
    current_array = Product.find_by_sql("SELECT * from products where tags NOT LIKE '%AR%' AND tags LIKE '%#{@next_mon.strftime('%m%y')}_main%';")
    my_insert = "insert into switchable_products (product_title, product_id, threepk) values ($1, $2, $3)"
    @conn.prepare('statement1', "#{my_insert}")
    current_array.each do |x|
      product_title = x.title
      product_id = x.id
      threepk = x.title.include?('3 Item')? true : false
      @conn.exec_prepared('statement1', [product_title, product_id, threepk])
    end
    logger.info "switchable_config done"
    @conn.close
  end
  # configures alternate_products table --step 2
  def alternate_config
    current_array = Product.find_by_sql("SELECT * from products where tags NOT LIKE '%AR%' AND tags LIKE '%#{@next_mon.strftime('%m%y')}_alt%';")
    my_insert = "insert into alternate_products (product_title, product_id, variant_id, sku, product_collection) values ($1, $2, $3, $4, $5)"
    @conn.prepare('statement1', "#{my_insert}")
    current_array.each do |x|
      product_title = x.title
      product_id = x.id
      # variant_id = x.variants[0]['id']
      variant_id = EllieVariant.find_by(product_id: x.id).variant_id
      # sku = x.variants[0]['sku']
      sku = EllieVariant.find_by(product_id: x.id).sku
      # TODO(Neville): adjust for edge cases i.e. Items => Item etc..
      product_collection = x.title
      @conn.exec_prepared('statement1', [product_title, product_id, variant_id, sku, product_collection])
    end
    logger.info "alternate_config done"
    @conn.close
  end
  def matching_config
    # array of current months product collections
    # not including auto renews
    current_array = Product.find_by_sql(
      "SELECT * from products
      WHERE tags NOT LIKE '%AR%'
      AND tags LIKE '%#{@next_mon.strftime('%m%y')}_%'
      ORDER BY (title);")
    my_insert = "insert into matching_products (new_product_title, incoming_product_id, threepk, outgoing_product_id) values ($1, $2, $3, $4)"
    @conn.prepare('statement1', "#{my_insert}")
    current_array.each_with_index do |prod, idx|
      if prod.title.include?('3 Item')
        incoming_product_id = current_array[idx + 1].shopify_id
        threepk = true
      elsif prod.title.include?('5 Item')
        incoming_product_id = prod.shopify_id
        threepk = false
      end
      new_product_title = prod.title
      product_id = incoming_product_id
      # if threepk true, assign 3 item prod id to outgoing_product_id
      outgoing_product_id = (threepk)? prod.shopify_id : incoming_product_id
      @conn.exec_prepared('statement1', [new_product_title, incoming_product_id, threepk, outgoing_product_id])
      # TODO(Neville): adjust for edge cases i.e. Items => Item etc..
    end
      logger.info "matching_config done"
      @conn.close
  end
end
