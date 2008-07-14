require 'activerdf'

local oo = activerdf.oo

module "activerdf_sparql.SparqlAdapter"

-- Parser for SPARQL XML result set.
SparqlResultParser = oo.class{}

function SparqlResultParser:__init()
	return oo.rawnew(self, {
		result = {},
		vars = {},
		current_type = nil    
	})
end
  
function SparqlResultParser:tag_start(name, attrs)
	if name == 'variable' then
      table.insert(self.vars, attrs['name'])		
	elseif name == 'result' then
      self.current_result = {}
	elseif name == 'binding' then
      self.index = table.index(self.vars, attrs['name'])
	elseif name == 'bnode' or name == 'literal' or name == 'typed-literal' or name == 'uri' then
      self.current_type = name
   end
end
  
function SparqlResultParser:tag_end(name)
	if name == "result" then
		table.insert(result, self.current_result)
   elseif name == 'bnode' or name == 'literal' or name == 'typed-literal' or name == 'uri' then
      self.current_type = nil
   elseif name == "sparql" then
   end
end
  
function SparqlResultParser:text(text)
	if not self.current_type == nil then
		self.current_result[self.index] = self:create_node(self.current_type, text)  
	end
end

-- create LOOP objects for each RDF node
function SparqlResultParser:create_node(_type, value)
	if _type == 'uri' then
		return RDFS.Resource(value)
   elseif _type == 'bnode' then
		return nil
   elseif _type == 'literal' or _type == 'typed-literal' then
		return tostring(value)
   end
end
