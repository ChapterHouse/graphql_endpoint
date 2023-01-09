require "graphql/client"

class QueryError < GraphQL::Client::Error

  attr_reader :query

  def initialize(query, errors)
    @query = query
    errors = errors.values if errors.is_a?(GraphQL::Client::Errors)
    errors = Array(errors).flatten.map(&:to_s).join("\n")
    super(errors)
  end

end

class GraphQL::Language::Nodes::VariableDefinition

  def convert(value, schema)
    type.respond_to?(:convert) ? type.convert(value, schema) : value
  end

  def variable_definition
    self
  end

end

class GraphQL::Language::Nodes::ListType

  def convert(value, schema)
    of_type.respond_to?(:convert) ? Array(value).map { |v| of_type.convert(v, schema) } : Array(value)
  end

  def variable_definition
    of_type.variable_definition
  end

end

class GraphQL::Language::Nodes::TypeName

  def convert(value, schema)
    type = schema.get_type(name)
    type.respond_to?(:coerce_result) ? type.coerce_result(value, GraphQL::Query::NullContext) : value
  end

  def variable_definition
    of_type.variable_definition
  end

end

class GraphQL::Language::Nodes::WrapperType

  def convert(value, schema)
    of_type.respond_to?(:convert) ? of_type.convert(value, schema) : value
  end

  def variable_definition
    of_type.variable_definition
  end

end

$depth = 0
class Hash
  # def depth
  #   arr = values
  #   d = 0
  #   loop do
  #     arr = arr.flatten.select { |e| e.is_a? Hash }
  #     break d if arr.empty?
  #     d += 1
  #     # puts d
  #     arr = arr.map(&:values)
  #     puts "d = #{d}, arr = #{arr}"
  #   end
  # end
  def depth
    $depth += 1
    puts ' ' * $depth + caller_locations.size.to_s
    sub_hashes = values.select { |x| x.is_a?(Hash) }
    sub_hashes.map(&:depth).max.to_i
  ensure
    $depth -= 1
  end

end

module GraphQL::Schema::AsQuery

  def as_query
    query_signature = 'query(' + own_arguments.map { |k, v| "$#{k}: #{v.type.to_type_signature}" }.join(', ') + ')'
    signature = "#{name}(" + own_arguments.keys.map { |k| "#{k}: $#{k}" }.join(', ') + ')'
    hash = {query_signature => {signature => query_fields(recurse: true)} }

    # File.open("tmp#{depth}.json", 'w') do |file|
    #   file.puts JSON.pretty_generate(hash)
    # end

    JSON.pretty_generate(hash).gsub(/"(.+?)":/, '\1').gsub('},', '}').gsub(/\{\s+\}/, '').gsub(/^  /, '')[1..-2]
    #.gsub(/"(.+?)":/, '\1').gsub('},', '}').gsub(/\{\s+\}/, '').gsub(/^  /, '')[1..-2]
  end

  def query_fields(recurse: false, skip: [])
    source = respond_to?(:of_type) ? of_type : type
    if source.is_a?(Class) && source < GraphQL::Schema::Object
      if skip.include?(source.graphql_name)
        source = nil
      else
        skip = skip + [source.graphql_name]
      end
    end

    if source.respond_to?(:query_fields)
      source.query_fields(recurse: recurse, skip: skip)
    elsif source.respond_to?(:own_fields)
      source.own_fields.map { |k, v| [k, recurse && v.query_fields(recurse: recurse, skip: skip) || v] }.to_h
    else
      {}
    end
  end

  def query_fields_recursive
    Hash.new do |h, k|
      if k.respond_to?(:query_fields)
        h[k] = k.query_fields
        h[k].reject! { |_, v2| h.has_key?(v2) }
        h[k].transform_values! { |x| h[x] }
        h[k]
      else
        k
      end
    end[self]
  end


end

class GraphQL::Schema::Field

  include GraphQL::Schema::AsQuery

end

class GraphQL::Schema::NonNull

  include GraphQL::Schema::AsQuery

end

class GraphQL::Schema::List

  include GraphQL::Schema::AsQuery

end


class GraphQL::Client::OperationDefinition

  def convert(variables={})
    variables = variables.with_indifferent_access
    definition_node.variables.each do |defined_variable|
      key = [defined_variable.name, defined_variable.name.underscore].find { |k| variables.has_key?(k) }
      if key
        value = variables[key]
        variables[defined_variable.name] = defined_variable.convert(value, client.schema)
      end
    end
    variables
  end

  def execute(variables={})
    client.query(self, variables: convert(variables)).tap do |result|
      raise QueryError.new(self, result.errors) unless result.errors.empty?
    end.data.to_h.values.first #  definition_node.selections.first.name
  end

end

