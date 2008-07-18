---------------------------------------------------------------------
-- Represents an RDF resource. Manages manipulations of that resource,
-- including data lookup (e.g. eyal.age), data updates (e.g. eyal.age=20),
-- class-level lookup (Person:find_by_name 'eyal'), and class-membership
-- (eyal.class ...Person).
-- @release $Id$
-- LUADOC COMMENTS ARE AT END OF THIS FILE
---------------------------------------------------------------------
require 'activerdf.objectmanager.namespace'
require 'activerdf.queryengine.query'

local string = activerdf.string
local error = error
local type = type
local unpack = unpack
local tostring = tostring
local getmetatable = getmetatable
local setmetatable = setmetatable
local rawequal = rawequal
local module = module

module "activerdf"

-- TODO: finish removal of ObjectManager.construct_classes: make dynamic finders 
-- accessible on instance level, and probably more stuff.

RDFS = RDFS or {}

local Resource = oo.class{
	-- uri of the resource (for instances of this class: rdf resources)
    uri = ''
}

RDFS.Resource = Resource

--- creates new resource representing an RDF resource.
-- @name new
-- @param uri an uri string or a resource
-- @usage <code>Resource.new('http://www.example.org/resource')</code>
function Resource.new(uri)
	return Resource(uri)
end

function Resource:__init(uri)
  local _uri  
  -- allow Resource.new(other_resource)
   if oo.instanceof(uri, RDFS.Resource) then	
		_uri = uri.uri
   -- allow Resource.new('<uri>') by stripping out <>
   elseif uri:match('^<([^>]*)>$') then
      _uri = uri:match('^<([^>]*)>$')
   -- allow Resource.new('uri')
   elseif type(uri) == 'string' then
		_uri = uri
   else 		
		error("cannot create resource <"..tostring(uri)..">")
   end
  return oo.rawnew(self, {
		uri = _uri,
		predicates = {}
  })
end
	
-- setting our own class uri to rdfs:resource
-- (has to be done after defining our RDFS::Resource.new
-- because it cannot be found in Namespace.lookup otherwise)
Resource.class_uri = Namespace.lookup('rdfs', 'Resource')

function Resource.uri(self)
	return self.class_uri.uri
end

--local mt = getmetatable(oo.getclass(RDFS.Resource))
--mt.__eq = function(self, other)
--	return other:uri() and other:uri() == self:uri() or false
--end

--#####                        ######
--##### start of instance-level code
--#####                        ######
 
function Resource:abbreviation()
	local uri
	uri = type(self.uri) == 'function' and self:uri() or self.uri
	return {tostring(Namespace.prefix(uri)), self:localname()};
end

-- a resource is same as another if they both represent the same uri
function Resource:__eq(other)
	local self_uri
	local other_uri
	if oo.instanceof(self, RDFS.Resource) then
		self_uri = self.uri
	elseif rawequal(self,RDFS.Resource) or oo.subclassof(self, RDFS.Resource) then
		self_uri = self:uri()
	end
	if oo.instanceof(other, RDFS.Resource) then
		other_uri = other.uri
	elseif rawequal(other,RDFS.Resource) or oo.subclassof(other, RDFS.Resource) then
		other_uri = other:uri()
	end	
	return other_uri and (other_uri == self_uri) or false			
end

--getmetatable(Resource).__eq = Resource.__eq
--alias_method 'eql?','=='

function Resource:to_ntriple() 
	local uri
	if oo.instanceof(self, RDFS.Resource) then
		uri = self.uri
	elseif oo.subclassof(self, RDFS.Resource) or self == RDFS.Resource then
		uri = self:uri()
	end
	return "<"..uri..">" 
end

