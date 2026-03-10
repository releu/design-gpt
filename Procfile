web: cd api && BUNDLE_PATH=/app/vendor/bundle bin/rails server -p $PORT -b 0.0.0.0
worker: cd api && BUNDLE_PATH=/app/vendor/bundle bin/jobs
release: cd api && BUNDLE_PATH=/app/vendor/bundle bin/rails db:migrate
