require 'active_support/inflector'

module Workflow
  module Draw

    # Generates a `dot` graph of the workflow.
    # Prerequisite: the `dot` binary. (Download from http://www.graphviz.org/)
    # You can use this method in your own Rakefile like this:
    #
    #     namespace :doc do
    #       desc "Generate a graph of the workflow."
    #       task :workflow
    #         Workflow::Draw::workflow_diagram(Order)
    #       end
    #     end
    #
    # You can influence the placement of nodes by specifying
    # additional meta information in your states and transition descriptions.
    # You can assign higher `doc_weight` value to the typical transitions
    # in your workflow. All other states and transitions will be arranged
    # around that main line. See also `weight` in the graphviz documentation.
    # Example:
    #
    #     state :new do
    #       event :approve, :transitions_to => :approved, :meta => {:doc_weight => 8}
    #     end
    #
    #
    # @param klass A class with the Workflow mixin, for which you wish the graphical workflow representation
    # @param [String] target_dir Directory, where to save the dot and the pdf files
    # @param [String] graph_options You can change graph orientation, size etc. See graphviz documentation
    def self.workflow_diagram(klass, target_dir='.', graph_options='rankdir="LR", size="7,11.6", ratio="fill"')
      workflow_name = "#{klass.name.tableize}_workflow".gsub('/', '_')
      fname = File.join(target_dir, "generated_#{workflow_name}")
      File.open("#{fname}.dot", 'w') do |file|
        file.puts %Q|
        digraph #{workflow_name} {
        graph [#{graph_options}];
        node [shape=box];
        edge [len=1];
        |

        klass.workflow_spec.states.each do |state_name, state|
          file.puts %Q{  #{state.name} [label="#{state.name}"];}
          state.events.each do |event_name, event|
            meta_info = event.meta
            if meta_info[:doc_weight]
              weight_prop = ", weight=#{meta_info[:doc_weight]}"
            else
              weight_prop = ''
            end
            file.puts %Q{  #{state.name} -> #{event.transitions_to} [label="#{event_name.to_s.humanize}" #{weight_prop}];}
          end
        end
        file.puts "}"
        file.puts
      end

      `dot -Tpdf -o'#{fname}.pdf' '#{fname}.dot'`

      puts "
Please run the following to open the generated file:

open '#{fname}.pdf'

"
    end
  end
end