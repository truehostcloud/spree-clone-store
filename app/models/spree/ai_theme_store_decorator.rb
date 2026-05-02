module Spree
  module AiThemeStoreDecorator
    def self.prepended(base)
      base.preference :ai_theme_payload, :text, default: nil
      base.preference :ai_theme_status, :string, default: 'draft'
      base.preference :ai_theme_version, :integer, default: 1
      base.preference :ai_theme_preview_token, :string, default: nil
      base.preference :ai_theme_preview_expires_at, :string, default: nil
      base.preference :ai_theme_published_at, :string, default: nil
    end
  end
end

Spree::Store.prepend(Spree::AiThemeStoreDecorator)