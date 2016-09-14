require File.join(File.dirname(__FILE__), 'test_helper')

$VERBOSE = false
require 'active_record'
require 'sqlite3'
require 'workflow'
require 'mocha/setup'
#require 'stringio'
#require 'ruby-debug'

#ActiveRecord::Migration.verbose = false

class Order < ActiveRecord::Base
  include Workflow
  workflow do # empty workflow that will be loaded from json
  end
end

class JsonLoadTest < ActiveRecordTestCase

  def setup
    super

    ActiveRecord::Schema.define do
      create_table :orders do |t|
        t.string :title, :null => false
        t.string :workflow_state
      end
    end

    exec "INSERT INTO orders(title, workflow_state) VALUES('some order', 'open')"

    Order.workflow_spec.from_json_file!('workflows/order.wf')
    Order.reassign_workflow!
  end

  def assert_state(title, expected_state, klass = Order)
    o = klass.find_by_title(title)
    assert_equal expected_state, o.read_attribute(klass.workflow_column)
    o
  end

  test 'order workflow load from json file' do
    assert Order.workflow_spec.from_json_file!('workflows/order.wf')
    assert_not_nil Order.workflow_spec.initial_state
    assert_equal Order.workflow_spec.initial_state.class , Workflow::State
  end

  test 'number of state keys is the expected one after order workflow load from json file' do
    assert_equal Order.workflow_spec.states.keys.length, 5
  end

  test 'number of state values is the expected one after order workflow load from json file' do
    assert_equal Order.workflow_spec.states.values.length, 5
  end

  test 'State class is the expected one after order workflow load from json file' do
    assert_equal Order.workflow_spec.states.values.first.class, Workflow::State
  end

  test 'State name class is the expected one after order workflow load from json file' do
    assert_equal Order.workflow_spec.states.values.first.name.class, Symbol
  end

  test 'State Meta attibute class is the expected one after order workflow load from json file' do
    assert_equal Order.workflow_spec.states.values.first.meta.class, Hash
  end

  test 'State Meta attribute is loaded after order workflow load from json file' do
    assert_equal Order.workflow_spec.states.values.first.meta.keys.length, 0
  end

  test 'Workflow specification is assigned to State after order workflow load from json file' do
    assert_equal Order.workflow_spec.states.values.first.spec.class, Workflow::Specification
  end

  test 'Workflow specification assigned to State after order workflow load from json file is the workflow_spec' do
    assert_equal Order.workflow_spec.states.values.first.spec, Order.workflow_spec
  end

  test 'Workflow events list class is the expected one after order workflow load from json file is the workflow_spec' do
    assert_equal Order.workflow_spec.states.values.first.events.class, Workflow::EventCollection
  end

  test 'Workflow event class is the expected one after order workflow load from json file is the workflow_spec' do
    assert_equal Order.workflow_spec.states.values.first.events.values.first[0].class, Workflow::Event
  end

  test 'Workflow event class for name is the expected one after order workflow load from json file is the workflow_spec' do
    assert_equal Order.workflow_spec.states.values.first.events.values.first[0].name.class, Symbol
  end

  test 'expected number of events per state after order workflow load from json file is the workflow_spec' do
    assert_equal Order.workflow_spec.states[:open].events.length, 1
    assert_equal Order.workflow_spec.states[:awaiting_review].events.length, 1
    assert_equal Order.workflow_spec.states[:being_reviewed].events.length, 2
    assert_equal Order.workflow_spec.states[:accepted].events.length, 0
    assert_equal Order.workflow_spec.states[:rejected].events.length, 0
  end

  test 'existing methods per events' do
    o = assert_state('some order','open')
    assert o.method_exists?(:contacted!)
    assert o.method_exists?(:review!)
    assert o.method_exists?(:accept!)
    assert o.method_exists?(:can_contacted?)
    assert o.method_exists?(:can_review?)
    assert o.method_exists?(:can_accept?)
    assert o.method_exists?(:open?)
    assert o.method_exists?(:awaiting_review?)
    assert o.method_exists?(:being_reviewed?)
    assert o.method_exists?(:accepted?)
    assert o.method_exists?(:rejected?)
  end

  test 'validate state flow 1 after order workflow load from json file is the workflow_spec' do
    o = assert_state('some order','open')
    o.contacted!
    o = assert_state('some order','awaiting_review')
    o.review!
    o = assert_state('some order','being_reviewed')
    o.accept!
    assert_state('some order','accepted')
  end

  test 'validate state flow 2 after order workflow load from json file is the workflow_spec' do
    o = assert_state('some order','open')
    o.contacted!
    o = assert_state('some order','awaiting_review')
    o.review!
    o = assert_state('some order','being_reviewed')
    o.reject!
    assert_state('some order','rejected')
  end
  
  test 'Loaded Order workflow persists as JSON 2' do
    assert_equal Order.workflow_spec.to_json, '{"states":{"open":{"name":"open","meta":{},"events":'\
    '{"contacted":[{"name":"contacted","transitions_to":"awaiting_review","meta":{},"action":null,'\
    '"condition":null}]}},"awaiting_review":{"name":"awaiting_review","meta":{},"events":{"review":'\
    '[{"name":"review","transitions_to":"being_reviewed","meta":{},"action":null,"condition":null}]}},'\
    '"being_reviewed":{"name":"being_reviewed","meta":{},"events":{"accept":[{"name":"accept","transitions_to":'\
    '"accepted","meta":{},"action":null,"condition":null}],"reject":[{"name":"reject","transitions_to":"rejected",'\
    '"meta":{},"action":null,"condition":null}]}},"accepted":{"name":"accepted","meta":{},"events":{}},"rejected":'\
    '{"name":"rejected","meta":{},"events":{}}},"initial_state":{"name":"open","meta":{},"events":{"contacted":'\
    '[{"name":"contacted","transitions_to":"awaiting_review","meta":{},"action":null,"condition":null}]}},"meta":{}}'
  end

end

