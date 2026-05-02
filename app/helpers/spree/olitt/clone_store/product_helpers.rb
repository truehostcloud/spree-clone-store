module Spree
  module Olitt
    module CloneStore
      module ProductHelpers
        def duplicate_master_variant(product:, vendor_id:, code:, tax_category: nil)
          master = product.master
          master.dup.tap do |new_master|
            new_master.sku = sku_generator(sku: master.sku, code: code)
            new_master.deleted_at = nil
            new_master.vendor_id = vendor_id
            new_master.tax_category = tax_category if new_master.respond_to?(:tax_category=)
            assign_variant_assets(new_variant: new_master, old_variant: master)
          end
        end

        def duplicate_variant(variant:, vendor_id:, code:, option_values: nil, tax_category: nil)
          option_values = Array(option_values.presence || variant.option_values.to_a.compact).compact
          return if option_values.empty?

          new_variant = variant.dup
          new_variant.sku = sku_generator(sku: variant.sku, code: code)
          new_variant.deleted_at = nil
          new_variant.vendor_id = vendor_id
          new_variant.tax_category = tax_category if new_variant.respond_to?(:tax_category=)
          new_variant.option_values = option_values
          assign_variant_assets(new_variant: new_variant, old_variant: variant)
          new_variant
        end

        def assign_variant_assets(new_variant:, old_variant:)
          new_variant.images = duplicate_images(images: old_variant.images) if new_variant.respond_to?(:images=)
          assign_variant_prices(new_variant: new_variant, old_variant: old_variant)
        end

        def duplicate_images(images:)
          Array(images).map { |image| duplicate_image(image: image) }
        end

        def assign_variant_prices(new_variant:, old_variant:)
          prices = duplicate_prices(prices: old_variant.prices)

          if prices.any? && new_variant.respond_to?(:prices=)
            new_variant.prices = prices
          elsif old_variant.respond_to?(:price) && new_variant.respond_to?(:price=) && old_variant.price.present?
            new_variant.price = old_variant.price
            new_variant.currency = old_variant.currency if new_variant.respond_to?(:currency=) && old_variant.respond_to?(:currency)
          end
        end

        def duplicate_prices(prices:)
          Array(prices).filter_map do |price|
            next if price.blank?

            price.dup.tap do |new_price|
              new_price.deleted_at = nil if new_price.respond_to?(:deleted_at=)
              new_price.created_at = nil if new_price.respond_to?(:created_at=)
              new_price.updated_at = nil if new_price.respond_to?(:updated_at=)
            end
          end
        end

        def duplicate_image(image:)
          new_image = image.dup
          new_image.attachment.attach(image.attachment.blob)
          new_image.save!
          new_image
        end

        def reset_properties(product:)
          product.product_properties.map do |prop|
            prop.dup.tap do |new_prop|
              new_prop.created_at = nil
              new_prop.updated_at = nil
            end
          end
        end

        def sku_generator(sku:, code:)
          return '' if sku.blank?

          "COPY OF #{sku} FOR STORE: #{code}"
        end
      end
    end
  end
end
