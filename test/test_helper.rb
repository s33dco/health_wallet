ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # NOTE: Tests are intentionally *not* parallelized. ActiveRecord gives each parallel
    # worker its own SQLite database, but Mongoid points every worker at the single
    # `health_wallet_test` database. The `Mongoid.purge!` below would then let one worker
    # wipe another worker's in-flight documents, producing flaky failures. Running
    # single-threaded keeps the Mongo-backed tests deterministic.

    # Add more helper methods to be used by all tests here...

    # Clean up MongoDB before each test. This wipes all Mongoid collections, so individual
    # tests don't need their own teardown to reset Patient/Assessment/ObservationCode data.
    setup do
      Mongoid.purge!
    end
  end
end
