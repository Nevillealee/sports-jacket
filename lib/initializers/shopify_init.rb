require_relative '../async'
ShopifyAPI::Base.site = "https://#{ENV['SHOPIFY_API_KEY']}:#{ENV['SHOPIFY_SHARED_SECRET']}@#{ENV['SHOPIFY_SHOP_NAME']}.myshopify.com/admin"
ShopifyAPI::Base.include Async
