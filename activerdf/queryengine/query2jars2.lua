-- Translates abstract query into jars2 query.
-- (ignores ASK queries)

module "activerdf"

Query2Jars2 = oo.class{}


function Query2Jars2.translate(query)
	local str = ""
	if query._select then
		-- concatenate each where clause using space: s p o
		-- and then concatenate the clauses using dot: s p o . s2 p2 o2 .
		str = str .. table.concat(table.map(query.where_clauses, function(i, w) return table.concat(table.map(w, function(i,w) return '?'..tostring(w) end), ' ') end), ' .\n')..' .'		-- TODO: should we maybe reverse the order on the where_clauses? it depends 
		-- on Andreas' answer of the best order to give to jars2. Users would 
		-- probably put the most specific stuff first, and join to get the 
		-- interesting information. Maybe we should not touch it and let the user 
		-- figure it out.
	end
	
	--$activerdflog.debug "Query2Jars2: translated #{query} to #{str}"
	return str
end

