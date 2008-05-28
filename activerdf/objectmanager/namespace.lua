local setmetatable = setmetatable
local string = string
local tostring = tostring
local type = type
local error = error
local activerdf = activerdf

module "activerdf"

-- Manages namespace abbreviations and expansions
Namespace = oo.class{
  
}

Namespace.namespaces = {}
Namespace.inverted_namespaces = {}

-- registers a namespace prefix and its associated expansion (full URI)
-- e.g. :rdf and 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
function Namespace.register(prefix, fullURI)
	if ( tostring(prefix) == "" or tostring(fullURI) == "") then
		error('prefix nor uri can be empty')
	end
	local end_fullURI = tostring(fullURI):sub(-1,-1)
	if not (end_fullURI == '#' or end_fullURI == '/') then
		error("namespace uri should end with # or /")
	end
	-- $activerdflog.info "Namespace: registering #{fullURI} to #{prefix}"
	Namespace.namespaces[tostring(prefix)] = tostring(fullURI)
	Namespace.inverted_namespaces[tostring(fullURI)] = tostring(prefix)

	-- enable namespace lookups through FOAF::name
	-- if FOAF defined, add to it
	local ns
	local _prefix = string.upper(tostring(prefix))
	if activerdf[_prefix] then
	  ns = activerdf[_prefix]
	else
	  -- otherwise create a new module for it	  
	  ns = { }
	  local mt = {	__tostring = function() return tostring(_prefix) end, 
						__index = function (self, method, ...)			
											if method:match("^%u") then
												return ObjectManager.construct_class(Namespace.lookup(string.lower(tostring(self)), method))												
											end
											return Namespace.lookup(string.lower(tostring(self)), method)
										end
					}
	  setmetatable(ns, mt)
	  activerdf[_prefix] = ns
	end

	-- make some builtin methods private because lookup doesn't work otherwise 
	-- on e.g. RDF::type and FOAF::name
	--[:type, :name, :id].each {|m| private(m) }

    -- return the namespace proxy object
    return ns
 end


-- returns a resource whose URI is formed by concatenation of prefix and localname
function Namespace.lookup(prefix, localname)
	local full_resource = Namespace.expand(prefix, localname)
	return RDFS.Resource(full_resource)
end

-- returns URI (string) formed by concatenation of prefix and localname
function Namespace.expand(prefix, localname)
	return Namespace.namespaces[prefix]..localname
end

-- returns prefix (if known) for the non-local part of the URI,
-- or nil if prefix not registered
function Namespace.prefix(resource)
	-- get string representation of resource uri
	local uri 	
	if oo.instanceof(resource, RDFS.Resource) then
		uri = resource.uri 
	else 
		uri = tostring(resource)
	end

	-- uri.to_s gives us the uri of the resource (if resource given)
	-- then we find the last occurrence of # or / (heuristical namespace
	-- delimitor)
	local _, delimiter = string.find(uri, ".*([#/])")

	-- if delimiter not found, URI cannot be split into (non)local-part
	if not delimiter then return uri end

	-- extract non-local part (including delimiter)
	local nonlocal = string.sub(uri, 1, delimiter)

	return Namespace.inverted_namespaces[nonlocal]
end

-- returns local-part of URI
function Namespace.localname(resource)
	if not resource.uri then		
		error("localname called on something that doesn't respond to uri")
	end
	
	-- get string representation of resource uri
	local uri = resource.uri
	
	if type(uri) == "function" then
		uri = resource:uri()
	end
	
	local _, delimiter = string.find(uri, ".*([#/])")

	if not delimiter or delimiter == string.len(uri) then
	  return uri
	else
	  return string.sub(uri, delimiter + 1)
	end
end

-- returns currently registered namespace abbreviations (e.g. :foaf, :rdf)
function Namespace.abbreviations()
	return table.keys(Namespace.namespaces)
end

Namespace.register('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')
Namespace.register('rdfs', 'http://www.w3.org/2000/01/rdf-schema#')
Namespace.register('owl', 'http://www.w3.org/2002/07/owl#')
