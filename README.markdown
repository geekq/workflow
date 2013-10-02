[![Build Status](https://travis-ci.org/geekq/workflow.png?branch=master)](https://travis-ci.org/geekq/workflow)


What is workflow?
-----------------

Workflow is a finite-state-machine-inspired API for modeling and
interacting with what we tend to refer to as 'workflow'.

A lot of business modeling tends to involve workflow-like concepts, and
the aim of this library is to make the expression of these concepts as
clear as possible, using similar terminology as found in state machine
theory.

So, a workflow has a state. It can only be in one state at a time. When
a workflow changes state, we call that a transition. Transitions occur
on an event, so events cause transitions to occur. Additionally, when an
event fires, other arbitrary code can be executed, we call those actions.
So any given state has a bunch of events, any event in a state causes a
transition to another state and potentially causes code to be executed
(an action). We can hook into states when they are entered, and exited
from, and we can cause transitions to fail (guards), and we can hook in
to every transition that occurs ever for whatever reason we can come up
with.

Now, all that's a mouthful, but we'll demonstrate the API bit by bit
with a real-ish world example.

Let's say we're modeling article submission from journalists. An article
is written, then submitted. When it's submitted, it's awaiting review.
Someone reviews the article, and then either accepts or rejects it.
Here is the expression of this workflow using the API:

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

Nice, isn't it!

Note: the first state in the definition (`:new` in the example, but you
can name it as you wish) is used as the initial state - newly created
objects start their life cycle in that state.

Let's create an article instance and check in which state it is:

    article = Article.new
    article.accepted? # => false
    article.new? # => true

You can also access the whole `current_state` object including the list
of possible events and other meta information:

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
    article.between? :awaiting_review, :rejected
    => true

Now we can call the submit event, which transitions to the
<tt>:awaiting_review</tt> state:

    article.submit!
    article.awaiting_review? # => true

Events are actually instance methods on a workflow, and depending on the
state you're in, you'll have a different set of events used to
transition to other states.

It is also easy to check, if a certain transition is possible from the
current state . `article.can_submit?` checks if there is a `:submit`
event (transition) defined for the current state.


Installation
------------

    gem install workflow

**Important**: If you're interested in graphing your workflow state machine, you will also need to
install the `active_support` and `ruby-graphviz` gems.

Versions up to and including 1.0.0 are also available as a single file download -
[lib/workflow.rb file](https://github.com/geekq/workflow/blob/v1.0.0/lib/workflow.rb).

Ruby 1.9
--------

Workflow gem does not work with some Ruby 1.9
builds due to a known bug in Ruby 1.9. Either

* use newer ruby build, 1.9.2-p136 and -p180 tested to work
* or compile your Ruby 1.9 from source
* or [comment out some lines in workflow](http://github.com/geekq/workflow/issues#issue/6)
(reduces functionality).

Examples
--------

After installation or downloading of the library you can easily try out
all the example code from this README in irb.

    $ irb
    require 'rubygems'
    require 'workflow'

Now just copy and paste the source code from the beginning of this README
file snippet by snippet and observe the output.


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

`article.review!; article.reject!` will cause a state transition, persist the new state
(if integrated with ActiveRecord) and invoke this user defined reject
method.

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


### The old, deprecated way

The old way, using a block is still supported but deprecated:

    event :review, :transitions_to => :being_reviewed do |reviewer|
      # store the reviewer
    end

We've noticed, that mixing the list of events and states with the blocks
invoked for particular transitions leads to a bumpy and poorly readable code
due to a deep nesting. We tried (and dismissed) lambdas for this. Eventually
we decided to invoke an optional user defined callback method with the same
name as the event (convention over configuration) as explained before.


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


### Custom workflow database column

[meuble](http://imeuble.info/) contributed a solution for using
custom persistence column easily, e.g. for a legacy database schema:

    class LegacyOrder < ActiveRecord::Base
      include Workflow

      workflow_column :foo_bar # use this legacy database column for
                               # persistence
    end



### Single table inheritance

Single table inheritance is also supported. Descendant classes can either
inherit the workflow definition from the parent or override with its own
definition.

Custom workflow state persistence
---------------------------------

If you do not use a relational database and ActiveRecord, you can still
integrate the workflow very easily. To implement persistence you just
need to override `load_workflow_state` and
`persist_workflow_state(new_value)` methods. Next section contains an example for
using CouchDB, a document oriented database.

[Tim Lossen](http://tim.lossen.de/) implemented support
for [remodel](http://github.com/tlossen/remodel) / [redis](http://github.com/antirez/redis)
key-value store.

Integration with CouchDB
------------------------

We are using the compact [couchtiny library](http://github.com/geekq/couchtiny)
here. But the implementation would look similar for the popular
couchrest library.

    require 'couchtiny'
    require 'couchtiny/document'
    require 'workflow'

    class User < CouchTiny::Document
      include Workflow
      workflow do
        state :submitted do
          event :activate_via_link, :transitions_to => :proved_email
        end
        state :proved_email
      end

      def load_workflow_state
        self[:workflow_state]
      end

      def persist_workflow_state(new_value)
        self[:workflow_state] = new_value
        save!
      end
    end

Please also have a look at
[the full source code](http://github.com/geekq/workflow/blob/master/test/couchtiny_example.rb).

Integration with Mongoid
------------------------

You can integrate with Mongoid following the example above for CouchDB, but there is a gem that does that for you (and includes extensive tests):
[workflow_on_mongoid](http://github.com/bowsersenior/workflow_on_mongoid)

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


Advanced transition hooks
-------------------------

### on_entry/on_exit

We already had a look at the declaring callbacks for particular workflow
events. If you would like to react to all transitions to/from the same state
in the same way you can use the on_entry/on_exit hooks. You can either define it
with a block inside the workflow definition or through naming
convention, e.g. for the state :pending just define the method
`on_pending_exit(new_state, event, *args)` somewhere in your class.

### on_transition

If you want to be informed about everything happening everywhere, e.g. for
logging then you can use the universal `on_transition` hook:

    workflow do
      state :one do
        event :increment, :transitions_to => :two
      end
      state :two
      on_transition do |from, to, triggering_event, *event_args|
        Log.info "#{from} -> #{to}"
      end
    end

Please also have a look at the [advanced end to end
example][advanced_hooks_and_validation_test].

[advanced_hooks_and_validation_test]: http://github.com/geekq/workflow/blob/master/test/advanced_hooks_and_validation_test.rb

### on_error

If you want to do custom exception handling internal to workflow, you can define an `on_error` hook in your workflow.
For example:

    workflow do
      state :first do
        event :forward, :transitions_to => :second
      end
      state :second

      on_error do |error, from, to, event, *args|
        Log.info "Exception(#error.class) on #{from} -> #{to}"
      end
    end

If forward! results in an exception, `on_error` is invoked and the workflow stays in a 'first' state.  This capability
is particularly useful if your errors are transient and you want to queue up a job to retry in the future without
affecting the existing workflow state.

### Guards

If you want to halt the transition conditionally, you can just raise an
exception in your [transition event handler](#transition_event_handler).
There is a helper called `halt!`, which raises the
Workflow::TransitionHalted exception. You can provide an additional
`halted_because` parameter.

    def reject(reason)
      halt! 'We do not reject articles unless the reason is important' \
        unless reason =~ /important/i
    end

The traditional `halt` (without the exclamation mark) is still supported
too. This just prevents the state change without raising an
exception.

You can check `halted?` and `halted_because` values later.

### Hook order

The whole event sequence is as follows:

    * before_transition
    * event specific action
    * on_transition (if action did not halt)
    * on_exit
    * PERSIST WORKFLOW STATE, i.e. transition
    * on_entry
    * after_transition


Multiple Workflows
------------------

I am frequently asked if it's possible to represent multiple "workflows"
in an ActiveRecord class.

The solution depends on your business logic and how you want to
structure your implementation.

### Use Single Table Inheritance

One solution can be to do it on the class level and use a class
hierarchy. You can use [single table inheritance][STI] so there is only
single `orders` table in the database. Read more in the chapter "Single
Table Inheritance" of the [ActiveRecord documentation][ActiveRecord].
Then you define your different classes:

    class Order < ActiveRecord::Base
      include Workflow
    end

    class SmallOrder < Order
      workflow do
        # workflow definition for small orders goes here
      end
    end

    class BigOrder < Order
      workflow do
        # workflow for big orders, probably with a longer approval chain
      end
    end


### Individual workflows for objects

Another solution would be to connect different workflows to object
instances via metaclass, e.g.

    # Load an object from the database
    booking = Booking.find(1234)

    # Now define a workflow - exclusively for this object,
    # probably depending on some condition or database field
    if # some condition
      class << booking
        include Workflow
        workflow do
          state :state1
          state :state2
        end
      end
    # if some other condition, use a different workflow

You can also encapsulate this in a class method or even put in some
ActiveRecord callback. Please also have a look at [the full working
example][multiple_workflow_test]!

[STI]: http://www.martinfowler.com/eaaCatalog/singleTableInheritance.html
[ActiveRecord]: http://api.rubyonrails.org/classes/ActiveRecord/Base.html
[multiple_workflow_test]: http://github.com/geekq/workflow/blob/master/test/multiple_workflows_test.rb


Documenting with diagrams
-------------------------

You can generate a graphical representation of the workflow for
a particular class for documentation purposes.
Use `Workflow::create_workflow_diagram(class)` in your rake task like:

    namespace :doc do
      desc "Generate a workflow graph for a model passed e.g. as 'MODEL=Order'."
      task :workflow => :environment do
        require 'workflow/draw'
        Workflow::Draw::workflow_diagram(ENV['MODEL'].constantize)
      end
    end


Earlier versions
----------------

The `workflow` library was originally written by Ryan Allen.

The version 0.3 was almost completely (including ActiveRecord
integration, API for accessing workflow specification,
method_missing free implementation) rewritten by Vladimir Dobriakov
keeping the original workflow DSL spirit.


Migration from the original Ryan's library
------------------------------------------

Credit: Michael (rockrep)

Accessing workflow specification

    my_instance.workflow # old
    MyClass.workflow_spec # new

Accessing states, events, meta, e.g.

    my_instance.workflow.states(:some_state).events(:some_event).meta[:some_meta_tag] # old
    MyClass.workflow_spec.states[:some_state].events[:some_event].meta[:some_meta_tag] # new

Causing state transitions

    my_instance.workflow.my_event # old
    my_instance.my_event! # new

when using both a block and a callback method for an event, the block executes prior to the callback


Changelog
---------

### New in the version 1.1.0

* Tested with ActiveRecord 4.0 (Rails 4.0)
* Tested with Ruby 2.0
* automatically generated scopes with names based on state names
* clean workflow definition override for class inheritance - undefining
  the old convinience methods, s. <http://git.io/FZO02A>

### New in the version 1.0.0

* **Support to private/protected callback methods.**
  See also issues [#53](https://github.com/geekq/workflow/pull/53)
  and [#58](https://github.com/geekq/workflow/pull/58). With the new
  implementation:

  * callback methods can be hidden (non public): both private methods
    in the immediate class and protected methods somewhere in the class
    hierarchy are supported
  * no unintentional calls on `fail!` and other Kernel methods
  * inheritance hierarchy with workflow is supported

* using Rails' 3.1 `update_column` whenever available so only the
  workflow state column and not other pending attribute changes are
  saved on state transition. Fallback to `update_attribute` for older
  Rails and other ORMs. [commit](https://github.com/geekq/workflow/commit/7e091d8ded1aeeb0a86647bbf7d78ab3c9d0c458)

### New in the version 0.8.7

* switch from [jeweler][] to pure bundler for building gems

### New in the version 0.8.0

* check if a certain transition possible from the current state with
  `can_....?`
* fix workflow_state persistence for multiple_workflows example
* add before_transition and after_transition hooks as suggested by
  [kasperbn](https://github.com/kasperbn)

### New in the version 0.7.0

* fix issue#10 Workflow::create_workflow_diagram documentation and path
  escaping
* fix issue#7 workflow_column does not work STI (single table
  inheritance) ActiveRecord models
* fix issue#5 Diagram generation fails for models in modules

### New in the version 0.6.0

* enable multiple workflows by connecting workflow to object instances
  (using metaclass) instead of connecting to a class, s. "Multiple
  Workflows" section

### New in the version 0.5.0

* fix issue#3 change the behaviour of halt! to immediately raise an
  exception. See also http://github.com/geekq/workflow/issues/#issue/3

### New in the version 0.4.0

* completely rewritten the documentation to match my branch
* switch to [jeweler][] for building gems
* use [gemcutter][] for gem distribution
* every described feature is backed up by an automated test

[jeweler]: http://github.com/technicalpickles/jeweler
[gemcutter]: http://gemcutter.org/gems/workflow

### New in the version 0.3.0

Intermixing of transition graph definition (states, transitions)
on the one side and implementation of the actions on the other side
for a bigger state machine can introduce clutter.

To reduce this clutter it is now possible to use state entry- and
exit- hooks defined through a naming convention. For example, if there
is a state :pending, then instead of using a
block:

    state :pending do
      on_entry do
        # your implementation here
      end
    end

you can hook in by defining method

    def on_pending_exit(new_state, event, *args)
      # your implementation here
    end

anywhere in your class. You can also use a simpler function signature
like `def on_pending_exit(*args)` if your are not interested in
arguments.  Please note: `def on_pending_exit()` with an empty list
would not work.

If both a function with a name according to naming convention and the
on_entry/on_exit block are given, then only on_entry/on_exit block is used.


Support
-------

### Reporting bugs

<http://github.com/geekq/workflow/issues>


About
-----

Author: Vladimir Dobriakov, <http://www.innoq.com/blog/vd>, <http://blog.geekq.net/>

Copyright (c) 2008-2009 Vodafone

Copyright (c) 2007-2008 Ryan Allen, FlashDen Pty Ltd

Based on the work of Ryan Allen and Scott Barron

Licensed under MIT license, see the MIT-LICENSE file.

