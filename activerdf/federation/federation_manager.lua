local type = type
local error = error
local print = print

module "activerdf"

-- Manages the federation of datasources: distributes queries to right 
-- datasources and merges their results
FederationManager = oo.class{}

-- add triple s,p,o to the currently selected write-adapter
function FederationManager.add(s,p,o)
	-- TODO: allow addition of full graphs	
	if not ConnectionPool.write_adapter then 
		error("cannot write without a write-adapter")
	end
	return ConnectionPool.write_adapter:add(s,p,o)
end

-- delete triple s,p,o from the currently selected write adapter (s and p are 
-- mandatory, o is optional, symbols are interpreted as wildcards)
function FederationManager.delete(s,p,o)
	local o = o or '?all'
	if not ConnectionPool.write_adapter then		
		error("cannot write without a write-adapter")
	end
	return ConnectionPool.write_adapter:delete(s,p,o)
end

-- executes read-only queries
-- by distributing query over complete read-pool
-- and aggregating the results
function FederationManager.query(q, options, block)	
	local options = options or { flatten = true }	
	-- build Array of results from all sources
	-- TODO: write test for sebastian's select problem
	-- (without distinct, should get duplicates, they
	-- were filtered out when doing results.union)
	local results = {}

	if table.empty(ConnectionPool.read_adapters()) then		
		error("cannot execute query without data sources")
	end

	-- ask each adapter for query results
	-- and yield them consequtively
	if type(block) == 'function' then
		table.foreach(ConnectionPool.read_adapters(), function(index, source)
			--check that if is correct: source:query(q) do |*clauses|			
			table.foreach(source:query(q), function(index, clauses)								
				block(unpack(clauses))
			end)
		end)
	else
		table.foreach(ConnectionPool.read_adapters(), function(index, source)
			local source_results = source:query(q)			
			table.foreach(source_results, function(index, clauses)
				table.insert(results, clauses)
			end)			
		end)					
		-- filter the empty results
		results = table.reject(results, function(index, ary) return table.empty(ary) end)
		
		-- remove duplicate results from multiple
		-- adapters if asked for distinct query
		-- (adapters return only distinct results,
		-- but they cannot check duplicates against each other)
		if q._distinct then 
			results = table.uniq(results)
		end		
		
		-- flatten results array if only one select clause
		-- to prevent unnecessarily nested array [[eyal],[renaud],...]
		if #q.select_clauses == 1 or q._ask then
			results = ObjectManager.flatten(results)			
		end		
		-- remove array (return single value or nil) if asked to
		if options['flatten'] or q._count then					
			if #results == 0 then				
				results = nil
			elseif #results == 1 then				
				results = results[1]				
			end
		end
	end	
	return results
end

