---------------------------------------------------------------------
--- Maintains pool of adapter instances that are connected to datasources. 
-- Returns right adapter for a given datasource, by either reusing an
-- existing adapter-instance or creating new a adapter-instance.
--
-- @release $Id$
---------------------------------------------------------------------
local table = activerdf.table
local error = error

module 'activerdf.ConnectionPool'

-- model with no inheritance
-- ConnectionPool = {}

-- currently active write-adapter (we can only write to one at a time)
write_adapter = nil

-- default setting for auto_flush
auto_flush = true

-- pool of all adapters
adapter_pool = {}

-- pool of connection parameters to all adapter
adapter_parameters = {}

-- adapters-classes known to the pool, registered by the adapter-class
-- itself using register_adapter method, used to select new
-- adapter-instance for requested connection type
registered_adapter_types = {}

--- clears the pool: removes all registered data sources
function clear()
	--$activerdflog.info "ConnectionPool: clear called"
	adapter_pool = {}
	adapter_parameters = {}
	write_adapter = nil
end

--- returns the set of currently registered datasources
function adapters()
	return table.dup(adapter_pool)
end

--- flushes all openstanding changes into the original datasource.
function flush()
	return write_adapter:flush()
end

--- returns the set of currently registered datasources types
function adapter_types()
	return table.keys(registered_adapter_types)
end

--- returns the set of currently registered read-access datasources
function read_adapters()
	return table.select(adapter_pool, function(index, adapter) return adapter.reads end)
end

--- returns the set of currently registered write-access datasources
function write_adapters()
	return table.select(adapter_pool, function(index, adapter) return adapter.writes end)
end

--- returns adapter-instance for given parameters (either existing or new)
-- @param connection_params a table with at least the field type for the type of datasource. Others fields depends on datasource. 
-- @usage for sparql: <code>ConnectionPool.add_data_source{ type = 'sparql', url = 'http://www.example.org/sparql' }</code>
-- @usage for rdflite: <code>ConnectionPool.add_data_source{ type = 'rdflite', url = '/path/to/database.db' }</code>
-- @return adapter-instance for given parameters 
function add_data_source(connection_params)
    --$activerdflog.info "ConnectionPool: add_data_source with params: #{connection_params.inspect}"	
	
    --either get the adapter-instance from the pool
    --or create new one (and add it to the pool)
   	local index = table.index(adapter_parameters, connection_params)			
	local adapter
	
	if index == nil then
		-- adapter not in the pool yet: create it,
		-- register its connection parameters in parameters-array
		-- and add it to the pool (at same index-position as parameters)
		-- $activerdflog.debug("Create a new adapter for parameters #{connection_params.inspect}")
		adapter = create_adapter(connection_params)
		table.insert(adapter_parameters, connection_params)
		table.insert(adapter_pool, adapter)	  
	else
		-- if adapter parametrs registered already,
		-- then adapter must be in the pool, at the same index-position as its parameters
		-- $activerdflog.debug("Reusing existing adapter")
		adapter = adapter_pool[index]
	end	
		-- sets the adapter as current write-source if it can write		
	if adapter.writes then
		write_adapter = adapter
	end	
	return adapter
end
  
--- remove one adapter from activerdf
-- @param adapter an instance of a datasource to be removed
function remove_data_source(adapter)
	--$activerdflog.info "ConnectionPool: remove_data_source with params: #{adapter.to_s}"
    
	local index = table.index(adapter_pool, adapter)

	-- remove_data_source mit be called repeatedly, e.g because the adapter object is stale
	if index then
      adapter_parameters[index] = nil
		adapter_pool[index] = nil
      if table.emtpy(write_adapters) then
			write_adapter = nil
      else
			write_adapter = write_adapters[1]
      end
    end
end

--- sets adapter-instance for connection parameters (if you want to re-enable an existing adapter)
-- @param adapter an adapter-instance
-- @param connection_params new connection parameters for adapter
-- @return the same adapter
function set_data_source(adapter, connection_params)
	local connection_params = connection_params or {}
	local index = table.index(adapter_parameters, connection_params)
	if index == nil then
		table.insert(adapter_parameters, connection_params)
		table.insert(adapter_pool, adapter)
	else
		adapter_pool[index] = adapter
	end
	if adapter.writes then
		write_adapter = adapter
	end
	return adapter
end

--- aliasing add_data_source as add
add = add_data_source

--- adapter-types can register themselves with connection pool by indicating which adapter-type they are
-- @param type a string for adapter type e.g 'rdflite'
-- @param klass a class for an adapter 
function register_adapter(type, klass)	
	-- $activerdflog.info "ConnectionPool: registering adapter of type #{type} for class #{klass}"
	registered_adapter_types[type] = klass
end

-- create new adapter from connection parameters
function create_adapter(connection_params)
	-- lookup registered adapter klass
	local klass = registered_adapter_types[connection_params['type']]	
	-- raise error if adapter type unknown
	if klass == nil then
		error("unknown adapter type "..connection_params['type'])
	end
	-- create new adapter-instance			
	return klass(connection_params)
end
