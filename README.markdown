What is workflow?
-----------------

This Gem is a fork of Vladimir Dobriakov's [Workflow Gem](http://github.com/geekq/workflow).  Credit goes to him for the core code.  Please read [the original README](http://github.com/geekq/workflow) for a full introduction,
as this README skims through much of that content and focuses on new / changed features.

## What's different in rails-workflow

The primary difference here is the use of [ActiveSupport::Callbacks](http://api.rubyonrails.org/classes/ActiveSupport/Callbacks.html)
to enable a more flexible application of callbacks.
You now have access to the same DSL you're used to from [ActionController Callbacks](http://guides.rubyonrails.org/action_controller_overview.html#filters),
including the ability to wrap state transitions in an `around_transition`, to place
conditional logic on application of callbacks, or to have callbacks run for only
a set of state-change events.

I've made `ActiveRecord` and `ActiveSupport` into runtime dependencies.

You can also take advantage of ActiveRecord's conditional validation syntax,
to apply validations only to specific state transitions.


Installation
------------

    gem install rails-workflow


Ruby Version
--------

I've only tested with Ruby 2.3.  ;)  Time to upgrade.


# Basic workflow definition:

    class Article
      include Workflow
      workflow do
        state :new do
          event :submit, :transitions_to => :awaiting_review
        end
        state :awaiting_review do
          event :review, :transitions_to => :being_reviewed
        end
        state :being_reviewed do
          event :accept, :transitions_to => :accepted
          event :reject, :transitions_to => :rejected
        end
        state :accepted
        state :rejected
      end
    end

Access an object representing the current state of the entity,
including available events and transitions:

    article.current_state
    => #<Workflow::State:0x7f1e3d6731f0 @events={
      :submit=>#<Workflow::Event:0x7f1e3d6730d8 @action=nil,
        @transitions_to=:awaiting_review, @name=:submit, @meta={}>},
      name:new, meta{}

On Ruby 1.9 and above, you can check whether a state comes before or
after another state (by the order they were defined):

    article.current_state
    => being_reviewed
    article.current_state < :accepted
    => true
    article.current_state >= :accepted
    => false
    article.current_state.between? :awaiting_review, :rejected
    => true

Now we can call the submit event, which transitions to the
<tt>:awaiting_review</tt> state:

    article.submit!
    article.awaiting_review? # => true


Callbacks
-------------------------

The DSL syntax here is very much similar to ActionController or ActiveRecord callbacks.

