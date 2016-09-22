$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "workflow"
require 'active_record'
require 'sqlite3'
require 'workflow'
require 'byebug'
require 'cancan'
require_relative 'support/active_record_setup'
require_relative 'support/helpers'

ActiveRecord::Migration.verbose = false

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # config.include FeatureSpecMacros, :type => :feature
  # config.include FactoryGirl::Syntax::Methods

  # Capybara.javascript_driver = :webkit
  # Capybara::Screenshot.autosave_on_failure = false
  config.run_all_when_everything_filtered = true
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.include_context "ActiveRecord Setup"
  config.include_context "Shared Helpers"

  config.alias_it_should_behave_like_to :it_has_the_behavior_of, 'has the behavior:'

  # VCR.configure do |config|
  #   config.cassette_library_dir = "support/cassettes"
  #   config.hook_into :webmock # or :fakeweb
  #   config.ignore_hosts '127.0.0.1'
  #   config.default_cassette_options = {
  #     :record => :once,
  #     :match_requests_on => [:method, :host, :path]
  #   }
  # end

  # config.infer_spec_type_from_file_location!
  #
  # config.filter_rails_from_backtrace!
  #
  # config.use_transactional_fixtures = false
  # DatabaseCleaner.strategy = :truncation, {except: [ActiveRecord::InternalMetadata.table_name]}
  # config.before(:each, type: :view) do
  #   DatabaseCleaner.clean_with :truncation, except: [ActiveRecord::InternalMetadata.table_name]
  # end
  # config.before(:each, type: :model) do
  #   DatabaseCleaner.clean_with :truncation, except: [ActiveRecord::InternalMetadata.table_name]
  # end
  # config.before(:each, type: :feature) do
  #   DatabaseCleaner.clean_with :truncation, except: [ActiveRecord::InternalMetadata.table_name]
  #   create :flavor, name: 'Ginger Teriyaki', abbreviation: 'T', slug: 'ginger-teriyaki'
  #   create :flavor, name: 'Original', abbreviation: 'O', slug: 'original'
  #   create :flavor, name: 'Chili Lime', abbreviation: 'L', slug: 'chili-lime'  end
end
