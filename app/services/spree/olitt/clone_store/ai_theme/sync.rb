require 'digest'
require 'json'
require 'securerandom'

module Spree
  module Olitt
    module CloneStore
      module AiTheme
        class Sync
          PAGE_KIND_CLASS_MAP = {
            'homepage' => 'Spree::Pages::Homepage',
            'shop_all' => 'Spree::Pages::ShopAll'
          }.freeze

          attr_reader :errors

          def initialize(store: nil, theme: nil)
            @store = store
            @theme = theme
            @errors = []
          end

          def upsert_theme(params)
            payload = normalize_payload(params)
            theme = resolve_theme(payload)

            with_transaction(theme) do
              assign_theme_attributes(theme, payload)
              theme.save!
              sync_pages(theme, payload[:spec])
              persist_theme_state!(theme, payload)
            end

            theme.reload if theme.respond_to?(:reload)
            theme
          rescue StandardError => e
            capture_error(e)
            nil
          end

          def upsert_page(theme, params)
            payload = normalize_payload(params)

            with_transaction(theme) do
              page = resolve_page(theme, payload)
              assign_page_attributes(page, payload, theme)
              page.save!
              sync_sections(page, payload[:sections])
              page
            end
          rescue StandardError => e
            capture_error(e)
            nil
          end

          def upsert_section(page, params)
            payload = normalize_payload(params)

            with_transaction(page) do
              section = resolve_section(page, payload)
              assign_section_attributes(section, payload, page)
              section.save!
              sync_blocks(section, payload[:blocks])
              section
            end
          rescue StandardError => e
            capture_error(e)
            nil
          end

          def snapshot_version(theme, params)
            payload = normalize_payload(params)
            with_transaction(theme) do
              version = next_version(theme)
              theme_state = theme_state(theme)
              revisions = Array(theme_state['versions'])
              snapshot = {
                'revision' => version,
                'checksum' => payload[:checksum].presence || checksum_for(payload[:spec] || theme_state['spec'] || {}),
                'spec' => payload[:spec] || theme_state['spec'] || {},
                'created_at' => Time.current.iso8601
              }
              revisions << snapshot
              persist_theme_state!(theme, { version: version, versions: revisions, spec: snapshot['spec'] })
              snapshot
            end
          rescue StandardError => e
            capture_error(e)
            nil
          end

          def preview_theme(theme)
            with_transaction(theme) do
              token = SecureRandom.hex(16)
              persist_theme_state!(theme, {
                status: 'preview',
                preview_token: token,
                preview_expires_at: 1.hour.from_now.iso8601,
                ready: false
              })
              token
            end
          rescue StandardError => e
            capture_error(e)
            nil
          end

          def publish_theme(theme)
            with_transaction(theme) do
              persist_theme_state!(theme, {
                status: 'published',
                published_at: Time.current.iso8601,
                ready: true
              })
              theme.update!(ready: true) if theme.respond_to?(:update!) && theme.respond_to?(:ready=)
              theme
            end
          rescue StandardError => e
            capture_error(e)
            nil
          end

          def theme_payload(theme)
            state = theme_state(theme)
            {
              data: {
                id: theme.id.to_s,
                type: 'ai_theme',
                attributes: {
                  name: theme.try(:name),
                  store_id: theme.try(:store_id),
                  status: state['status'].presence || default_status(theme),
                  version: state['version'].presence || 1,
                  prompt: state['prompt'],
                  spec: state['spec'] || {},
                  preview_token: state['preview_token'],
                  preview_expires_at: state['preview_expires_at'],
                  published_at: state['published_at'],
                  ready: state.key?('ready') ? state['ready'] : theme.try(:ready),
                  pages: serialize_pages(theme)
                }
              },
              meta: {
                theme_id: theme.id,
                store_id: theme.try(:store_id),
                status: state['status'].presence || default_status(theme),
                version: state['version'].presence || 1
              }
            }
          end

          def page_payload(page)
            state = preferences_hash(page)
            {
              data: {
                id: page.id.to_s,
                type: 'ai_page',
                attributes: {
                  type: page.try(:type),
                  name: page.try(:name),
                  slug: page.try(:slug),
                  meta_title: page.try(:meta_title),
                  meta_description: page.try(:meta_description),
                  meta_keywords: page.try(:meta_keywords),
                  preferences: state['ai_theme'] || state,
                  sections: serialize_sections(page)
                }
              },
              meta: {
                page_id: page.id,
                theme_id: page.try(:pageable_id)
              }
            }
          end

          def section_payload(section)
            state = preferences_hash(section)
            {
              data: {
                id: section.id.to_s,
                type: 'ai_section',
                attributes: {
                  type: section.try(:type),
                  name: section.try(:name),
                  position: section.try(:position),
                  preferences: state['ai_theme'] || state,
                  blocks: serialize_blocks(section)
                }
              },
              meta: {
                section_id: section.id,
                page_id: section.try(:pageable_id)
              }
            }
          end

          private

          def normalize_payload(params)
            raw = if params.respond_to?(:to_unsafe_h)
              params.to_unsafe_h
            else
              params.to_h
            end

            raw.deep_symbolize_keys
          end

          def resolve_theme(payload)
            return @theme if @theme.present?

            theme_id = payload[:theme_id] || payload[:id]
            return theme_by_id(theme_id) if theme_id.present?

            return @store.themes.find_or_initialize_by(name: payload[:name]) if @store.respond_to?(:themes) && payload[:name].present?

            theme_class.new
          end

          def theme_by_id(theme_id)
            return @theme if @theme.present?
            return theme_class.find_by(id: theme_id) if theme_class.respond_to?(:find_by)

            nil
          end

          def theme_class
            Spree::Theme
          end

          def assign_theme_attributes(theme, payload)
            assign_if_possible(theme, :name, payload[:name]) if payload[:name].present?
            assign_if_possible(theme, :store, @store) if @store.present? && theme.respond_to?(:store=)
            assign_if_possible(theme, :default, payload.fetch(:default, false)) if theme.respond_to?(:default=)
            assign_if_possible(theme, :ready, false) if theme.respond_to?(:ready=)
          end

          def sync_pages(theme, spec)
            Array(spec&.fetch(:pages, [])).each do |page_spec|
              upsert_page(theme, page_spec)
            end
          end

          def resolve_page(theme, payload)
            page_class = resolve_page_class(payload)
            scope = if theme.respond_to?(:pages)
              theme.pages
            else
              page_class
            end

            criteria = {}
            criteria[:slug] = payload[:slug].presence || parameterize_identifier(payload[:name] || payload[:title] || page_class.name)
            criteria[:type] = page_class.name if page_class.respond_to?(:name)

            if scope.respond_to?(:find_or_initialize_by)
              scope.find_or_initialize_by(criteria)
            else
              page_class.new
            end
          end

          def assign_page_attributes(page, payload, theme)
            assign_if_possible(page, :pageable, theme) if page.respond_to?(:pageable=)
            assign_if_possible(page, :name, payload[:name].presence || payload[:title].presence || default_name(payload))
            assign_if_possible(page, :slug, payload[:slug].presence || parameterize_identifier(payload[:name] || payload[:title] || default_name(payload))) if page.respond_to?(:slug=)
            assign_if_possible(page, :meta_title, payload[:meta_title]) if payload.key?(:meta_title) && page.respond_to?(:meta_title=)
            assign_if_possible(page, :meta_description, payload[:meta_description]) if payload.key?(:meta_description) && page.respond_to?(:meta_description=)
            assign_if_possible(page, :meta_keywords, payload[:meta_keywords]) if payload.key?(:meta_keywords) && page.respond_to?(:meta_keywords=)
            assign_if_possible(page, :visible, payload.fetch(:visible, true)) if page.respond_to?(:visible=)
            assign_if_possible(page, :preferences, merge_preferences(page.preferences, 'ai_theme' => page_spec_payload(payload))) if page.respond_to?(:preferences=)
            assign_if_possible(page, :type, resolve_page_class(payload).name) if page.respond_to?(:type=)
          end

          def sync_sections(page, sections_spec)
            Array(sections_spec).each do |section_spec|
              upsert_section(page, section_spec)
            end
          end

          def resolve_section(page, payload)
            section_class = resolve_section_class(payload)
            scope = if page.respond_to?(:sections)
              page.sections
            else
              section_class
            end

            criteria = {}
            criteria[:name] = payload[:name].presence || default_name(payload)
            criteria[:type] = section_class.name if section_class.respond_to?(:name)

            if scope.respond_to?(:find_or_initialize_by)
              scope.find_or_initialize_by(criteria)
            else
              section_class.new
            end
          end

          def assign_section_attributes(section, payload, page)
            assign_if_possible(section, :pageable, page) if section.respond_to?(:pageable=)
            assign_if_possible(section, :name, payload[:name].presence || default_name(payload))
            assign_if_possible(section, :position, payload[:position].presence || 1)
            assign_if_possible(section, :preferences, merge_preferences(section.preferences, 'ai_theme' => section_spec_payload(payload))) if section.respond_to?(:preferences=)
            assign_if_possible(section, :type, resolve_section_class(payload).name) if section.respond_to?(:type=)
            assign_if_possible(section, :content, payload[:content].to_json) if payload.key?(:content) && section.respond_to?(:content=)
            assign_if_possible(section, :settings, payload[:settings].to_json) if payload.key?(:settings) && section.respond_to?(:settings=)
          end

          def sync_blocks(section, blocks_spec)
            return if blocks_spec.blank?

            Array(blocks_spec).each do |block_spec|
              upsert_block(section, block_spec)
            end
          end

          def upsert_block(section, payload)
            block_class = resolve_block_class(payload)
            scope = if section.respond_to?(:blocks)
              section.blocks
            else
              block_class
            end

            criteria = {}
            criteria[:name] = payload[:name].presence || default_name(payload)
            criteria[:type] = block_class.name if block_class.respond_to?(:name)

            block = if scope.respond_to?(:find_or_initialize_by)
              scope.find_or_initialize_by(criteria)
            else
              block_class.new
            end

            assign_if_possible(block, :section, section) if block.respond_to?(:section=)
            assign_if_possible(block, :name, payload[:name].presence || default_name(payload))
            assign_if_possible(block, :position, payload[:position].presence || 1)
            assign_if_possible(block, :preferences, merge_preferences(block.preferences, 'ai_theme' => block_spec_payload(payload))) if block.respond_to?(:preferences=)
            assign_if_possible(block, :type, block_class.name) if block.respond_to?(:type=)
            assign_if_possible(block, :content, payload[:content].to_json) if payload.key?(:content) && block.respond_to?(:content=)
            assign_if_possible(block, :settings, payload[:settings].to_json) if payload.key?(:settings) && block.respond_to?(:settings=)
            block.save!
            block
          end

          def resolve_page_class(payload)
            class_name = class_name_for(payload[:class_name] || payload[:type], PAGE_KIND_CLASS_MAP, Spree::Page)
            class_name.safe_constantize || Spree::Page
          end

          def resolve_section_class(payload)
            class_name = class_name_for(payload[:class_name] || payload[:type], {}, Spree::PageSection)
            class_name.safe_constantize || Spree::PageSection
          end

          def resolve_block_class(payload)
            class_name = class_name_for(payload[:class_name] || payload[:type], {}, Spree::PageBlock)
            class_name.safe_constantize || Spree::PageBlock
          end

          def class_name_for(raw_value, mapping, default_class)
            value = raw_value.to_s.strip
            return default_class.name if value.blank?
            return value if value.include?('::')

            mapping.fetch(value, default_class.name)
          end

          def default_name(payload)
            payload[:name].presence || payload[:title].presence || 'Untitled'
          end

          def parameterize_identifier(value)
            value.to_s.parameterize.presence || SecureRandom.hex(6)
          end

          def page_spec_payload(payload)
            payload.slice(:name, :title, :slug, :class_name, :type, :meta_title, :meta_description, :meta_keywords, :visible)
          end

          def section_spec_payload(payload)
            payload.slice(:name, :class_name, :type, :position, :content, :settings)
          end

          def block_spec_payload(payload)
            payload.slice(:name, :class_name, :type, :position, :content, :settings)
          end

          def sync_theme_metadata(theme, payload)
            state = theme_state(theme)
            persist_theme_state!(theme, state.merge(
              'status' => payload[:status],
              'prompt' => payload[:prompt],
              'spec' => payload[:spec] || state['spec'] || {},
              'version' => payload[:version] || state['version'] || 1
            ).compact)
          end

          def persist_theme_state!(theme, payload)
            state = theme_state(theme).merge(payload.deep_stringify_keys)
            assign_if_possible(theme, :preferences, merge_preferences(theme.preferences, 'ai_theme' => state)) if theme.respond_to?(:preferences=)
            theme.save! if theme.respond_to?(:save!)
            state
          end

          def theme_state(theme)
            state = preferences_hash(theme)['ai_theme']
            state = state.to_h if state.respond_to?(:to_h)
            state = {} unless state.is_a?(Hash)
            state.deep_stringify_keys
          end

          def preferences_hash(record)
            raw = if record.respond_to?(:preferences)
              record.preferences
            else
              {}
            end

            raw = raw.to_h if raw.respond_to?(:to_h) && !raw.is_a?(Hash)
            raw = JSON.parse(raw) if raw.is_a?(String) && raw.present?
            raw = {} unless raw.is_a?(Hash)
            raw.deep_stringify_keys
          rescue JSON::ParserError
            {}
          end

          def merge_preferences(existing_preferences, payload)
            preferences = existing_preferences
            preferences = preferences.to_h if preferences.respond_to?(:to_h) && !preferences.is_a?(Hash)
            preferences = JSON.parse(preferences) if preferences.is_a?(String) && preferences.present?
            preferences = {} unless preferences.is_a?(Hash)
            preferences.deep_stringify_keys.merge(payload.deep_stringify_keys)
          rescue JSON::ParserError
            payload.deep_stringify_keys
          end

          def serialize_pages(theme)
            return [] unless theme.respond_to?(:pages)

            Array(theme.pages).map { |page| page_payload(page)[:data][:attributes].merge(id: page.id) }
          end

          def serialize_sections(page)
            return [] unless page.respond_to?(:sections)

            Array(page.sections).map { |section| section_payload(section)[:data][:attributes].merge(id: section.id) }
          end

          def serialize_blocks(section)
            return [] unless section.respond_to?(:blocks)

            Array(section.blocks).map do |block|
              block_state = preferences_hash(block)
              {
                id: block.id,
                type: block.try(:type),
                name: block.try(:name),
                position: block.try(:position),
                preferences: block_state['ai_theme'] || block_state
              }
            end
          end

          def next_version(theme)
            state = theme_state(theme)
            Array(state['versions']).size + 1
          end

          def checksum_for(spec)
            Digest::SHA256.hexdigest(spec.to_json)
          end

          def assign_if_possible(record, attribute, value)
            writer = "#{attribute}="
            record.public_send(writer, value) if record.respond_to?(writer)
          end

          def resolve_theme_store(theme)
            return @store if @store.present?
            return theme.store if theme.respond_to?(:store)

            nil
          end

          def capture_error(exception)
            @errors = Array(exception.respond_to?(:record) ? exception.record.errors.full_messages.presence || exception.message : exception.message)
          end

          def resolve_page_relation(theme)
            return theme.pages if theme.respond_to?(:pages)
            page_class = Spree::Page
            page_class.where(pageable: theme)
          end

          def with_transaction(record, &block)
            if record.respond_to?(:class) && record.class.respond_to?(:transaction)
              record.class.transaction(&block)
            else
              block.call
            end
          end

          def locate_theme(payload)
            return @theme if @theme.present?

            theme_id = payload[:theme_id] || payload[:id]
            return theme_class.find_by(id: theme_id) if theme_id.present? && theme_class.respond_to?(:find_by)

            if @store.respond_to?(:themes)
              return @store.themes.find_or_initialize_by(name: payload[:name]) if payload[:name].present?
              return @store.themes.find_by(default: true) || @store.themes.build
            end

            theme_class.new
          end

          def default_status(theme)
            return 'published' if theme.respond_to?(:ready) && theme.ready

            'draft'
          end
        end
      end
    end
  end
end