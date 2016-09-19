
ActiveSupport-Style Callbacks
-----------------------------

Enable ActiveSupport - Style callbacks by simply requiring the file:

    require 'workflow/adapters/active_support_callbacks'

And then write your class something like this:

    class Article < ActiveRecord::Base
      include Workflow

      before_transition :set_attributes_from_event_args, if: :some_method?
      before_transition :do_something_else, only: [:submit, :review]

      before_transition except: :reject do |article|
        throw :abort unless article.title == "Invalid Title"
      end

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

## Callback Types

Callbacks with this strategy used the same as [ActionController Callbacks](http://guides.rubyonrails.org/action_controller_overview.html#filters).

You can configure any number of `before`, `around`, or `after` transition callbacks.

`before_transition` and `around_transition` are called in the order they are set,
and `after_transition` callbacks are called in reverse order.

### Around Transition

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

### Before Transition

Allows you to run code prior to the state transition.
If you `throw :abort` within a `before_transition`, the callback chain
will be halted prior, the transition will be canceled and the event action
will return false.

    before_transition :check_title

    def check_title
      throw :abort unless title == "Good Title"
    end

Or again, in block expression:

    before_transition do |article|
      throw :abort unless article.title == "Good Title"
    end

### After Transition

Runs code after the transition.

    after_transition :check_title


### Prepend Transitions

To add a callback to the beginning of the sequence:

    prepend_before_transition :some_before_transition
    prepend_around_transition :some_around_transition
    prepend_after_transition :some_after_transition

### Skip Transitions

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
    halt_unless_valid!

### Checking A Transition

Call `can_transition?` to determine whether the validations would pass if a
given event was called:

    if article.can_transition?(:submit)
      #  Do something interesting
    end


About
-----

Author: Tyler Gannon, <https://github.com/tylergannon>

Copyright (c) 2010-2014 Vladimir Dobriakov, www.mobile-web-consulting.de

Copyright (c) 2008-2009 Vodafone

Copyright (c) 2007-2008 Ryan Allen, FlashDen Pty Ltd

Based on the work of Ryan Allen and Scott Barron

Licensed under MIT license, see the MIT-LICENSE file.
