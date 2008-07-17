---------------------------------------------------------------------
--- Maintains pool of adapter instances that are connected to datasources. 
--- Returns right adapter for a given datasource, by either reusing an
--- existing adapter-instance or creating new a adapter-instance.
--
-- @class module
-- @name ConnectionPool
-- $ svn propset svn:keywords Id "filename"
---------------------------------------------------------------------

local table = activerdf.table
local error = error

module "activerdf"

-- model with no inheritance
ConnectionPool = {}

-- currently active write-adapter (we can only write to one at a time)
ConnectionPool.write_adapter = nil

-- default setting for auto_flush
ConnectionPool.auto_flush = true

-- pool of all adapters
ConnectionPool.adapter_pool = {}

--pool of connection parameters to all adapter
ConnectionPool.adapter_parameters = {}

-- adapters-classes known to the pool, registered by the adapter-class
-- itself using register_adapter method, used to select new
-- adapter-instance for requested connection type
ConnectionPool.registered_adapter_types = {}

-- clears the pool: removes all registered data sources
function ConnectionPool.clear()
	--$activerdflog.info "ConnectionPool: clear called"
	ConnectionPool.adapter_pool = {}
	ConnectionPool.adapter_parameters = {}
	ConnectionPool.write_adapter = nil
end

function ConnectionPool.adapters()
	return table.dup(ConnectionPool.adapter_pool)
end

-- flushes all openstanding changes into the original datasource.
function ConnectionPool.flush()
	return ConnectionPool.write_adapter:flush()
end

function ConnectionPool.adapter_types()
	return table.keys(ConnectionPool.registered_adapter_types)
end

-- returns the set of currently registered read-access datasources
function ConnectionPool.read_adapters()
	return table.select(ConnectionPool.adapter_pool, function(index, adapter) return adapter.reads end)
end

function ConnectionPool.write_adapters()
	return table.select(ConnectionPool.adapter_pool, function(index, adapter) return adapter.writes end)
end

-- returns adapter-instance for given parameters (either existing or new)
function ConnectionPool.add_data_source(connection_params)
    --$activerdflog.info "ConnectionPool: add_data_source with params: #{connection_params.inspect}"	
	
    --either get the adapter-instance from the pool
    --or create new one (and add it to the pool)
   local index = table.index(ConnectionPool.adapter_parameters, connection_params)			
	local adapter
	
	if index == nil then
		-- adapter not in the pool yet: create it,
		-- register its connection parameters in parameters-array
		-- and add it to the pool (at same index-position as parameters)
		-- $activerdflog.debug("Create a new adapter for parameters #{connection_params.inspect}")
		adapter = ConnectionPool.create_adapter(connection_params)
		table.insert(ConnectionPool.adapter_parameters, connection_params)
		table.insert(ConnectionPool.adapter_pool, adapter)	  
	else
		-- if adapter parametrs registered already,
		-- then adapter must be in the pool, at the same index-position as its parameters
		-- $activerdflog.debug("Reusing existing adapter")
		adapter = ConnectionPool.adapter_pool[index]
	end	
		-- sets the adapter as current write-source if it can write		
	if adapter.writes then
		ConnectionPool.write_adapter = adapter
	end	
	return adapter
end
  
-- remove one adapter from activerdf
function ConnectionPool.remove_data_source(adapter)
	--$activerdflog.info "ConnectionPool: remove_data_source with params: #{adapter.to_s}"
    
	local index = table.index(ConnectionPool.adapter_pool, adapter)

	-- remove_data_source mit be called repeatedly, e.g because the adapter object is stale
	if index then
      ConnectionPool.adapter_parameters[index] = nil
		ConnectionPool.adapter_pool[index] = nil
      if table.emtpy(ConnectionPool.write_adapters) then
			ConnectionPool.write_adapter = nil
      else
			ConnectionPool.write_adapter = ConnectionPool.write_adapters[1]
      end
    end
end

-- sets adapter-instance for connection parameters (if you want to re-enable an existing adapter)
function ConnectionPool.set_data_source(adapter, connection_params)
	local connection_params = connection_params or {}
	local index = table.index(ConnectionPool.adapter_parameters, connection_params)
	if index == nil then
		table.insert(ConnectionPool.adapter_parameters, connection_params)
		table.insert(ConnectionPool.adapter_pool, adapter)
	else
		ConnectionPool.adapter_pool[index] = adapter
	end
	if adapter.writes then
		ConnectionPool.write_adapter = adapter
	end
	return adapter
end

-- aliasing add_data_source as add
-- (code bit more complicad since they are class methods)
ConnectionPool.add = ConnectionPool.add_data_source

-- adapter-types can register themselves with connection pool by
-- indicating which adapter-type they are
function ConnectionPool.register_adapter(_type, klass)	
	-- $activerdflog.info "ConnectionPool: registering adapter of type #{type} for class #{klass}"
	ConnectionPool.registered_adapter_types[_type] = klass
end

-- create new adapter from connection parameters
function ConnectionPool.create_adapter(connection_params)
	-- lookup registered adapter klass
	local klass = ConnectionPool.registered_adapter_types[connection_params['type']]	
	-- raise error if adapter type unknown
	if klass == nil then
		error("unknown adapter type "..connection_params['type'])
	end
	-- create new adapter-instance			
	return klass(connection_params)
end
