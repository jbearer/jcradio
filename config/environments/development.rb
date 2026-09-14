Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Load app/ classes at boot instead of on first use. Lazy autoloading is not
  # thread-safe: two requests arriving together right after a restart (a browser
  # SSE reconnect plus a page load is enough) raised "Circular dependency detected
  # while autoloading constant ..." and the losing SSE stream stayed dead until
  # the tab was reloaded. Costs a few seconds of boot; code still reloads on edit.
  config.eager_load = true

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  #config.action_controller.perform_caching = false
  config.action_controller.perform_caching = true # Change to try speed up web load

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  # On the Pi, debug mode cost ~100 ms of asset-tag helpers per page plus 33
  # separate asset requests; concatenated bundles are still served dynamically.
  config.assets.debug = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  config.preload_frameworks = true
  config.allow_concurrency = true
end
