require 'active_support'
require 'simple-graph'

class AssociatedQueryGenerator
  class << self
    def queries_for_associated_records(starting_table_name)
      graph = SimpleGraph::Graph.new
      process_stack = [starting_table_name]

      until process_stack.empty?
        current_table_name = process_stack.pop
        foreign_key = ActiveSupport::Inflector.singularize(current_table_name) + '_id'

        tables.each do |table_name, table|
          if table.columns.any? { |col| col.name == foreign_key }
            process_stack.push(table_name)
            graph.add_vertex(current_table_name)
            graph.add_vertex(table_name)
            graph.add_edge(current_table_name, table_name)
          end
        end
      end

      find_queries(
        graph.vertices[starting_table_name], [], [starting_table_name]
      )
    end

    private

    def find_queries(vertex, visited, path, &block)
      if block_given?
        vertex.neighbors.each_pair do |_, neighbor|
          unless visited.include?(neighbor.value)
            visited << neighbor.value
            find_queries(neighbor, visited, path + [neighbor.value], &block)
          end
        end

        yield select_for(path)
      else
        to_enum(__method__, vertex, visited, path)
      end
    end

    def select_for(path)
      path = path.reverse
      query = tables[path.first]

      joins_for(path).each do |join|
        query = query.joins(join)
      end

      query
    end

    def joins_for(path)
      path.each_cons(2).map do |first_table, second_table|
        second_table_singular = ActiveSupport::Inflector.singularize(second_table)

        tables[first_table].arel_table.join(tables[second_table].arel_table).on(
          tables[second_table].arel_table[:id].eq(
            tables[first_table].arel_table["#{second_table_singular}_id"]
          )
        ).join_sources
      end
    end

    def tables
      @tables ||= ActiveRecord::Base.connection.tables.each_with_object({}) do |table_name, ret|
        ret[table_name] = Class.new(ActiveRecord::Base) do
          self.table_name = table_name
        end
      end
    end
  end
end
