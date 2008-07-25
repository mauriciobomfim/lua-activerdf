require 'activerdf.queryengine.query2sparql'
local oo = activerdf.oo

---------------------------------------------------------------------
--- Generic superclass of all adapters
-- @release $Id$
---------------------------------------------------------------------
module ( 'activerdf.ActiveRdfAdapter', oo.class )

-- indicate if adapter can read and write
reads = false
writes = false

--- translate a query to its string representation.
-- @name translate
-- @param query an instance of class Query.
-- @return string
function translate(query)
	return Query2SPARQL.translate(query)
end