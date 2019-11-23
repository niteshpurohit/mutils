# frozen_string_literal: true

# Module Mutils
module Mutils
  module Serialization
    # Module SerializationResults
    module SerializationResults

      def generate_hash
        if scope
          if scope_is_collection?
            scope.map { |inner_scope| self.class.new(inner_scope, options).generate_hash }
          else
            hashed_result
          end
        else
          {}
        end
      end

      def hashed_result
        relationships = [self.class.belongs_to_relationships, self.class.has_many_relationships]
        [fetch_attributes(self.class.attributes_to_serialize&.keys),
         call_methods(self.class.method_to_serialize&.keys),
         hash_relationships(relationships)].reduce(&:merge)
      end

      def fetch_attributes(keys)
        invoke_sends_async(keys)
      end

      def call_methods(keys)
        invoke_sends(keys, true)
      end

      def invoke_sends(keys, call_method = nil)
        hash = {}
        keys&.each do |key|
          invoke_send(hash, key, call_method)
        end
        hash
      end

      def invoke_sends_async(keys, call_method = nil)
        hash = {}
        runners = []
        keys&.each do |key|
          runners << Thread.new do
            mutex.synchronize { invoke_send(hash, key, call_method) }
          end
        end
        runners.map(&:join)
        hash
      end

      def invoke_send(hash, key, call_method = nil)
        hash[key] = send(key) if call_method
        hash[key] = scope.send(key) unless call_method
        hash
      end

      def hash_relationships(relationships_array)
        relationships = relationships_array.compact.reduce(&:merge)
        hash = {}
        relationships&.keys&.each do |key|
          if check_if_included(relationships, key)
            klass = relationships[key][:serializer]
            hash[key] = klass.new(scope.send(key)).to_h
          end
        end
        hash
      end

      def check_if_included(relationships, key)
        always_include = relationships[key][:always_include]
        always_include = always_include.nil? ? false : always_include == true
        always_include || (options[:includes]&.include?(key))
      end

      def scope_is_collection?
        scope.respond_to?(:size) && !scope.respond_to?(:each_pair)
      end
    end
  end
end