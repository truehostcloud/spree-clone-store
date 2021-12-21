module Spree
  module Olitt
    module CloneStore
      module ProductHelpers
        def duplicate_master_variant(product:, code:)
          master = product.master
          master.dup.tap do |new_master|
            new_master.sku = sku_generator(sku: master.sku, code: code)
            new_master.deleted_at = nil
            new_master.images = master.images.map { |image| duplicate_image(image: image) }
            new_master.price = master.price
            new_master.currency = master.currency
          end
        end

        def duplicate_variant(variant:, code:)
          new_variant = variant.dup
          new_variant.sku = sku_generator(sku: variant.sku, code: code)
          new_variant.deleted_at = nil
          new_variant.option_values = variant.option_values.map { |option_value| option_value }
          new_variant
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
