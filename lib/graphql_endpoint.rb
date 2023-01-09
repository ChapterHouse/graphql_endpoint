# frozen_string_literal: true
require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.ignore "#{__dir__}/graphql_endpoint/graphql"
loader.setup

require "graphql/client"
require "graphql/client/http"
require 'active_support/core_ext/hash'
require 'active_support/core_ext/module/attribute_accessors'

require_relative 'graphql_endpoint/graphql/tweaks'


module GraphQLEndpoint

  def self.extended(base)
    base.cattr_accessor :site
    base.cattr_accessor :path, default: 'graphql'
    base.cattr_accessor :headers, default: {}
  end

  # If not using a query_name, consider loading the schema from a file first for best performance.
  def add_query(query_string, query_name = nil)
    unless query_name
      pq = parse_query(query_string)
      query_name = pq.name.underscore
      parsed_queries[query_name] = pq
      respond_to_query(query_name)
    else
      query_name = query_name.to_s.underscore
    end
    queries[query_name] = query_string
  end

  def add_default_query(query_name, rename = nil)
    add_query(default_queries[query_name.to_s.camelize(:lower)].as_query, rename || query_name)
  end

  def add_default_queries
    default_query_names.each { |name| add_default_query(name) }
  end

  def default_queries
    schema.query.own_fields
  end

  def default_query_names
    default_queries.keys
  end

  def dump_schema(file=nil)
    file ||= schema_file
    GraphQL::Client.dump_schema(http_client, file)
  end

  def load_schema(file=nil)
    file ||= schema_file? && schema_file
    self.schema = file
  end

  def schema
    @schema || (self.schema = http_client) && @schema
  end

  def schema=(schema)
    @schema = schema ? GraphQL::Client.load_schema(schema) : nil
  end

  def schema?
    !!@schema
  end

  def schema_file
    @schema_file ||= name.gsub(/GraphQL$/, '').underscore + '_schema.json'
  end

  def schema_file=(file_name)
    @schema_file = file_name
  end

  def schema_file?
    File.exist?(schema_file)
  end

  def method_missing(symbol, *args)
    if queries.has_key?(symbol) || parsed_queries.has_key?(symbol)
      respond_to_query(symbol).call(*args)
    else
      super
    end
  end

  def queries
    @unparsed_queries ||= {}.with_indifferent_access
  end

  def respond_to_missing?(name, include_all)
    queries.has_key?(name) || super
  end

  private

  def client
    @client ||= GraphQL::Client.new(schema: schema, execute: http_client)
  end

  def http_client
    site.nil? && raise("#{name}.site not configured") || path.nil? && raise("#{name}.path not configured")
    original_headers = method(:headers)
    headers = original_headers.arity == 0 ? Proc.new { |_| original_headers[] } : original_headers
    GraphQL::Client::HTTP.new(File.join(site, path)) { define_method(:headers, &headers) }
  end

  def parse_query(key_or_query, query_name = nil)
    raw_query = queries[key_or_query]
    if raw_query
      query_name ||= key_or_query
    else
      raw_query = key_or_query
    end
    client.parse(raw_query).tap do |operation|
      query_name ||= operation.definition_node.selections.first.name
      query_name = query_name.to_s.sub(/.*\./, "").camelize # Like classify but without singularize
      operation.define_singleton_method(:name, &query_name.method(:itself))
    end
  end

  def parsed_queries
    @parsed_queries ||= HashWithIndifferentAccess.new do |hash, key|
      hash[key] = parse_query(key) if queries[key]
    end
  end

  def respond_to_query(symbol)
    define_singleton_method(symbol, &parsed_queries[symbol].method(:execute))
    method(symbol)
  end

end