function Resource:to_xml()
	local base = string.chop(Namespace.expand(Namespace.prefix(self),''))	
	local xml = '<?xml version="1.0"?>\n'
	xml = xml .. '<rdf:RDF xmlns="' .. base .. '#"\n'
	table.foreach(Namespace.abbreviations(), function(i, p) 
															uri = Namespace.expand(p,'')
															if uri ~= base .. '#' then
																xml = xml .. '  xmlns:' .. tostring(p)..'="'..uri..'"\n'
															end															
														end)	
	xml = xml .. '  xml:base="'..base..'">\n'
	xml = xml .. '<rdf:Description rdf:about="#'..self:localname()..'">\n'	
	table.foreach(self:direct_predicates(), function(i, p)		
		objects = Query():distinct('?o'):where(self, p, '?o'):execute()		
		table.foreach(objects, function(i, obj)
			prefix, localname = Namespace.prefix(p), Namespace.localname(p)			
			if prefix then
				pred_xml = string.format('%s:%s', prefix, localname)
			else
				pred_xml = p.uri
			end
			if oo.instanceof(obj, RDFS.Resource) then
            xml = xml .. '  <'..pred_xml..' rdf:resource="'..obj.uri..'"/>\n'
         elseif oo.instanceof(obj, LocalizedString) then
            xml = xml .. '  <'..pred_xml..' xml:lang="'..obj.lang..'">'..obj..'</'..pred_xml..'>\n'
         else
            xml = xml .. '  <'..pred_xml..' rdf:datatype="'..obj:xsd_type().uri..'">'..obj..'</'..pred_xml..'>\n'
         end
		end)
	end)	      
   	xml = xml .. '</rdf:Description>\n'
   	xml = xml .. '</rdf:RDF>'
	return xml
end

-- overriding sort based on uri
--def <=>(other)
--      uri <=> other.uri
--end
function Resource:__lt(other)		
	return other.uri and (self.uri < other.uri) or false	
end

--#####                   	#####
--##### class level methods	#####
--#####                    	#####

--- returns the predicates that have this resource as their domain. 
-- (applicable predicates for this resource).
-- @name predicates
function Resource.predicates()
	local domain = Namespace.lookup('rdfs', 'domain')	
	return Query():distinct('?p'):where('?p', domain, Resource.class_uri):execute() or {}
end

--- returns a table of all instances of this class.
-- (always returns collection)
-- @name find_all
-- @usage <code>Person:find_all()</code>
function Resource.find_all(self, ...)
	return self:find('?all', ...)
end

function Resource.send(self, method)		
	if type(method) == 'string' then	
		--if Resource[method] then					
--			return Resource[method]
	--	end
		if oo.isclass(self) and oo.subclassof(self, Resource) then
			-- manages invocations such as Person.find_by_name, 
			-- Person.find_by_foaf::name, Person.find_by_foaf::name_and_foaf::knows, etc.
			local capture = string.match(method, '^find_by_(.+)')			
			if capture then				
				--$activerdflog.debug "constructing dynamic finder for #{method}"
				-- construct proxy to handle delayed lookups 
				-- (find_by_foaf::name_and_foaf::age)				
				return function(self, ...)							
					local proxy = DynamicFinderProxy(capture, nil, ...)
					-- if proxy already found a value (find_by_name) we will not get a more 
					-- complex query, so return the value. Otherwise, return the proxy so that 
					-- subsequent lookups are handled					
					return proxy.value or proxy
				end
			end	
		end		
	end
	
end

getmetatable(Resource).__index = Resource.send

