class FigmaFileConvertJob < ApplicationJob
  queue_as :figma

  def perform(figma_file_id)
    ff = FigmaFile.find(figma_file_id)

    ff.update!(status: "converting")
    ff.update_progress(step: "converting", step_number: 3, total_steps: 4, message: "Generating React code...")

    # Level 2: Copy react_code for unchanged components before running codegen
    prev = previous_version_file(ff)
    skipped = copy_unchanged_codegen(ff, prev) if prev

    Figma::ReactFactory.new(ff).generate_all

    ff.reload
    sets_with_code = ff.component_sets.joins(:variants).where.not(component_variants: { react_code: [nil, ""] }).distinct.count
    components_with_code = ff.components.where.not(react_code: [nil, ""]).count
    skip_msg = skipped ? " (#{skipped} unchanged, skipped codegen)" : ""
    ff.update_progress(step: "converting", step_number: 3, total_steps: 4,
      message: "Complete - #{sets_with_code} component sets, #{components_with_code} standalone components with React code#{skip_msg}")

    ff.update!(status: "ready", progress: ff.progress.merge(
      "completed_at" => Time.current.iso8601,
      "codegen_version" => Figma::ReactFactory::CODEGEN_VERSION
    ))
    maybe_finalize_design_system(ff)
  rescue => e
    ff.update!(status: "error", progress: ff.progress.merge("error" => e.message))
    maybe_finalize_design_system(ff)
    raise
  end

  private

  def previous_version_file(ff)
    return nil unless ff.design_system && ff.version > 1

    ff.design_system.figma_files
      .where(figma_file_key: ff.figma_file_key, version: ff.version - 1)
      .first
  end

  def copy_unchanged_codegen(ff, prev)
    skipped = 0
    # Skip copying entirely if codegen version changed — the generation logic
    # may produce different source code (e.g. new imports for INSTANCE_SWAP).
    codegen_current = prev.progress&.dig("codegen_version").to_i >= Figma::ReactFactory::CODEGEN_VERSION
    return 0 unless codegen_current
    can_copy_compiled = codegen_current

    # Component sets: copy react_code from previous version's default variant if content_hash matches
    prev_sets = prev.component_sets.includes(:variants).index_by(&:node_id)
    ff.component_sets.includes(:variants).each do |cs|
      prev_cs = prev_sets[cs.node_id]
      next unless prev_cs && cs.content_hash.present? && cs.content_hash == prev_cs.content_hash

      prev_default = prev_cs.default_variant
      cs_default = cs.default_variant
      next unless prev_default && cs_default && prev_default.react_code.present?

      cs_default.update!(
        react_code: prev_default.react_code,
        react_code_compiled: can_copy_compiled ? prev_default.react_code_compiled : nil
      )
      skipped += 1
    end

    # Standalone components: copy react_code if content_hash matches
    prev_comps = prev.components.index_by(&:node_id)
    ff.components.each do |c|
      prev_c = prev_comps[c.node_id]
      next unless prev_c && c.content_hash.present? && c.content_hash == prev_c.content_hash && prev_c.react_code.present?

      c.update!(
        react_code: prev_c.react_code,
        react_code_compiled: can_copy_compiled ? prev_c.react_code_compiled : nil
      )
      skipped += 1
    end

    total = ff.component_sets.count + ff.components.count
    puts "[FigmaFileConvertJob] #{skipped} of #{total} components unchanged, skipping codegen"
    skipped
  end

  def maybe_finalize_design_system(ff)
    ds = ff.design_system
    return unless ds

    siblings = ds.figma_files.where(version: ff.version)
    still_pending = siblings.where(status: %w[pending importing converting comparing])
    return if still_pending.exists?

    if siblings.where(status: "error").exists?
      ds.update!(status: "error", progress: ds.progress.merge("error" => "One or more files failed"))
    else
      ds.update!(status: "ready", version: ff.version, progress: ds.progress.merge("completed_at" => Time.current.iso8601))
    end

    # Schedule delayed shutdown — keeps worker alive for 10 min in case of re-sync
    FigmaWorkerShutdownJob.set(wait: FigmaWorkerShutdownJob::IDLE_TIMEOUT).perform_later
  end
end
