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
    #
    # With include_comments: true, a resolved node's leading comment is
    # appended as an inline annotation (opt-in — comments are reading aid,
    # not call-graph structure):
    #
    #   └─ OrderDeleteService#execute  # Destroys the order.
    class TextTree
      # Only the first comment line is shown, truncated to keep the tree scannable.
      MAX_COMMENT_LENGTH = 60

      # @param root [CallNode]
      # @param include_comments [Boolean] append leading comments to resolved nodes
      # @return [String]
      def self.format(root, include_comments: false)
        new(include_comments: include_comments).format(root)
      end

      def initialize(include_comments: false)
        @include_comments = include_comments
      end

      def format(root)
        lines = [node_label(root)]
        append_children(lines, root.children, "")
        "#{lines.join("\n")}\n"
      end

      private

      def append_children(lines, children, prefix)
        children.each_with_index do |child, index|
          last = index == children.size - 1
          connector = last ? "└─ " : "├─ "
          lines << "#{prefix}#{connector}#{node_label(child)}"
          child_prefix = prefix + (last ? "   " : "│  ")
          append_children(lines, child.children, child_prefix)
        end
      end

      def node_label(node)
        label = node.label
        return label unless @include_comments

        comment = node.definition&.comments&.first
        return label unless comment

        "#{label}  # #{truncate(comment)}"
      end

      def truncate(text)
        return text if text.length <= MAX_COMMENT_LENGTH

        "#{text[0, MAX_COMMENT_LENGTH]}…"
      end
    end
  end
end
