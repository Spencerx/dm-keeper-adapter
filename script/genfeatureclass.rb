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
    #
    # generate or update the class definition for 'Feature'
    #
    def update_featureclass path
      partsrevision = 0
      xmlfieldsrevision = 0
      if File.exists? path
	require path
	partsrevision = Feature.partsrevision
	xmlfieldsrevision = Feature.xmlfieldsrevision
      end
      current_partsrevision = revision_of('list_view_parts').to_i
      current_xmlfieldsrevision = revision_of('list_xmlfields').to_i
      if partsrevision < current_partsrevision || xmlfieldsrevision < current_xmlfieldsrevision
	# class needs regeneration
	File.open path, "w+" do |f|
	  f.puts("# File generated by dm-keeper-adapter on #{Time.new.asctime}")
	  f.puts("require 'rubygems'")
	  f.puts("require 'dm-core'")
	  f.puts("class Feature")
	  f.puts("  def Feature.partsrevision")
	  f.puts("    #{current_partsrevision}")
	  f.puts("  end")
	  f.puts("  def Feature.xmlfieldsrevision")
	  f.puts("    #{current_xmlfieldsrevision}")
	  f.puts("  end")
	  f.puts("  include DataMapper::Resource\n")
	  f.puts("  property :id, Integer, :key => true")
	  properties = []
	  viewparts.each_key do |k|
	    n = k.tr(" ","_").downcase
	    properties << n
	    f.puts("  property :#{n}, String")
	  end
	  xmlfields.each_key do |k|
	    n = k.tr(" ","_").downcase
	    next if n == '.'
	    next if properties.include? n
	    f.puts("  property :#{n}, String")
	  end
	  f.puts("end")	    
	end
      else
	puts "#{path} is up to date"
      end
    end

    def revision_of id
      node = valuelist.xpath("//valuelist[@id='#{id}']").first
      node.attribute_with_ns('revision', 'http://inttools.suse.de/sxkeeper/schema/keeper').value
    end

