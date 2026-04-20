module Spree
  module Olitt
    module CloneStore
      class ZoneResolver
        def resolve(source_zone)
          return if source_zone.blank?

          Spree::Zone.find_by(id: source_zone.id) || find_equivalent_zone(source_zone)
        end

        private

        def find_equivalent_zone(source_zone)
          candidate = Spree::Zone.includes(:zone_members).find_by(name: source_zone.name, kind: source_zone.kind)
          return candidate if candidate.present? && same_members?(candidate, source_zone)

          Spree::Zone.includes(:zone_members).detect { |zone| same_identity?(zone, source_zone) && same_members?(zone, source_zone) }
        end

        def same_identity?(candidate, source_zone)
          candidate.kind == source_zone.kind && candidate.name == source_zone.name
        end

        def same_members?(candidate, source_zone)
          zone_members(candidate) == zone_members(source_zone)
        end

        def zone_members(zone)
          zone.zone_members.map { |member| [member.zoneable_type, member.zoneable_id] }.sort
        end
      end
    end
  end
end