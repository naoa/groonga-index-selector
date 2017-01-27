module Groonga
  module ExpressionRewriters
    class IndexSelector < ExpressionRewriter
      register "index_selector"

      def rewrite
        optimized_lexicon_name = Config["index-selector.table"]
        return nil unless optimized_lexicon_name
        return nil if check_unsupported_code

        builder = ExpressionTreeBuilder.new(@expression)

        root_node = builder.build
        variable = @expression[0]
        table = context[variable.domain]

        @optimized_lexicon = context[optimized_lexicon_name]

        optimized_root_node = optimize_node(table, root_node)
        rewritten = Expression.create(table)
        optimized_root_node.build(rewritten)
        rewritten
      end

      private
      def check_unsupported_code
        unsupported = false
        stack = []
        codes = @expression.codes
        codes.each do |code|
          case code.op
          when Operator::PREFIX, Operator::NEAR, Operator::SIMILAR
            unsupported = true
          when Operator::PUSH
            case code.value
            when PatriciaTrie, VariableSizeColumn, FixedSizeColumn
              unsupported = true
            end
          end
        end
        unsupported
      end

      def optimize_node(table, node)
        case node
        when ExpressionTree::LogicalOperation
          optimized_sub_nodes = node.nodes.collect do |sub_node|
            optimize_node(table, sub_node)
          end
          ExpressionTree::LogicalOperation.new(node.operator,
                                               optimized_sub_nodes)
        when ExpressionTree::BinaryOperation
          if (node.left.is_a?(ExpressionTree::Variable) or
              node.left.is_a?(ExpressionTree::IndexColumn) or
              node.left.is_a?(ExpressionTree::Accessor)) and
              node.right.is_a?(ExpressionTree::Constant)
            optimized_left = node.left
            if @optimized_lexicon[node.right.value]
              if node.left.is_a?(ExpressionTree::Variable) and node.left.column.is_a?(Expression)
                match_builder = ExpressionTreeBuilder.new(node.left.column)
                match_column_node = match_builder.build
                optimized_match_column_node = optimize_match_column_node(table, match_column_node)
                rewritten = Expression.create(table)
                optimized_match_column_node.build(rewritten)
                optimized_left = ExpressionTree::Variable.new(rewritten)
              else
                optimized_left = optimize_match_column_node(table, node.left)
              end
            end

            if node.left == optimized_left
              node
            else
              ExpressionTree::BinaryOperation.new(node.operator,
                                                  optimized_left,
                                                  node.right)
            end
          else
            node
          end
        else
          node
        end
      end

      def optimize_match_column_node table, node
        case node
        when ExpressionTree::BinaryOperation
          optimized_left = optimize_match_column_node(table, node.left)
          ExpressionTree::BinaryOperation.new(node.operator,
                                              optimized_left,
                                              node.right)
        when ExpressionTree::Variable
          optimized_index = nil
          node.column.indexes.each do |info|
            next if info.index.source_ids.size != 1
            index_column_name = info.index.name.split('.').last
            optimized_index = context["#{@optimized_lexicon.name}.#{index_column_name}"]
            break if optimized_index
          end
          if optimized_index
            ExpressionTree::IndexColumn.new(optimized_index)
          else
            node
          end
        when ExpressionTree::IndexColumn
          index_column_name = node.object.name.split('.').last
          optimized_index = context["#{@optimized_lexicon.name}.#{index_column_name}"]
          if optimized_index
            ExpressionTree::IndexColumn.new(optimized_index)
          else
            node
          end
        when ExpressionTree::Accessor
          accessor = node.object
          original_source_ids = accessor.object.source_ids
          optimized_accessor = @optimized_lexicon.find_column("#{accessor.name}")
          @expression.take_object(optimized_accessor)
          new_source_ids = optimized_accessor.object.source_ids
          if original_source_ids == new_source_ids
            ExpressionTree::Accessor.new(optimized_accessor)
          else
            node
          end
        when ExpressionTree::LogicalOperation
          optimized_sub_nodes = node.nodes.collect do |sub_node|
            optimize_match_column_node(table, sub_node)
          end
          ExpressionTree::LogicalOperation.new(node.operator,
                                               optimized_sub_nodes)
        when ExpressionTree::FunctionCall
          optimized_arguments = node.arguments.map do |argument|
            optimize_match_column_node table, argument
          end
          ExpressionTree::FunctionCall.new(node.procedure, optimized_arguments)
        else
          node
        end
      end
    end
  end
end
