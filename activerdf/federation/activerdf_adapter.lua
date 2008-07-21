---------------------------------------------------------------------
-- Generic superclass of all adapters
-- @release $Id$
-- LUADOC COMMENTS ARE AT END OF THIS FILE
---------------------------------------------------------------------
require 'activerdf.queryengine.query2sparql'
local module = module

module 'activerdf'

ActiveRdfAdapter = oo.class {
	-- indicate if adapter can read and write
	reads = false,
	writes = false,	
}

--- translate a query to its string representation.
-- @name translate
-- @param query an instance of class Query.
-- @return string
function ActiveRdfAdapter:translate(query)
	return Query2SPARQL.translate(query)
end

-- it is here just because of luadoc
---------------------------------------------------------------------
--- Generic superclass of all adapters.
-- @release $Id$
-- LUADOC COMMENTS ARE AT END OF THIS FILE
---------------------------------------------------------------------
module 'activerdf.ActiveRdfAdapter'