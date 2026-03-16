Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_ORIGIN", "https://jan-designer.dev, http://localhost:5173, https://design-gpt.localtest.me").split(/[,\s]+/)
    resource "*", headers: :any, methods: %i[get post options], expose: %w[Authorization]
  end

  # Public export endpoint (used by Figma plugin — sandboxed iframe, null origin)
  allow do
    origins "*"
    resource "/api/iterations/*/export-figma", headers: :any, methods: %i[get options]
  end
end
