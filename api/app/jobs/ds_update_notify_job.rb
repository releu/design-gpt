class DsUpdateNotifyJob < ApplicationJob
  queue_as :default

  def perform(design_system_id)
    ds = DesignSystem.find(design_system_id)

    designs = Design.where(design_system_id: ds.id, status: "ready")

    designs.find_each do |design|
      # Skip designs that have no iteration with a tree (nothing to rebuild)
      last_tree = design.iterations.order(:id).where.not(tree: nil).last
      next unless last_tree

      design.chat_messages.create!(
        author: "system",
        message: "Design system was updated. Components may have changed.",
        action: "rebuild"
      )
    end
  end
end
