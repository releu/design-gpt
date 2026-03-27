namespace :pipeline do
  desc "Full component quality grind: screenshot every variant, pixel diff, AI inspect"
  task :grind, [:ds_name, :force] => :environment do |_t, args|
    force = args[:force] == "force"
    PipelineGrind.new(args[:ds_name], force: force).run
  end

  desc "Quick test: max 10 variants per component set. Optional: pipeline:quick[ComponentName]"
  task :quick, [:component_name] => :environment do |_t, args|
    PipelineGrind.new.quick_test(args[:component_name])
  end

  desc "Pre-download all Figma screenshots (run before grind to avoid rate limits)"
  task :cache_figma, [:ds_name] => :environment do |_t, args|
    PipelineGrind.new(args[:ds_name]).cache_figma_screenshots
  end
end