--#####                         #####
--##### instance level methods	#####
--#####                         #####
--- returns a table of all instances of this class respecting the filters params ...
-- @name find
-- @param ... table with filter fields where, order, reverse_order, context, limit and offset
-- @usage <code>Person:find{ where = { name = "eyal" } }</code>
function Resource:find(...)		
	if oo.isclass(self) and oo.subclassof(self, Resource) then		
		return self.class_uri:find(...)
	end
	
	local sort_predicate
 	-- extract sort options from args
 	local args = {...}	
	local options = (type(args[#args]) == 'table') and table.remove(args,#args) or {}
 
	local query = Query():distinct('?s')	
	query:where('?s', Namespace.lookup('rdf','type'), self)

	if options['order'] then
		sort_predicate = options['order']
		query:sort('?sort_value')
		query:where('?s', sort_predicate, '?sort_value')
	end

	if options['reverse_order'] then
		sort_predicate = options['reverse_order']
		query:reverse_sort('?sort_value')
		query:where('s?', sort_predicate, '?sort_value')
	end

	if options['where'] then 				
		if type(options['where']) ~= 'table' then
			error("where clause should be lua table of predicate = object" )
		end
		table.foreach(options['where'], function(p,o)
			if options['context'] then
				query:where('?s', p, o, options['context'])
			else
				query:where('?s', p, o)
			end
		end)
	else
		if options['context'] then
			query:where('?s', '?p', '?o', options['context'])
		end
	end

	if options['limit'] then query:limit(options['limit']) end
	if options['offset'] then query:offset(options['offset']) end

	--if block_given?
	--  query.execute do |resource|
	--    yield resource
	--  end
	--else	
	return query:execute{flatten = false}
	--end
end

function Resource:localname()
	return Namespace.localname(self)
end

-- manages invocations such as eyal.age
function Resource:__index(method, ...)				
	if type(method) == 'string' then		
		if Resource[method] then						
			return Resource[method]
		end		

		if oo.instanceof(self, Resource) then			
			-- possibilities:
			-- 1. eyal.age is a property of eyal (triple exists <eyal> <age> "30")
			-- evidence: eyal age ?a, ?a is not nil (only if value exists)
			-- action: return ?a
			--
			-- 2. eyal's class is in domain of age, but does not have value for eyal
			-- explain: eyal is a person and some other person (not eyal) has an age
			-- evidence: eyal type ?c, age domain ?c
			-- action: return nil
			--
			-- 3. eyal.age = 30 (setting a value for a property)
			-- explain: eyal has (or could have) a value for age, and we update that value
			-- complication: we need to find the full URI for age (by looking at
			-- possible predicates to use
			-- evidence: eyal age ?o  (eyal has a value for age now, we're updating it)
			-- evidence: eyal type ?c, age domain ?c (eyal could have a value for age, we're setting it)
			-- action: add triple (eyal, age, 30), return 30
			--
			-- 4. eyal.age is a custom-written method in class Person
			-- evidence: eyal type ?c, ?c.methods includes age
			-- action: inject age into eyal and invoke
			--
			-- 5. eyal.age is registered abbreviation 
			-- evidence: age in @predicates
			-- action: return object from triple (eyal, @predicates[age], ?o)
			--
			-- 6. eyal.foaf::name, where foaf is a registered abbreviation
			-- evidence: foaf in Namespace.
			-- action: return namespace proxy that handles 'name' invocation, by 
			-- rewriting into predicate lookup (similar to case (5)

			-- $activerdflog.debug "method_missing: #{method}"

			-- are we doing an update or not? 
			-- checking if method ends with '='
				
			local args = {...}
			local update = string.find(method, '^set')
			-- methodname = if update 
			-- method.to_s[0..-2]
			-- else
			-- method.to_s
			-- end
			local methodname = method

			-- extract single values from array unless user asked for eyal.all_age
			local flatten = true
			if string.sub(method,1,4) == 'all_' then
				flatten = false
				methodname = string.sub(methodname, 5,-1)
			end
			
			-- check possibility (5)			 
			if self.predicates[methodname] then
				if update then
					return self:set_predicate(self.predicates[methodname], args)
				else					
					return self:get_predicate(self.predicates[methodname])
				end
			end
			
			-- check possibility (6)
			if table.include(Namespace.abbreviations(), methodname) then
				local namespace = {}
				Resource.uri = methodname
				Resource.subject = self
				Resource.flatten = flatten

				-- catch the reading invocation on the namespace
				local __index = function(self, localname, ...)
					local values = {...}
					local predicate				
					predicate = Namespace.lookup(Resource.uri, localname)
					return Resource.subject:get_predicate(predicate, Resource.flatten)										
				end
				
				-- catch the updating invocation on the namespace				
				local __newindex = function(self, localname, ...)
					local values = {...}
					local predicate		
					predicate = Namespace.lookup(Resource.uri, localname)
					return Resource.subject:set_predicate(predicate, values)									
				end
				
				setmetatable(namespace, { __index = __index, __newindex = __newindex })
				--private(:type)
				--end
				return namespace
			end
			
			local candidates
			if update then				
				candidates = table.uniq(table.add(self:class_level_predicates(), self:direct_predicates()))
			else
				candidates = self:direct_predicates()			
			end
			
			-- checking possibility (1) and (3)
			local result = table.foreach(candidates, function(index, pred)				
				if Namespace.localname(pred) == methodname then										
					if update then
						return self:set_predicate(pred, args)
					else				
						return self:get_predicate(pred, flatten)
					end
				end
			end)
				
			if result then return result end
			
			if update then
				--raise ActiveRdfError, "could not set #{methodname} to #{args}: no suitable 
				--predicate found. Maybe you are missing some schema information?" if update
				error("could not set "..methodname.." to "..args..": no suitable predicate found. Maybe you are missing some schema information?")
			end			
			-- get/set attribute value did not succeed, so checking option (2) and (4)
			
			-- checking possibility (2), it is not handled correctly above since we use
			-- direct_predicates instead of class_level_predicates. If we didn't find
			-- anything with direct_predicates, we need to try the
			-- class_level_predicates. Only if we don't find either, we
			-- throw "method_missing"			
			candidates = self:class_level_predicates()
						
			-- if any of the class_level candidates fits the sought method, then we
			-- found situation (2), so we return nil or [] depending on the {:array =>
			-- true} value			
			if table.any(candidates, function(i,c) if Namespace.localname(c) == methodname then return true end end) then
				if type(args[1]) == 'table' then
					local return_ary = args[1]['array'] 
				end
				if return_ary then
					return {}
				else
					return nil
				end
			end
			-- checking possibility (4)
			-- TODO: implement search strategy to select in which class to invoke
			-- e.g. if to_s defined in Resource and in Person we should use Person
			--$activerdflog.debug "RDFS::Resource: method_missing option 4: custom class method"
			result = table.foreach(self:type(), function(index, klass)				
				if type(klass[method]) == 'function' then					
					local _dup = klass(uri)
					return _dup[method](self, unpack(args))
				end				
			end)				
			return result						
		end	
		-- if none of the three possibilities work out, we don't know this method
		-- invocation, but we don't want to throw NoMethodError, instead we return
		-- nil, so that eyal.age does not raise error, but returns nil. (in RDFS,
		-- we are never sure that eyal cannot have an age, we just dont know the
		-- age right now)			
		return nil
	end			
	return nil
end

-- manages invocations such as eyal.age
function Resource:__newindex(method, ...)				
	if type(method) == 'string' then		
		if Resource[method] then						
			return Resource[method]
		end

		if oo.instanceof(self, Resource) then			
			-- possibilities:
			-- 1. eyal.age is a property of eyal (triple exists <eyal> <age> "30")
			-- evidence: eyal age ?a, ?a is not nil (only if value exists)
			-- action: return ?a
			--
			-- 2. eyal's class is in domain of age, but does not have value for eyal
			-- explain: eyal is a person and some other person (not eyal) has an age
			-- evidence: eyal type ?c, age domain ?c
			-- action: return nil
			--
			-- 3. eyal.age = 30 (setting a value for a property)
			-- explain: eyal has (or could have) a value for age, and we update that value
			-- complication: we need to find the full URI for age (by looking at
			-- possible predicates to use
			-- evidence: eyal age ?o  (eyal has a value for age now, we're updating it)
			-- evidence: eyal type ?c, age domain ?c (eyal could have a value for age, we're setting it)
			-- action: add triple (eyal, age, 30), return 30
			--
			-- 4. eyal.age is a custom-written method in class Person
			-- evidence: eyal type ?c, ?c.methods includes age
			-- action: inject age into eyal and invoke
			--
			-- 5. eyal.age is registered abbreviation 
			-- evidence: age in @predicates
			-- action: return object from triple (eyal, @predicates[age], ?o)
			--
			-- 6. eyal.foaf::name, where foaf is a registered abbreviation
			-- evidence: foaf in Namespace.
			-- action: return namespace proxy that handles 'name' invocation, by 
			-- rewriting into predicate lookup (similar to case (5)

			-- $activerdflog.debug "method_missing: #{method}"

			-- are we doing an update or not? 
			-- checking if method ends with '='
				
			local args = {...}
			local update = true
			-- methodname = if update 
			-- method.to_s[0..-2]
			-- else
			-- method.to_s
			-- end
			local methodname = method

			-- extract single values from array unless user asked for eyal.all_age
			local flatten = true
			if string.sub(method,1,4) == 'all_' then
				flatten = false
				methodname = string.sub(methodname, 5,-1)
			end
			
			-- check possibility (5)			 
			if self.predicates[methodname] then
				if update then
					return self:set_predicate(self.predicates[methodname], args)
				else					
					return self:get_predicate(self.predicates[methodname])
				end
			end
			
			-- check possibility (6)
			if table.include(Namespace.abbreviations(), methodname) then				
				local namespace = {}
				Resource.uri = methodname
				Resource.subject = self
				Resource.flatten = flatten

				local __index = function(self, localname, ...)
					local values = {...}
					local predicate				
					predicate = Namespace.lookup(Resource.uri, localname)
					return Resource.subject:get_predicate(predicate, Resource.flatten)										
				end
				
				-- catch the updating invocation on the namespace				
				local __newindex = function(self, localname, ...)
					local values = {...}
					local predicate		
					predicate = Namespace.lookup(Resource.uri, localname)
					return Resource.subject:set_predicate(predicate, values)									
				end
				
				setmetatable(namespace, { __index = method_missing, __newindex = __newindex })
				--private(:type)
				--end
				return namespace
			end
			
			local candidates
			if update then
				candidates = table.uniq(table.add(self:class_level_predicates(), self:direct_predicates()))
			else
				candidates = self:direct_predicates()			
			end
			
			-- checking possibility (1) and (3)
			local result = table.foreach(candidates, function(index, pred)				
				if Namespace.localname(pred) == methodname then										
					if update then
						return self:set_predicate(pred, args)
					else				
						return self:get_predicate(pred, flatten)
					end
				end
			end)
				
			if result then return result end
			
			--raise ActiveRdfError, "could not set #{methodname} to #{args}: no suitable 
			--predicate found. Maybe you are missing some schema information?" if update
			error("could not set"..methodname.." to "..tostring(args)..": no suitable predicate found. Maybe you are missing some schema information?")
						
			-- get/set attribute value did not succeed, so checking option (2) and (4)
			
			-- checking possibility (2), it is not handled correctly above since we use
			-- direct_predicates instead of class_level_predicates. If we didn't find
			-- anything with direct_predicates, we need to try the
			-- class_level_predicates. Only if we don't find either, we
			-- throw "method_missing"			
			candidates = self:class_level_predicates()
						
			-- if any of the class_level candidates fits the sought method, then we
			-- found situation (2), so we return nil or [] depending on the {:array =>
			-- true} value			
			if table.any(candidates, function(i,c) if Namespace.localname(c) == methodname then return true end end) then
				if type(args[1]) == 'table' then
					local return_ary = args[1]['array'] 
				end
				if return_ary then
					return {}
				else
					return nil
				end
			end
			-- checking possibility (4)
			-- TODO: implement search strategy to select in which class to invoke
			-- e.g. if to_s defined in Resource and in Person we should use Person
			--$activerdflog.debug "RDFS::Resource: method_missing option 4: custom class method"
			result = table.foreach(self:type(), function(index, klass)				
				if type(klass[method]) == 'function' then					
					local _dup = klass(uri)
					return _dup[method](self, unpack(args))
				end				
			end)				
			return result						
		end	
		-- if none of the three possibilities work out, we don't know this method
		-- invocation, but we don't want to throw NoMethodError, instead we return
		-- nil, so that eyal.age does not raise error, but returns nil. (in RDFS,
		-- we are never sure that eyal cannot have an age, we just dont know the
		-- age right now)			
		return nil
	end			
	return nil
end


--- saves instance into datastore.
-- @name save
-- @usage <code>resource = Resource.new('http://www.example.com/resource') <br>resource:save()</code> 
function Resource:save()
	local db = ConnectionPool.write_adapter
	local rdftype = Namespace.lookup('rdf', 'type')
	table.foreach(self:types(), function(i,t)
		db.add(self, rdftype, t)
	end)
	
	Query():distinct('?p','?o'):where(self, '?p', '?o'):execute(function(p, o)
		db:add(self, p, o)
	end)
end

--- returns all rdf:type of this instance.
--
-- Note: this method performs a database lookup for { self rdf:type ?o }. For 
-- simple type-checking (to know if you are handling an ActiveRDF object, use 
-- oo.classof(self), which does not do a database query, but simply returns 
-- RDFS::Resource.
-- @name type
-- @return e.g. { RDFS.Resource, FOAF.Person }
-- @usage <code>resource:type()</code>
function Resource:type()	
	return table.map(self:types(), function(index, _type)
		return ObjectManager.construct_class(_type)
	end)
end
	
--- defines a localname for a predicate URI.
-- localname should be a string, fulluri a Resource or string. 
-- @name add_predicate
-- @usage <code>resource:add_predicate('name', FOAF.lastName)</code>
function Resource:add_predicate(localname, fulluri)
	local localname = tostring(localname)
	if type(fulluri) == 'string' then
		local fulluri = RDFS.Resource(fulluri) 
	end

	-- predicates is a hash from abbreviation string to full uri resource
	self.predicates[localname] = fulluri
	return self.predicates[localname]
end

--- overrides built-in instance_of to use rdf:type definitions.
-- @name instanceof
-- @param klass a LOOP class
-- @usage <code>resource:instanceof(klass)</code>
function Resource:instanceof(klass)
	return table.include(self:type(), klass)
end

--- returns all predicates that fall into the domain of the rdf:type of this resource.
-- @name class_level_predicates
-- @usage <code>resource:class_level_predicates()</code>
function Resource:class_level_predicates()	
	local type = Namespace.lookup('rdf', 'type')
	local domain = Namespace.lookup('rdfs', 'domain')		
	return Query():distinct('?p'):where(self,type,'?t'):where('?p', domain, '?t'):execute() or {}
end

--- returns all predicates that are directly defined for this resource.
-- @name direct_predicates
-- @param distinct true or false
-- @usage <code>resource:direct_predicates(true)</code>
function Resource:direct_predicates(distinct)	
	local distinct = distinct == nil and true or distinct	
	if distinct then
		return Query():distinct('?p'):where(self, '?p', '?o'):execute()
	else		
		return Query():select('?p'):where(self, '?p', '?o'):execute()
	end
end

function Resource:property_accessors()
	return table.map(self:direct_predicates(), function(index, pred) return Namespace.localname(pred) end)
end

-- alias include? to ==, so that you can do paper.creator.include?(eyal)
-- without worrying whether paper.creator is single- or multi-valued
-- alias include? ==

--- returns uri of resource, can be overridden in subclasses.
-- called by lua tostring 
-- @name __tostring
-- @usage <code>tostring(resource)</code>
function Resource:__tostring()
	return "<"..self.uri..">"
end

function Resource:set_predicate(predicate, values)	
	FederationManager.delete(self, predicate)
	table.foreach(table.flatten(values), function(i, v) 
											FederationManager.add(self, predicate, v)
										 end)
	return values
end

function Resource:get_predicate(predicate, flatten)
	local flatten = flatten or false
	local values = Query():distinct('?o'):where(self, predicate, '?o'):execute({ flatten = flatten })

	--TODO: fix '<<' for Fixnum values etc (we cannot use values.instance_eval 
	-- because Fixnum cannot do instace_eval, they're not normal classes)
	--if values and oo.instanceof(values, RDFS.Resource) then
		-- prepare returned values for accepting << later, eg. in
		-- eyal.foaf::knows << knud
		
		-- store @subject, @predicate in returned values
		--values.instance_exec(self, predicate) do |s,p|
			--@subj = s
			--@pred = p
		--end

	  -- overwrite << to add triple to db
	  --values.instance_eval do
		 --def <<(value)
			--FederationManager.add(@subj, @pred, value)
		 --end
	  --end
	--end

	return values
end


--		private

--		def ancestors(predicate)
--			subproperty = Namespace.lookup(:rdfs,:subPropertyOf)
--			Query.new.distinct(:p).where(predicate, subproperty, :p).execute
--		end

-- returns all rdf:types of this resource but without a conversion to 
-- LOOP classes (it returns an array of RDFS.Resources)
function Resource:types()
	local type = Namespace.lookup('rdf', 'type')	
	
	-- we lookup the type in the database	
	local types = Query():distinct('?t'):where(self,type,'?t'):execute()
	
	-- we are also always of type rdfs:resource and of our own class (e.g. foaf:Person)
	local defaults = {}
	table.insert(defaults, Namespace.lookup('rdfs','Resource'))
	table.insert(defaults, oo.classof(self).class_uri)
	return Resource.uniq(table.add(types,defaults))
end

-- needs use check equality table's values to remove duplicates values because, some tables have theirs __eq meta-table's function redefined.
function Resource.uniq(tbl)		
	local t = table.uniq(table.dup(tbl))
	local t_result = {}	
	table.sort(t, function(v1, v2) return v1 < v2 end)	
	for i = 1, table.getn(t) do
		if t[i] ~= t[i+1] then
			table.insert(t_result, t[i])
		end
	end
	return t_result
end



-- proxy to manage find_by_ invocations
DynamicFinderProxy = oo.class{
  ns = nil,
  where = nil,
  value = nil,
}

-- construct proxy from find_by text
-- foaf::name
function DynamicFinderProxy:__init(find_string, where, ...)	
	local obj = oo.rawnew(self, {    
		where = where or {}
	})
	obj:parse_attributes(find_string, ...)
	return obj
end

function DynamicFinderProxy:__index(method, ...)	
	if(type(method) == 'string') then
		if DynamicFinderProxy[method] then
			return DynamicFinderProxy[method]
		end
		local args = {...}
		-- we store the ns:name for later (we need to wait until we have the 
		-- arguments before actually constructing the where clause): now we just 
		-- store that a where clause should appear about foaf:name

		-- if this method is called name_and_foaf::age we add ourself to the query
		-- otherwise, the query is built: we execute it and return the results
		if string.find(method, '_and_') then
			return self:parse_attributes(method, unpack(args))
		else
			table.insert(self.where, Namespace.lookup(self.ns, method))
			return self:query(unpack(args))
		end
	end
end

-- private 
-- split find_string by occurrences of _and_
function DynamicFinderProxy:parse_attributes(str, ...)
	local args = {...}	
	local attributes = string.split(str, '_and_')
	table.foreach(attributes, function(index, atr)
		-- attribute can be:
		-- - a namespace prefix (foaf): store prefix in @ns to prepare for method_missing
		-- - name (attribute name): store in where to prepare for method_missing
		if table.include(Namespace.abbreviations(), atr) then
			self.ns = atr:lower()
		else
			-- found simple attribute label, e.g. 'name'
			-- find out candidate (full) predicate for this localname: investigate 
			-- all possible predicates and select first one with matching localname
			local candidates = Query():distinct('?p'):where('?s','?p','?o'):execute()
			table.insert(self.where, table.select(candidates, function(index, cand) return Namespace.localname(cand) == atr end)[1])
		end
	end)
	-- if the last attribute was a prefix, return this dynamic finder (we'll 
	-- catch the following method_missing and construct the real query then)
	-- if the last attribute was a localname, construct the query now and return 
	-- the results
	if table.include(Namespace.abbreviations(), attributes[#attributes]) then	
		return self
	else	
		return self:query(unpack(args))
	end
end

-- construct and execute finder query
function DynamicFinderProxy:query(...)
	local args = {...}
	local sort_predicate
   -- extract options from args or use an empty hash (no options given)
	local options = type(args[#args]) == 'table' and args[#args] or {}			
	-- build query
   local query = Query():distinct('?s')
	table.foreach(self.where, function(i, predicate)
		-- specify where clauses, use context if given
		if options['context'] then
			query:where('?s', predicate, args[i], options['context'])
		else
			query:where('?s', predicate, args[i])
		end
	end)
    
	-- use sort order if given
    if options['order'] then
		sort_predicate = options['order']
      	query:sort('?sort_value')
      	-- add sort predicate where clause unless we have it already      	
		if not table.include(self.where, sort_predicate) then
			query:where('?s', sort_predicate, '?sort_value')
		end
    end

    if options['reverse_order'] then
      sort_predicate = options['reverse_order']
      query:reverse_sort('?sort_value')
		if not table.include(self.where, sort_predicate) then
			query:where('?s', sort_predicate, '?sort_value')
		end
    end
	if options['limit'] then
		query:limit(options['limit'])
	end
	if options['offset'] then
		query:offset(options['offset']) 
	end
	--$activerdflog.debug "executing dynamic finder: #{query.to_sp}"

    -- store the query results so that caller (Resource.method_missing) can 
    -- retrieve them (we cannot return them here, since we were invoked from 
    -- the initialize method so all return values are ignored, instead the proxy 
    -- itself is returned)
    self.value = query:execute()
    return self.value
end

-- it is here just because of luadoc
---------------------------------------------------------------------
--- Represents an RDF resource. Manages manipulations of that resource,
-- including data lookup (e.g. eyal.age), data updates (e.g. eyal.age=20),
-- class-level lookup (Person:find_by_name 'eyal'), and class-membership
-- (eyal.class ...Person).<br>
-- <br/><b>Dynamic attribute-based finders</b><br/><br/>
-- Dynamic attribute-based finders work by appending the name of an attribute to find_by_, 
-- so you get finders like <code>Person:find_by_name(name)</code>, <code>Person:find_by_last_name(last_name)</code>, 
-- <code>Payment:find_by_transaction_id(transaction_id)</code>.<br> 
-- So instead of writing <code>Person:find( { where = { name = "eyal" } } )</code>, 
-- you just do <code>Person:find_by_name("eyal")</code>. 
-- It‘s also possible to use multiple attributes in the same find by separating them with "and", 
-- so you get finders like <code>Person:find_by_user_name_and_password(user_name, password)</code> or 
-- even <code>Payment:find_by_purchaser_and_state_and_country(purchaser, state, country)</code>.<br>
-- @release $Id$
---------------------------------------------------------------------
module 'activerdf.RDFS.Resource'