Callbacks with this strategy used the same as [ActionController Callbacks](http://guides.rubyonrails.org/action_controller_overview.html#filters).

You can configure any number of `before`, `around`, or `after` transition callbacks.

`before_transition` and `around_transition` are called in the order they are set,
and `after_transition` callbacks are called in reverse order.

## Around Transition

Allows you to run code surrounding the state transition.

    around_transition :wrap_in_transaction

    def wrap_in_transaction(&block)
      Article.transaction(&block)
    end

You can also define the callback using a block:

    around_transition do |object, transition|
      object.with_lock do
        transition.call
      end
    end

### Replacement for workflow's `on_error` proc:

  around_transition :catch_errors

  def catch_errors
    begin
      yield
    rescue SomeApplicationError => ex
      logger.error 'Oh noes!'
    end
  end


## before_transition

Allows you to run code prior to the state transition.
If you `halt` or `throw :abort` within a `before_transition`, the callback chain
will be halted, the transition will be canceled and the event action
will return false.

    before_transition :check_title

    def check_title
      halt('Title was bad.') unless title == "Good Title"
    end

Or again, in block expression:

    before_transition do |article|
      throw :abort unless article.title == "Good Title"
    end

## After Transition

Runs code after the transition.

    after_transition :check_title


## Prepend Transitions

To add a callback to the beginning of the sequence:

    prepend_before_transition :some_before_transition
    prepend_around_transition :some_around_transition
    prepend_after_transition :some_after_transition

## Skip Transitions

    skip_before_transition :some_before_transition


## Conditions

### if/unless

The callback will run `if` or `unless` the named method returns a truthy value.

    before_transition :do_something, if: :valid?

### only/except

The callback will run `if` or `unless` the event being processed is in the list given

    #  Run this callback only on the `accept` and `publish` events.
    before_transition :do_something, only: [:accept, :publish]

    #  Run this callback on events other than the `accept` and `publish` events.
    before_transition :do_something_else, except: [:accept, :publish]

## Conditional Validations

If you are using `ActiveRecord`, you'll have access to a set of methods which
describe the current transition underway.

Inside the same Article class which was begun above, the following three
validations would all run when the `submit` event is used to transition
from `new` to `awaiting_review`.

    validates :title, presence: true, if: :transitioning_to_awaiting_review?
    validates :body, presence: true, if: :transitioning_from_new?
    validates :author, presence: true, if: :transitioning_via_event_submit?

### Halting if validations fail

    #  This will create a transition callback which will stop the event
    #  and return false if validations fail.
    halt_transition_unless_valid!

    #  This is the same as

### Checking A Transition

Call `can_transition?` to determine whether the validations would pass if a
given event was called:

    if article.can_transition?(:submit)
      #  Do something interesting
    end

# Transition Context

During transition you can refer to the `transition_context` object on your model,
for information about the current transition.  See [Workflow::TransitionContext].

## Naming Event Arguments

If you will normally call each of your events with the same arguments, the following
will help:

    class Article < ApplicationRecord
      include Workflow

      before_transition :check_reviewer

      def check_reviewer
        # Ability is a class from the cancan gem: https://github.com/CanCanCommunity/cancancan
        halt('Access denied') unless Ability.new(transition_context.reviewer).can?(:review, self)
      end

      workflow do
        event_args :reviewer, :reviewed_at
        state :new do
          event :review, transitions_to: :reviewed
        end
        state :reviewed
      end
    end


Transition event handler
------------------------

The best way is to use convention over configuration and to define a
method with the same name as the event. Then it is automatically invoked
when event is raised. For the Article workflow defined earlier it would
be:

    class Article
      def reject
        puts 'sending email to the author explaining the reason...'
      end
    end

`article.review!; article.reject!` will cause state transition to
`being_reviewed` state, persist the new state (if integrated with
ActiveRecord), invoke this user defined `reject` method and finally
persist the `rejected` state.

Note: on successful transition from one state to another the workflow
gem immediately persists the new workflow state with `update_column()`,
bypassing any ActiveRecord callbacks including `updated_at` update.
This way it is possible to deal with the validation and to save the
pending changes to a record at some later point instead of the moment
when transition occurs.

You can also define event handler accepting/requiring additional
arguments:

    class Article
      def review(reviewer = '')
        puts "[#{reviewer}] is now reviewing the article"
      end
    end

    article2 = Article.new
    article2.submit!
    article2.review!('Homer Simpson') # => [Homer Simpson] is now reviewing the article


Integration with ActiveRecord
-----------------------------

Workflow library can handle the state persistence fully automatically. You
only need to define a string field on the table called `workflow_state`
and include the workflow mixin in your model class as usual:

    class Order < ActiveRecord::Base
      include Workflow
      workflow do
        # list states and transitions here
      end
    end

On a database record loading all the state check methods e.g.
`article.state`, `article.awaiting_review?` are immediately available.
For new records or if the `workflow_state` field is not set the state
defaults to the first state declared in the workflow specification. In
our example it is `:new`, so `Article.new.new?` returns true and
`Article.new.approved?` returns false.

At the end of a successful state transition like `article.approve!` the
new state is immediately saved in the database.

You can change this behaviour by overriding `persist_workflow_state`
method.

### Scopes

Workflow library also adds automatically generated scopes with names based on
states names:

    class Order < ActiveRecord::Base
      include Workflow
      workflow do
        state :approved
        state :pending
      end
    end

    # returns all orders with `approved` state
    Order.with_approved_state

    # returns all orders with `pending` state
    Order.with_pending_state

### Wrap State Transition in a locking transaction

Wrap your transition in a locking transaction to ensure that any exceptions
raised later in the transition sequence will roll back earlier changes made to
the record:

    class Order < ActiveRecord::Base
      include Workflow
      workflow transactional: true do
        state :approved
        state :pending
      end
    end

Conditional event transitions
-----------------------------

Conditions can be a "method name symbol" with a corresponding instance method, a `proc` or `lambda` which are added to events, like so:

    state :off
      event :turn_on, :transition_to => :on,
                      :if => :sufficient_battery_level?

      event :turn_on, :transition_to => :low_battery,
                      :if => proc { |device| device.battery_level > 0 }
    end

    # corresponding instance method
    def sufficient_battery_level?
      battery_level > 10
    end

When calling a `device.can_<fire_event>?` check, or attempting a `device.<event>!`, each event is checked in turn:

* With no `:if` check, proceed as usual.
* If an `:if` check is present, proceed if it evaluates to true, or drop to the next event.
* If you've run out of events to check (eg. `battery_level == 0`), then the transition isn't possible.



Accessing your workflow specification
-------------------------------------

You can easily reflect on workflow specification programmatically - for
the whole class or for the current object. Examples:

    article2.current_state.events # lists possible events from here
    article2.current_state.events[:reject].transitions_to # => :rejected

    Article.workflow_spec.states.keys
    #=> [:rejected, :awaiting_review, :being_reviewed, :accepted, :new]

    Article.workflow_spec.state_names
    #=> [:rejected, :awaiting_review, :being_reviewed, :accepted, :new]

    # list all events for all states
    Article.workflow_spec.states.values.collect &:events


You can also store and later retrieve additional meta data for every
state and every event:

    class MyProcess
      include Workflow
      workflow do
        state :main, :meta => {:importance => 8}
        state :supplemental, :meta => {:importance => 1}
      end
    end
    puts MyProcess.workflow_spec.states[:supplemental].meta[:importance] # => 1

The workflow library itself uses this feature to tweak the graphical
representation of the workflow. See below.


Earlier versions
----------------

The `workflow` gem is the work of Vladimir Dobriakov, <http://www.mobile-web-consulting.de>, <http://blog.geekq.net/>.

This project is a fork of his work, and the bulk of the workflow specification code
and DSL are virtually unchanged.


About
-----
Author: Tyler Gannon [https://github.com/tylergannon]

Original Author: Vladimir Dobriakov, <http://www.mobile-web-consulting.de>, <http://blog.geekq.net/>

Copyright (c) 2010-2014 Vladimir Dobriakov, www.mobile-web-consulting.de

Copyright (c) 2008-2009 Vodafone

Copyright (c) 2007-2008 Ryan Allen, FlashDen Pty Ltd

Based on the work of Ryan Allen and Scott Barron

Licensed under MIT license, see the MIT-LICENSE file.
