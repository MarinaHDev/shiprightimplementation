module Auditable
  extend ActiveSupport::Concern

  class_methods do
    def audited(only: nil, **paper_trail_options)
      options = paper_trail_options.dup
      options[:only] = Array(only).map(&:to_s) if only
      has_paper_trail(**options)
    end
  end

  # Returns this record's audit trail oldest-first as a stable struct, so views
  # and tests don't have to know about PaperTrail's API surface.
  def audit_history
    versions.reorder(created_at: :asc).map do |version|
      AuditEntry.new(
        at: version.created_at,
        event: version.event,
        whodunnit: version.whodunnit,
        changes: version.object_changes ? version.changeset : {}
      )
    end
  end

  AuditEntry = Data.define(:at, :event, :whodunnit, :changes) do
    def actor_label
      whodunnit.presence || "system"
    end
  end
end
