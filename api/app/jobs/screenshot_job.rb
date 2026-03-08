class ScreenshotJob < ApplicationJob
  queue_as :default

  def perform(iteration_id)
    iteration = Iteration.find(iteration_id)

    return unless iteration.design.component_libraries.any?

    width = 393
    height = 800

    renderer_url = "http://127.0.0.1:#{ENV.fetch('PORT', 3000)}/api/iterations/#{iteration_id}/renderer"

    browser = Ferrum::Browser.new(
      headless: true,
      browser_path: ENV["GOOGLE_CHROME_BIN"],
      browser_options: { "no-sandbox": nil, "disable-setuid-sandbox": nil },
      window_size: [width, height],
      extensions: []
    )
    page = browser.create_page
    page.command("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: true)

    page.goto(renderer_url)
    page.network.wait_for_idle

    page.evaluate <<~JS
      window.postMessage({
        type: "render",
        jsx: `#{iteration.jsx}`,
      }, location.origin);
    JS

    tmp = Tempfile.new(["shot", ".png"]).tap(&:binmode)
    page.screenshot(path: tmp.path, full: true, format: :png)

    render = Render.create!(:image => File.read(tmp.path))
    iteration.update(:render => render)

  ensure
    page&.close
    browser&.quit
    tmp&.close
    tmp&.unlink
  end
end
