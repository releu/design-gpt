web: cd api && BUNDLE_PATH=/app/vendor/bundle bin/rails server -p $PORT -b 0.0.0.0
figma_worker: cd api && BUNDLE_PATH=/app/vendor/bundle bin/jobs --config-file config/queue_figma.yml
worker: cd api && BUNDLE_PATH=/app/vendor/bundle bin/jobs --config-file config/queue_default.yml
release: cd api && BUNDLE_PATH=/app/vendor/bundle bin/rails db:migrate
