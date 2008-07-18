require 'activerdf.queryengine.query2sparql'

-- Generic superclass of all adapters
module 'activerdf'

ActiveRdfAdapter = oo.class {
	-- indicate if adapter can read and write
	reads = false,
	writes = false,	
}

--- translate a query to its string representation
-- @param query an instance of class Query
-- @return string
function ActiveRdfAdapter:translate(query)
	return Query2SPARQL.translate(query)
end