require 'activerdf.queryengine.query2sparql'

module "activerdf"

-- Generic superclass of all adapters
ActiveRdfAdapter = oo.class {
	-- indicate if adapter can read and write
	reads = false,
	writes = false,
	-- translate a query to its string representation
}

function ActiveRdfAdapter:translate(query)
	Query2SPARQL.translate(query)
end
