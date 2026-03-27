module Admin
  class PipelineReviewsController < ActionController::Base
    skip_forgery_protection

    # Index: list all components sorted by diff (worst first)
    # "ready_to_review" items shown at top
    def index
      @ready = PipelineReview.ready_to_review.includes(:component_set).by_match
      @all = PipelineReview.where.not(status: "ready_to_review").includes(:component_set).by_match
      render html: index_html.html_safe, layout: false
    end

    # Show: single component detail with variants, comments, controls
    def show
      @review = PipelineReview.includes(component_set: :variants).find(params[:id])
      @cs = @review.component_set
      render html: show_html.html_safe, layout: false
    end

    # Update: save comment and/or change status
    def update
      @review = PipelineReview.find(params[:id])
      @review.update!(review_params)
      redirect_to admin_pipeline_review_path(@review)
    end

    # Serve comparison/figma/react/diff images from tmp
    def image
      review = PipelineReview.includes(:component_set).find(params[:id])
      cs_name = review.component_set.name
      variant_name = params[:variant]
      type = params[:type] # comparison, figma, react, diff

      path = case type
      when "comparison" then PipelineReviewService.comparison_path(cs_name, variant_name)
      when "figma" then PipelineReviewService.figma_screenshot_path(cs_name, variant_name)
      when "react" then PipelineReviewService.react_screenshot_path(cs_name, variant_name)
      when "diff" then PipelineReviewService.diff_screenshot_path(cs_name, variant_name)
      end

      if path && File.exist?(path)
        send_file path, type: "image/png", disposition: "inline"
      else
        head :not_found
      end
    end

    # Mark all "need_fix" as "fixing" (for claude code to pick up)
    def mark_fixing
      PipelineReview.need_fix.update_all(status: "fixing")
      redirect_to admin_pipeline_reviews_path
    end

    # Re-run comparison for one component
    def rerun
      review = PipelineReview.includes(:component_set).find(params[:id])
      PipelineReviewService.new.run_one(review.component_set)
      redirect_to admin_pipeline_review_path(review)
    end

    private

    def review_params
      params.permit(:comment, :status)
    end

    def index_html
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Figma → React Pipeline Review</title>
          <style>#{common_css}</style>
        </head>
        <body>
          <div class="container">
            <h1>Figma → React Pipeline Review</h1>
            <p class="stats">
              Total: #{@ready.size + @all.size} components |
              Ready to review: #{@ready.size} |
              Need fix: #{@all.count { |r| r.status == "need_fix" }} |
              Approved: #{@all.count { |r| r.status == "approved" }} |
              Pending: #{@all.count { |r| r.status == "pending" }}
            </p>

            #{if @ready.any?
              "<h2 class='section-header ready'>Ready to Review (#{@ready.size})</h2>" +
              component_table(@ready)
            else
              ""
            end}

            <h2 class="section-header">All Components</h2>
            #{component_table(@all)}
          </div>
        </body>
        </html>
      HTML
    end

    def component_table(reviews)
      rows = reviews.map do |r|
        cs = r.component_set
        match_class = if r.best_match_percent.nil? then "unknown"
                      elsif r.best_match_percent >= 99.5 then "excellent"
                      elsif r.best_match_percent >= 95 then "good"
                      elsif r.best_match_percent >= 85 then "fair"
                      else "poor"
                      end
        warn_count = (cs.validation_warnings || []).size
        warn_badge = warn_count > 0 ? "<span class=\"warn-badge\" title=\"#{warn_count} warnings\">#{warn_count}</span>" : ""
        <<~ROW
          <tr class="#{match_class}">
            <td><a href="/admin/figma2react/#{r.id}">#{ERB::Util.html_escape(cs.name)}</a> #{warn_badge}</td>
            <td class="match">#{r.best_match_percent&.round(1) || '—'}%</td>
            <td class="match">#{r.avg_match_percent&.round(1) || '—'}%</td>
            <td>#{r.variant_scores&.size || 0}</td>
            <td><span class="status #{r.status}">#{r.status}</span></td>
            <td class="comment">#{ERB::Util.html_escape(r.comment.to_s.truncate(80))}</td>
          </tr>
        ROW
      end.join

      <<~TABLE
        <table>
          <thead>
            <tr>
              <th>Component</th>
              <th>Best %</th>
              <th>Avg %</th>
              <th>Variants</th>
              <th>Status</th>
              <th>Comment</th>
            </tr>
          </thead>
          <tbody>#{rows}</tbody>
        </table>
      TABLE
    end

    def show_html
      figma_url = @cs.figma_url
      ff = @cs.figma_file
      renderer_url = "/api/figma-files/#{ff.id}/renderer" if ff

      ws = @cs.validation_warnings || []
      warnings_html = if ws.any?
        items = ws.map { |w| "<li>#{ERB::Util.html_escape(w)}</li>" }.join
        "<div class=\"warnings-box\"><div class=\"warnings-title\">Warnings (#{ws.size})</div><ul>#{items}</ul></div>"
      else
        ""
      end

      variant_cards = (@review.variant_scores || []).sort_by { |v| v["match"] || 0 }.map do |vs|
        vname = vs["name"]
        match = vs["match"]
        match_class = if match.nil? then "unknown"
                      elsif match >= 99.5 then "excellent"
                      elsif match >= 95 then "good"
                      elsif match >= 85 then "fair"
                      else "poor"
                      end

        variant = @cs.variants.find { |v| v.name == vname }
        variant_figma_url = variant&.figma_url

        <<~CARD
          <div class="variant-card #{match_class}">
            <div class="variant-header">
              <h3>#{ERB::Util.html_escape(vname)}</h3>
              <span class="match">#{match&.round(1) || '—'}%</span>
              #{variant_figma_url ? "<a href=\"#{variant_figma_url}\" target=\"_blank\" class=\"btn btn-small\">Figma</a>" : ""}
            </div>
            <div class="variant-images">
              <div class="variant-col">
                <div class="image-label">Figma</div>
                <img src="/admin/figma2react/#{@review.id}/image?variant=#{ERB::Util.url_encode(vname)}&type=figma" loading="lazy" onerror="this.parentElement.innerHTML='<em>no image</em>'">
              </div>
              <div class="variant-col">
                <div class="image-label">React</div>
                <img src="/admin/figma2react/#{@review.id}/image?variant=#{ERB::Util.url_encode(vname)}&type=react" loading="lazy" onerror="this.parentElement.innerHTML='<em>no image</em>'">
              </div>
            </div>
            <div class="variant-diff">
              <div class="image-label">Diff</div>
              <img src="/admin/figma2react/#{@review.id}/image?variant=#{ERB::Util.url_encode(vname)}&type=diff" loading="lazy" onerror="this.parentElement.innerHTML='<em>no image</em>'">
            </div>
          </div>
        CARD
      end.join

      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{ERB::Util.html_escape(@cs.name)} — Pipeline Review</title>
          <style>#{common_css}#{show_css}</style>
        </head>
        <body>
          <div class="container">
            <a href="/admin/figma2react" class="back">&larr; Back to list</a>
            <h1>#{ERB::Util.html_escape(@cs.name)}</h1>

            <div class="meta">
              <span class="status #{@review.status}">#{@review.status}</span>
              <span>Best: #{@review.best_match_percent&.round(1) || '—'}%</span>
              <span>Avg: #{@review.avg_match_percent&.round(1) || '—'}%</span>
              <span>Variants: #{@review.variant_scores&.size || 0}</span>
            </div>

            #{warnings_html}

            <div class="links">
              #{figma_url ? "<a href=\"#{figma_url}\" target=\"_blank\" class=\"btn\">Open in Figma</a>" : ""}
              #{renderer_url ? "<a href=\"#{renderer_url}\" target=\"_blank\" class=\"btn\">React Renderer</a>" : ""}
              <a href="/admin/figma2react/#{@review.id}/rerun" class="btn btn-secondary">Re-run Comparison</a>
            </div>

            <form action="/admin/figma2react/#{@review.id}" method="post" class="review-form">
              <textarea name="comment" rows="3" placeholder="Your notes about what's wrong...">#{ERB::Util.html_escape(@review.comment.to_s)}</textarea>
              <div class="actions">
                <button type="submit" name="status" value="need_fix" class="btn btn-danger">Mark: Need Fix</button>
                <button type="submit" name="status" value="approved" class="btn btn-success">Approve</button>
                <button type="submit" name="status" value="pending" class="btn btn-secondary">Reset to Pending</button>
              </div>
            </form>

            <h2>Variants (sorted by match %)</h2>
            #{variant_cards}
          </div>
        </body>
        </html>
      HTML
    end

    def common_css
      <<~CSS
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #0d1117; color: #c9d1d9; padding: 20px; }
        .container { max-width: 1600px; margin: 0 auto; }
        h1 { margin-bottom: 10px; color: #f0f6fc; }
        h2 { margin: 20px 0 10px; color: #f0f6fc; }
        .section-header { padding: 8px 12px; background: #161b22; border-radius: 6px; }
        .section-header.ready { background: #1a3a2a; border: 1px solid #238636; }
        .stats { color: #8b949e; margin-bottom: 16px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        th { text-align: left; padding: 8px 12px; background: #161b22; color: #8b949e; font-size: 12px; text-transform: uppercase; border-bottom: 1px solid #30363d; }
        td { padding: 8px 12px; border-bottom: 1px solid #21262d; }
        tr:hover { background: #161b22; }
        tr.excellent td { }
        tr.good td { }
        tr.fair td { background: #1c1a0f; }
        tr.poor td { background: #2a1215; }
        .match { font-family: monospace; font-weight: bold; }
        tr.excellent .match { color: #3fb950; }
        tr.good .match { color: #58a6ff; }
        tr.fair .match { color: #d29922; }
        tr.poor .match { color: #f85149; }
        .warn-badge { display: inline-block; background: #2e1a00; color: #d29922; font-size: 11px; font-weight: 600; padding: 1px 6px; border-radius: 8px; margin-left: 6px; }
        .warnings-box { background: #2e1a00; border: 1px solid #d29922; border-radius: 8px; padding: 12px 16px; margin: 12px 0; }
        .warnings-title { color: #d29922; font-weight: 600; font-size: 14px; margin-bottom: 8px; }
        .warnings-box ul { margin: 0; padding-left: 20px; }
        .warnings-box li { color: #c9d1d9; font-size: 13px; margin-bottom: 4px; }
        .status { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 12px; font-weight: 500; }
        .status.pending { background: #30363d; color: #8b949e; }
        .status.need_fix { background: #3d1e20; color: #f85149; }
        .status.fixing { background: #2e1a00; color: #d29922; }
        .status.ready_to_review { background: #1a3a2a; color: #3fb950; }
        .status.approved { background: #1a3a2a; color: #3fb950; border: 1px solid #238636; }
        .comment { color: #8b949e; font-size: 13px; }
        a { color: #58a6ff; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .back { display: inline-block; margin-bottom: 12px; color: #8b949e; }
        .btn { display: inline-block; padding: 6px 16px; border-radius: 6px; border: 1px solid #30363d; background: #21262d; color: #c9d1d9; cursor: pointer; font-size: 14px; text-decoration: none; margin-right: 8px; }
        .btn:hover { background: #30363d; text-decoration: none; }
        .btn-danger { background: #3d1e20; border-color: #f85149; color: #f85149; }
        .btn-danger:hover { background: #5a2028; }
        .btn-success { background: #1a3a2a; border-color: #238636; color: #3fb950; }
        .btn-success:hover { background: #244e33; }
        .btn-secondary { background: #161b22; border-color: #30363d; color: #8b949e; }
      CSS
    end

    def show_css
      <<~CSS
        .meta { display: flex; gap: 16px; align-items: center; margin: 12px 0; }
        .links { margin: 16px 0; }
        .review-form { background: #161b22; padding: 16px; border-radius: 8px; margin: 16px 0; }
        .review-form textarea { width: 100%; background: #0d1117; border: 1px solid #30363d; color: #c9d1d9; padding: 8px; border-radius: 6px; font-family: inherit; font-size: 14px; resize: vertical; }
        .review-form .actions { margin-top: 12px; display: flex; gap: 8px; }
        .variant-card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 20px; margin-bottom: 24px; min-height: 80vh; }
        .variant-card.poor { border-color: #f85149; }
        .variant-card.fair { border-color: #d29922; }
        .variant-card.good { border-color: #58a6ff; }
        .variant-card.excellent { border-color: #238636; }
        .variant-header { display: flex; align-items: center; gap: 16px; margin-bottom: 16px; padding-bottom: 12px; border-bottom: 1px solid #30363d; }
        .variant-header h3 { flex: 1; color: #f0f6fc; font-size: 18px; }
        .variant-header .match { font-family: monospace; font-size: 24px; font-weight: bold; }
        .variant-card.excellent .variant-header .match { color: #3fb950; }
        .variant-card.good .variant-header .match { color: #58a6ff; }
        .variant-card.fair .variant-header .match { color: #d29922; }
        .variant-card.poor .variant-header .match { color: #f85149; }
        .variant-images { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px; }
        .variant-col { text-align: center; }
        .variant-col img, .variant-diff img { max-width: 100%; border: 1px solid #30363d; border-radius: 4px; background: #fff; }
        .variant-diff { text-align: center; }
        .image-label { font-size: 13px; color: #8b949e; margin-bottom: 6px; font-weight: 500; text-transform: uppercase; letter-spacing: 0.5px; }
        .btn-small { padding: 4px 10px; font-size: 12px; }
      CSS
    end
  end
end
