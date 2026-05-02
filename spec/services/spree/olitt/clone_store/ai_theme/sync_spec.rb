require 'spec_helper'

module AiThemeSyncSpecSupport
  class FakeCollection
    attr_reader :records

    def initialize(klass)
      @klass = klass
      @records = []
    end

    def find_or_initialize_by(criteria)
      records.find { |record| criteria.all? { |key, value| record.public_send(key) == value } } || begin
        record = @klass.new
        criteria.each { |key, value| record.public_send("#{key}=", value) }
        records << record
        record
      end
    end

    def find_by(criteria)
      records.find { |record| criteria.all? { |key, value| record.public_send(key) == value } }
    end

    def build
      record = @klass.new
      records << record
      record
    end

    def each(&block)
      records.each(&block)
    end

    def map(&block)
      records.map(&block)
    end

    def size
      records.size
    end

    def to_a
      records.dup
    end
  end

  class FakeBlock
    attr_accessor :id, :name, :position, :type, :preferences, :content, :settings, :section

    def initialize
      @preferences = {}
    end

    def save!
      self.id ||= SecureRandom.random_number(100_000)
      true
    end
  end

  class FakeSection
    attr_accessor :id, :name, :position, :type, :preferences, :content, :settings, :pageable

    def initialize
      @preferences = {}
      @blocks = FakeCollection.new(FakeBlock)
    end

    def blocks
      @blocks
    end

    def save!
      self.id ||= SecureRandom.random_number(100_000)
      true
    end
  end

  class FakePage
    attr_accessor :id, :name, :slug, :type, :meta_title, :meta_description, :meta_keywords, :visible, :preferences, :pageable

    def initialize
      @preferences = {}
      @sections = FakeCollection.new(FakeSection)
    end

    def sections
      @sections
    end

    def save!
      self.id ||= SecureRandom.random_number(100_000)
      true
    end
  end

  class FakeTheme
    attr_accessor :id, :name, :store, :default, :ready, :preferences

    def self.transaction
      yield
    end

    def initialize
      @preferences = {}
      @pages = FakeCollection.new(FakePage)
      @ready = true
      @default = false
    end

    def pages
      @pages
    end

    def save!
      self.id ||= SecureRandom.random_number(100_000)
      true
    end

    def reload
      self
    end

    def update!(attributes)
      attributes.each { |key, value| public_send("#{key}=", value) }
      true
    end
  end

  class FakeThemesRelation
    attr_reader :records

    def initialize
      @records = []
    end

    def find_or_initialize_by(criteria)
      records.find { |record| criteria.all? { |key, value| record.public_send(key) == value } } || begin
        record = FakeTheme.new
        criteria.each { |key, value| record.public_send("#{key}=", value) }
        records << record
        record
      end
    end

    def find_by(criteria)
      records.find { |record| criteria.all? { |key, value| record.public_send(key) == value } }
    end

    def build
      record = FakeTheme.new
      records << record
      record
    end
  end

  class FakeStore
    attr_reader :themes

    def initialize
      @themes = FakeThemesRelation.new
    end
  end
end

describe Spree::Olitt::CloneStore::AiTheme::Sync do
  include AiThemeSyncSpecSupport

  let(:store) { FakeStore.new }
  let(:service) { described_class.new(store: store) }

  let(:theme_params) do
    {
      name: 'Modern Fashion',
      prompt: 'Build a premium store',
      spec: {
        pages: [
          {
            type: 'homepage',
            name: 'Homepage',
            slug: '/',
            class_name: 'AiThemeSyncSpecSupport::FakePage',
            sections: [
              {
                type: 'hero',
                name: 'Hero',
                position: 1,
                class_name: 'AiThemeSyncSpecSupport::FakeSection',
                content: { headline: 'Hello' },
                blocks: [
                  {
                    type: 'text',
                    name: 'Headline',
                    position: 1,
                    class_name: 'AiThemeSyncSpecSupport::FakeBlock',
                    content: { body: 'Welcome' }
                  }
                ]
              }
            ]
          }
        ]
      }
    }
  end

  it 'upserts a theme with nested pages, sections, and blocks' do
    theme = service.upsert_theme(theme_params)

    expect(theme).to be_a(FakeTheme)
    expect(theme.name).to eq('Modern Fashion')
    expect(theme.preferences.dig('ai_theme', 'status')).to eq('draft')
    expect(theme.preferences.dig('ai_theme', 'spec', 'pages').first['name']).to eq('Homepage')
    expect(theme.pages.size).to eq(1)

    page = theme.pages.records.first
    expect(page.name).to eq('Homepage')
    expect(page.sections.size).to eq(1)
    expect(page.sections.records.first.blocks.size).to eq(1)
  end

  it 'serializes the theme payload' do
    theme = service.upsert_theme(theme_params)

    payload = service.theme_payload(theme)

    expect(payload[:data][:attributes][:name]).to eq('Modern Fashion')
    expect(payload[:data][:attributes][:pages].first[:name]).to eq('Homepage')
    expect(payload[:data][:attributes][:pages].first[:sections].first[:name]).to eq('Hero')
  end

  it 'creates preview and publish state' do
    theme = service.upsert_theme(theme_params)

    preview_token = service.preview_theme(theme)
    expect(preview_token).to be_present
    expect(theme.preferences.dig('ai_theme', 'status')).to eq('preview')

    published = service.publish_theme(theme)
    expect(published.ready).to be(true)
    expect(theme.preferences.dig('ai_theme', 'status')).to eq('published')
  end

  it 'snapshots versions' do
    theme = service.upsert_theme(theme_params)

    version = service.snapshot_version(theme, spec: theme_params[:spec], checksum: 'sha256:abc123')

    expect(version['revision']).to eq(1)
    expect(version['checksum']).to eq('sha256:abc123')
    expect(theme.preferences.dig('ai_theme', 'versions').size).to eq(1)
  end
end