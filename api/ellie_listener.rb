require_relative 'config/environment'
require_relative '../lib/recharge_active_record'
require_relative '../lib/logging'

class EllieListener < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  include Logging

  PAGE_LIMIT = 250

  configure do
    enable :logging
    set :server, :puma
    set :database, ENV['DATABASE_URL']
    #set :protection, :except => [:json_csrf]
    mime_type :application_javascript, 'application/javascript'
    mime_type :application_json, 'application/json'

    # on webserver startup set the current theme id
    Resque.enqueue_to(:default, 'Rollover', :set_current_theme_id)
    puts "running configure timezone: #{Time.zone.inspect}"
  end

  def initialize
    @tokens = {}
    @key = ENV['SHOPIFY_API_KEY']
    @secret = ENV['SHOPIFY_SHARED_SECRET']
    @app_url = 'www.ellieactivetesting.com'
    @default_headers = { 'Content-Type' => 'application/json' }
    @recharge_token = ENV['RECHARGE_ACCESS_TOKEN']
    @recharge_change_header = {
      'X-Recharge-Access-Token' => @recharge_token,
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }
    # required for active support's Time.zone
    # Gets unset from initializer when puma forks new threads
    p 'running EllieListener#initialize'
    Thread.current[:time_zone] ||= ActiveSupport::TimeZone['Pacific Time (US & Canada)']

    super
  end

  get '/install' do
    shop = 'elliestaging.myshopify.com'
    scopes = 'read_themes, write_themes, read_orders, write_orders, read_products, read_customers, write_customers'

    # construct the installation URL and redirect the merchant
    install_url =
      "http://#{shop}/admin/oauth/authorize?client_id=#{@key}&scope=#{scopes}"\
      "&redirect_uri=https://#{@app_url}/auth/shopify/callback"

    redirect install_url
  end


  get '/auth/shopify/callback' do
    # extract shop data from request parameters
    shop = request.params['shop']
    code = request.params['code']
    hmac = request.params['hmac']

    # perform hmac validation to determine if the request is coming from Shopify
    h = request.params.reject{|k, _| k == 'hmac' || k == 'signature'}
    query = URI.escape(h.sort.collect{|k,v| "#{k}=#{v}"}.join('&'))
    digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @secret, query)

    unless hmac == digest
      return [403, "Authentication failed. Digest provided was: #{digest}"]
    end

    # if we don't have an access token for this particular shop,
    # we'll post the OAuth request and receive the token in the response
    if @tokens[shop].nil?
      url = "https://#{shop}/admin/oauth/access_token"

      payload = {
        client_id: @key,
        client_secret: @secret,
        code: code
      }

      response = HTTParty.post(url, body: payload)

      # if the response is successful, obtain the token and store it in a hash
      if response.code == 200
        @tokens[shop] = response['access_token']
      else
        return [500, 'Something went wrong.']
      end
    end

    # now that we have the token, we can instantiate a session
    session = ShopifyAPI::Session.new(shop, @tokens[shop])
    @my_session = session
    ShopifyAPI::Base.activate_session(session)

    # create webhook for order creation if it doesn't exist



    redirect '/hello'

  end

  get '/hello' do
    'Hello, success, thanks for installing me!'
  end

  get '/test' do
    'Hi there endpoint is active'
  end

  get '/subscriptions' do
    puts "handler timezone: #{Time.zone.inspect}"
    shopify_id = params['shopify_id']
    logger.debug params.inspect
    if shopify_id.nil?
      return [400, @default_headers, JSON.generate(error: 'shopify_id required')]
    end
    customer_id = Customer.find_by!(shopify_customer_id: shopify_id).customer_id
    time = Time.zone.parse params[:time] rescue Time.zone.now
    data = Subscription
      .current_products(time: time, theme_id: params[:theme_id])
      .where(
        status: 'ACTIVE',
        customer_id: customer_id,
      )
      .order(:next_charge_scheduled_at)
    output = data.map{|sub| transform_subscriptions(sub, sub.orders)}
    [200, @default_headers, output.to_json]
  end
  
  get '/subscriptions_properties' do
    puts "handler timezone: #{Time.zone.inspect}"
    shopify_id = params['shopify_id']
    logger.debug params.inspect

    if shopify_id.nil?
      return [400, @default_headers, JSON.generate(error: 'shopify_id required')]
    end
    customer_id = Customer.find_by!(shopify_customer_id: shopify_id).customer_id
    time = Time.zone.parse params[:time] rescue Time.zone.now
    data = Subscription
      .current_products(time: time, theme_id: params[:theme_id])
      .where(
        status: 'ACTIVE',
        customer_id: customer_id,
      )
      .order(:next_charge_scheduled_at)
    output = data.map{|sub| transform_subscriptions(sub, sub.orders)}
    [200, @default_headers, output.to_json]
  end


  get '/subscription/:subscription_id/sizes' do |subscription_id|
    sub = Subscription.find subscription_id
    #sub = Subscription.limit(200).sample
    return [404, @default_headers, {error: 'subscription not found'}.to_json] if sub.nil?
    [200, @default_headers, sub.sizes.to_json]
  end

  post '/subscriptions' do
    json = JSON.parse request.body.read
    shopify_id = json['shopify_id']
    return [400, {error: 'shopify_id required'}.to_json] if shopify_id.nil?
    data = Customer.joins(:subscriptions)
      .find_by!(shopify_customer_id: shopify_id, status: 'ACTIVE')
      .subscriptions
      .map{|sub| [sub, sub.orders]}
    output = data.map{|i| transform_subscriptions(*i)}
    [200, @default_headers, output.to_json]
  end

  get '/subscription/:subscription_id' do |subscription_id|
    subscription = Subscription.find(subscription_id)
    [200, @default_headers, subscription.to_json]
  end

  put '/subscription/:subscription_id/sizes' do |subscription_id|
    #puts 'found the method'
    # body parsing and validation
    begin
      json = JSON.parse request.body.read
      sizes = json.select do |key, val|
        SubLineItem::SIZE_PROPERTIES.include?(key) && SubLineItem::SIZE_VALUES.include?(val)
      end
      logger.debug "sizes: #{sizes}"
    rescue Exception => e
      logger.error e.inspect
      return [400, @default_headers, {error: e}.to_json]
    end
    begin
      #res = RechargeAPI.put("/subscriptions/#{subscription_id}", {body: body_json})
      #queued = Subscription.async(:recharge_update, body)
      #ChangeSizes.perform(subscription_id, sizes)
      queued = Resque.enqueue_to(:change_sizes, 'ChangeSizes', subscription_id, sizes)
      raise 'Error updating sizes. Please try again later.' unless queued
      #line_items.each(&:save!)
    rescue Exception => e
      logger.error e.inspect
      return [500, @default_headers, {error: e}.to_json]
    end
    [200, @default_headers, sizes.to_json]
  end

  put '/subscription/:subscription_id' do |subscription_id|
    subscription = Subscription.find_by!(subscription_id: subscription_id)
    if subscription.nil?
      return [404, @default_headers, {error: 'subscription not found'}.to_json]
    end
    begin
      json = JSON.parse request.body.read
      matching_keys = (subscription.API_MAP.pluck(:remote_keys) & json.keys)
      subscription.update(json.select { |k, _| matching_keys.include? k })
    rescue
      return [400, @default_headers, {error: 'invalid payload data'}.to_json]
    end
    res = Subscription.async(:recharge_update, subscription.as_recharge)
    raise 'Error processing subscription change. Please try again later.' unless res
    subscription.save
    logger.error e.inspect
    output = {subscription: subscription}
    [200, @default_headers, output.to_json]
  end

  post '/subscription/:subscription_id/skip' do |subscription_id|
    sub = Subscription.find subscription_id
    return [404, @default_headers, {error: 'subscription not found'}.to_json] if sub.nil?
    begin
      request_body = JSON.parse request.body.read
      puts "request_body = #{request_body}"
    rescue StandardError => e
      return [400, @default_headers, {error: 'invalid payload data', details: e}.to_json]
    end
    skip_res = sub.skip
    # FIXME: currently does not allow skipping prepaid subscriptions
    queue_res = Subscription.async :skip!, subscription_id
    if queue_res
      SkipReason.create(
        customer_id: sub.customer.customer_id,
        shopify_customer_id: request_body['shopify_customer_id'],
        subscription_id: sub.subscription_id,
        charge_id: sub.charges.next_scheduled,
        skipped_to: sub.next_charge_scheduled_at,
        skip_status: skip_res,
        reason: request_body['reason'],
      )
      [200, @default_headers, {skipped: skip_res, subscription: sub.as_recharge}.to_json]
    else
      [500, @default_headers, {error: 'error processing skip'}.to_json]
    end
  end

  put '/subscription_switch' do
    puts 'Received stuff'
    puts params.inspect
    puts '----------'
    myjson = params

    puts "recharge_change_header = #{@recharge_change_header}"

    #myjson = JSON.parse(request.body.read)
    myjson['recharge_change_header'] = @recharge_change_header
    puts myjson.inspect
    my_action = myjson['action']
    if my_action == 'switch_product'
      Resque.enqueue_to(:switch_product, 'SubscriptionSwitch', myjson)
    else
      puts "Can't switch product, action must be switch product not #{my_action}"
    end
  end

  post '/subscription_skip' do
    #json = JSON.parse request.body
    puts "Received skip request"
    puts params.inspect
    params['recharge_change_header'] = @recharge_change_header
    my_action = params['action']
    my_now = Date.current.day
    puts "Day of the month is #{my_now}"
    if Time.zone.now.day < 5
      if my_action == "skip_month"
        Resque.enqueue_to(:skip_product, 'SubscriptionSkip', params)
      else
        puts "Cannot skip this product, action must be skip_month not #{my_action}"
      end
    else
      puts "It is past the 4th of the month, cannot skip"
    end
  end

  get '/skippable_subscriptions' do
    shopify_id = params['shopify_id']
    logger.debug params.inspect
    if shopify_id.nil?
      return [400, @default_headers, JSON.generate(error: 'shopify_id required')]
    end
    customer = Customer.joins(:subscriptions)
      .find_by!(shopify_customer_id: shopify_id, status: 'ACTIVE')
    time = Time.zone.parse params[:time] rescue Time.zone.now
    next_charge_sql = 'next_charge_scheduled_at > ? AND next_charge_scheduled_at < ?'
    data = customer
      .subscriptions
      .skippable_products(time: time, theme_id: params[:theme_id])
      .where(status: 'ACTIVE')
      .where(next_charge_sql, Time.current.beginning_of_month, Time.current.end_of_month)
      .order(:next_charge_scheduled_at)
      .map do |sub|
        skippable = sub.skippable?(time: time, theme_id: params[:theme_id])
        switchable = sub.switchable?(time: time, theme_id: params[:theme_id])
        {
          subscription_id: sub.subscription_id,
          shopify_product_title: sub.product_title,
          shopify_product_id: sub.shopify_product_id,
          next_charge_scheduled_at: sub.next_charge_scheduled_at.strftime('%F'),
          skippable: skippable,
          can_choose_alt_product: switchable,
        }
      end
    [200, @default_headers, data.to_json]
  end

  error ActiveRecord::RecordNotFound do
    details = env['sinatra.error'].message
    [404, @default_headers, {error: 'Record not found', details: details}.to_json]
  end

  error JSON::ParserError do
    [400, @default_headers, { error: env['sinatra_error'].message }.to_json]
  end

  error do
    [500, @default_headers, {error: env['sinatra.error'].message}.to_json]
  end

  private

  def transform_subscriptions(sub, orders)
    logger.debug "subscription: #{sub.inspect}"
    {
      shopify_product_id: sub.shopify_product_id.to_i,
      subscription_id: sub.subscription_id.to_i,
      product_title: sub.product_title,
      next_charge: sub.next_charge_scheduled_at.try{|time| time.strftime('%Y-%m-%d')},
      charge_date: sub.next_charge_scheduled_at.try{|time| time.strftime('%Y-%m-%d')},
      sizes: sub.sizes,
      prepaid: sub.prepaid?,
      prepaid_shipping_at: sub.shipping_at.try{|time| time.strftime('%Y-%m-%d')},
      skippable: sub.skippable?,
      can_choose_alt_product: sub.switchable?
    }
  end

end


