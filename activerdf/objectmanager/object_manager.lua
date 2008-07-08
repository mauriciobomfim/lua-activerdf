require 'activerdf.queryengine.query'

local string = activerdf.string
local setmetatable = setmetatable 
local getmetatable = getmetatable
local ipairs = ipairs
local type = type
local tostring = tostring

module "activerdf"

Modules = {}

-- Constructs LOOP classes for RDFS classes (in the right namespace)
ObjectManager = oo.class{}

ObjectManager.__flatten = function (t,f,complete)		
	for _,v in ipairs(t) do		
		if type(v) == "table" and not oo.instanceof(v, RDFS.Resource) then		
			 if (complete or type(v[1]) == "table") then
				  ObjectManager.__flatten(v,f,complete)				  				  
			 else
				  f[#f+1] = v		  
			 end
		else			
			 f[#f+1] = v
		end
	end
end

ObjectManager.flatten = function(t,f,complete)
  local f = { }   
  ObjectManager.__flatten(t,f,true)    
  return f
end

-- Constructs empty LOOP classes for all RDF types found in the data. Allows 
-- users to invoke methods on classes (e.g. FOAF.Person) without
-- getting symbol undefined errors (because e.g. foaf:person wasnt encountered
-- before so no class was created for it)

function ObjectManager.construct_classes()
	-- find all rdf:types and construct class for each of them
	-- q = Query.new.select(:t).where(:s,Namespace.lookup(:rdf,:type),:t)
	-- find everything defined as rdfs:class or owl:class
	local _type = Namespace.lookup('rdf','type')
	local rdfsklass = Namespace.lookup('rdfs','Class')

	-- TODO: we should not do this, we should not support OWL
	-- instead, owl:Class is defined as subclass-of rdfs:Class, so if the 
	-- reasoner has access to owl definition it should work out fine.
	local owlklass = Namespace.lookup('owl','Class')

	local klasses = {}
 
	table.insert(klasses, Query():distinct('?s'):where('?s',_type, rdfsklass):execute())
	table.insert(klasses, Query():distinct('?s'):where('?s',_type, owlklass):execute())
	
	-- flattening to get rid of nested arrays
	-- compacting array to get rid of nil (if one of these queries returned nil)		
	local klasses = ObjectManager.flatten(klasses)	
	-- $activerdflog.debug "ObjectManager: construct_classes: classes found: #{klasses}"
	
	-- then we construct a LOOP class for each found rdfs:class
	-- and return the set of all constructed classes			
	
	return table.map(klasses, function(i,t) return ObjectManager.construct_class(t) end)
end

-- constructs LOOP class for the given resource (and puts it into the module as
-- defined by the registered namespace abbreviations)
function ObjectManager.construct_class(resource)	
	-- get prefix abbreviation and localname from type
   -- e.g. :foaf and Person
   local localname = Namespace.localname(resource)
   local prefix = Namespace.prefix(resource)
	local modulename
   -- find names for the module and class
   -- e.g. FOAF and Person
   if not prefix then
		-- if the prefix is unknown, we create our own from the full URI
		modulename = ObjectManager.create_module_name(resource)
		-- $activerdflog.debug "ObjectManager: construct_class: constructing modulename #{modulename} from URI #{resource}"
	else
		-- otherwise we convert the registered prefix into a module name
		modulename = ObjectManager.prefix_to_module(prefix)
		--$activerdflog.debug "ObjectManager: construct_class: constructing modulename #{modulename} from registered prefix #{prefix}"
   end
   local klassname = ObjectManager.localname_to_class(localname)

   -- look whether module defined
   -- else: create it
   local _module
	if Modules[modulename] then
		-- $activerdflog.debug "ObjectManager: construct_class: module name #{modulename} previously defined"
		_module = Modules[modulename]
	else
      -- $activerdflog.debug "ObjectManager: construct_class: defining module name #{modulename} now"
		Modules[modulename] = {}
		local mt = { __tostring = function() return tostring(modulename) end }		
		setmetatable(Modules[modulename], mt)
		_module = Modules[modulename]
	end

	-- look whether class defined in that module
	if _module[klassname] then
		-- $activerdflog.debug "ObjectManager: construct_class: given class #{klassname} defined in the module"
		-- if so, return the existing class				
		return _module[klassname]
	else
      	--$activerdflog.debug "ObjectManager: construct_class: creating given class #{klassname}"
		-- otherwise: create it, inside that module, as subclass of RDFS::Resource
		-- (using toplevel Class.new to prevent RDFS::Class.new from being called)		
		_module[klassname] = oo.class({}, RDFS.Resource)				
		local klass = _module[klassname]		
		klass.class_uri = resource
		getmetatable(getmetatable(klass)).__index = RDFS.Resource.send
		getmetatable(klass).__eq = RDFS.Resource.__eq	
		return klass
	end
end


function ObjectManager.prefix_to_module(prefix)
	-- TODO: remove illegal characters
	return string.upper(prefix)
end

function ObjectManager.localname_to_class(localname)
	-- replace illegal characters inside the uri
	-- and capitalize the classname	
	return string.capitalize(ObjectManager.replace_illegal_chars(localname))
end

function ObjectManager.create_module_name(resource)
	-- TODO: write unit test to verify replacement of all illegal characters

	-- extract non-local part (including delimiter)
	local uri = resource.uri		
	local _, delimiter = string.find(uri, ".*([#/])")
	local nonlocal = string.sub(uri, 1, delimiter)

	-- remove illegal characters appearing at the end of the uri (e.g. trailing 
	-- slash)
	local cleaned_non_local = nonlocal:gsub("[^%w]+$","")
	-- replace illegal chars within the uri
	return ObjectManager.replace_illegal_chars(cleaned_non_local):upper()
end

function ObjectManager.replace_illegal_chars(name)
	return name:gsub("[^%w]+","_")
end

  --declare the class level methods as private with these directives
  --private_class_method :prefix_to_module
  --private_class_method :localname_to_class
  --private_class_method :create_module_name
  --private_class_method :replace_illegal_chars

