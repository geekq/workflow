module Workflow
  class EventCollection < Hash
    def [](name)
      super name.to_sym # Normalize to symbol
    end

    def push(name, event)
      key = name.to_sym
      self[key] ||= []
      self[key] << event
    end

    def flat
      values.flatten.uniq do |event|
        [:name, :transitions_to, :meta, :action].map { |m| event.send(m) }
      end
    end

    def include?(name_or_obj)
      case name_or_obj
      when Event
        flat.include? name_or_obj
      else
        !(self[name_or_obj].nil?)
      end
    end

    def first_applicable(name, object_context)
      (self[name] || []).find do |event|
        event.condition_applicable?(object_context) && event
      end
    end
  end
end
