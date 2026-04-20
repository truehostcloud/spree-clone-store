require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      describe ZoneResolver do
        describe '#resolve' do
          it 'returns the source zone when the zone still exists by id' do
            source_zone = instance_double('Spree::Zone', id: 5)

            allow(Spree::Zone).to receive(:find_by).with(id: 5).and_return(:resolved_zone)

            expect(described_class.new.resolve(source_zone)).to eq(:resolved_zone)
          end
        end
      end
    end
  end
end