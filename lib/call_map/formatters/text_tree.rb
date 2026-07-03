# frozen_string_literal: true

module CallMap
  module Formatters
    # Renders a CallNode tree as a text tree using box-drawing characters,
    # suitable for pasting into Notion or pull requests.
    #
    #   OrdersController#destroy
    #   ├─ before_action set_order
    #   │  └─ Order.find
    #   └─ OrderDeleteService.execute
    #      └─ OrderDeleteService#execute
    class TextTree
      # @param root [CallNode]
      # @return [String]
      def self.format(root)
        new.format(root)
      end

      def format(root)
        lines = [root.label]
        append_children(lines, root.children, "")
        "#{lines.join("\n")}\n"
      end

      private

      def append_children(lines, children, prefix)
        children.each_with_index do |child, index|
          last = index == children.size - 1
          connector = last ? "└─ " : "├─ "
          lines << "#{prefix}#{connector}#{child.label}"
          child_prefix = prefix + (last ? "   " : "│  ")
          append_children(lines, child.children, child_prefix)
        end
      end
    end
  end
end
