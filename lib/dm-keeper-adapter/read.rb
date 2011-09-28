#
# dm-keeper-adapter/read.rb
#
# Read/Query operations - A DataMapper adapter for FATE/features.opensuse.org
#
#--
# Copyright (c) 2011 SUSE LINUX Products GmbH
#
# Author: Klaus Kämpf <kkaempf@suse.com>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'cgi'

module DataMapper::Adapters
  class KeeperAdapter < AbstractAdapter
    require 'nokogiri'
    def read(query)
      records = records_for(query)
#      query.filter_records(records)
    end

  private
    # taken from https://github.com/whoahbot/dm-redis-adapter/
    
    ##
    # Retrieves records for a particular model.
    #
    # @param [DataMapper::Query] query
    #   The query used to locate the resources
    #
    # @return [Array]
    #   An array of hashes of all of the records for a particular model
    #
    # @api private
    def records_for(query)
#      $stderr.puts "records_for(#{query})"
#      $stderr.puts "records_for(#{query.inspect})"
      records = []
      if query.conditions.nil?
	# return all
      else
	query.conditions.operands.each do |operand|
	  if operand.is_a?(DataMapper::Query::Conditions::OrOperation)
	    operand.each do |op|
	      records = records + perform_query(query, op)
	    end
	  else
	    records = perform_query(query, operand)
	  end
	end
      end      
      records
    end #def

    ##
    # Find records that match have a matching value
    #
    # @param [DataMapper::Query] query
    #   The query used to locate the resources
    #
    # @param [DataMapper::Operation] the operation for the query
    #
    # @return [Array]
    #   An array of hashes of all of the records for a particular model
    #
    # @api private
    def perform_query(query, operand)
      records = []
#      STDERR.puts "perform_query(query#{query}, operand #{operand})"
       
      if operand.is_a? DataMapper::Query::Conditions::NotOperation
	subject = operand.first.subject
	value = operand.first.value
      elsif operand.subject.is_a? DataMapper::Associations::ManyToOne::Relationship
	subject = operand.subject.child_key.first
	value = operand.value[operand.subject.parent_key.first.name]
      else
	subject = operand.subject
	value =  operand.value
      end
      
      if subject.is_a?(DataMapper::Associations::ManyToOne::Relationship)
	subject = subject.child_key.first
      end
      
#      $stderr.puts "perform_query(\n\tsubject#{subject.inspect}\n\t#{value.inspect})"

      # typical queries
      #
      # ?query=/feature[
      #   productcontext[
      #    not (status[done or rejected or duplicate or unconfirmed])
      #  ]
      #  and
      #  actor[
      #    (person/userid='kkaempf@suse.com' or person/email='kkaempf@suse.com' or person/fullname='kkaempf@suse.com')
      #    and
      #    role='projectmanager'
      #  ]
      # ]
      #
      #  "/#{container}[actor/role='infoprovider']
      #
      # query=/feature[title='Foo%20bar%20baz']
      #
      # query=/feature[contains(title,'Foo')]
      # query=/feature[contains(title,'Foo')]/title
      # query=/feature[contains(title,'Foo')]/@k:id
      #
      
#      $stderr.puts "perform_query(subject #{subject.inspect},#{value.inspect})"
      container = query.model.to_s.downcase
      if query.model.key.include?(subject)
	# get single <feature>
	records << node_to_record(query.model, get("/#{container}/#{CGI.escape(value.to_s)}").root)
      else
	xpath = "/#{container}"
	xpathmap = query.model.xpathmap rescue { }
	name = xpathmap[subject.name] || subject.name
	# query, get <collection>[<object><feature>...]*
	xpath << "["
	case operand
	when DataMapper::Query::Conditions::EqualToComparison
	  xpath << CGI.escape("#{name} = \"#{value}\"")
	when DataMapper::Query::Conditions::LikeComparison
	  xpath << "contains(#{name},'#{CGI.escape(value)}')"
	else
	  raise "Unhandled operand #{operand.class}"
	end
	xpath << "]"
	collection = get("/#{container}?query=#{xpath}").root
	collection.xpath("//#{container}", collection.namespace).each do |node|
	  records << node_to_record(query.model, node)
	end
      end

      records
    end # def

    ##
    # Convert feature (as xml) into record (as hash of key/value pairs)
    #
    # @param [Nokogiri::XML::Node] node
    #   A node
    #
    # @return [Hash]
    #   A hash of all of the properties for a particular record
    #
    # @api private
    def node_to_record(model, node)
      record = { }
      xpathmap = model.xpathmap rescue { }
      xmlnamespaces = model.xmlnamespaces rescue nil
#      $stderr.puts "node_to_record(#{model}:#{node.class})"
      model.properties.each do |property|
	xpath = xpathmap[property.name] || property.name
	key = property.name.to_s
	if key == "raw"
	  record[key] = node.to_s
	  next
	end
	children = node.xpath("./#{xpath}", xmlnamespaces)	
#	$stderr.puts "Property found: #{property.inspect}"
	case children.size
	when 0: next
	when 1: value = children.text
	else
	  value = children.to_xml
	end
#	$stderr.puts "Key #{key}, Value #{value} <#{property.class}>"
	case property
	when DataMapper::Property::Date
	  require 'parsedate'
	  record[key] = Time.utc(ParseDate.parsedate(value))
	when DataMapper::Property::Integer
	  record[key] = value.to_s
	when DataMapper::Property::String
	  record[key] = value.to_s
	else
	  raise TypeError, "#{property} unsupported"
	end
      end
      record
    end
  end # class
end # module
