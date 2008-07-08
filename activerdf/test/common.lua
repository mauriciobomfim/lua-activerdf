require 'activerdf'
local oo = activerdf.oo
local ConnectionPool = activerdf.ConnectionPool
local table = activerdf.table

function get_adapter()
	local types = ConnectionPool.adapter_types()
	if table.include(types, 'rdflite') then
		return get_rdflite()
	elseif table.include(types, 'redland') then
		return get_redland()
	elseif table.include(types, 'sparql') then		
		return get_sparql()
	elseif table.include(types, 'yars') then
		return get_yars()
	elseif table.include(types, 'jars2') then
		return get_jars2()
	else		
		error "no suitable adapter found for test"
	end
end

function get_read_only_adapter()
	if table.include(ConnectionPool.adapter_types(), 'sparql') then
		return get_sparql()
	else		
		error "no suitable read-only adapter found for test"
	end
end

-- TODO make this work with a list of existing adapters, not only one
function get_different_adapter(existing_adapter)
	local types = ConnectionPool.adapter_types()
	if table.include(types, 'rdflite') then
		if oo.class(existing_adapter) == activerdf.adapters.rdflite.RDFLite then
			return ConnectionPool.add { type = 'rdflite', unique = true }
		else
			return get_rdflite()
		end
	elseif table.include(types, 'redland') and oo.class(existing_adapter) ~= activerdf.adapters.redland.RedlandAdapter then
		return get_rdflite()
	elseif table.include(types, 'sparql') and oo.class(existing_adapter) ~= activerdf.adapters.sparql.SparqlAdapter then
		return get_sparql()
	elseif table.include(types, 'yars') and oo.class(existing_adapter) ~= activerdf.adapters.yars.YarsAdapter then
		return get_yars()
	elseif table.include(types, 'jars2') and oo.class(existing_adapter) ~= activerdf.adapters.jars2.Jars2Adapter then
		return get_jars2()
	else		
		error "only one adapter on this system, or no suitable adapter found for test"
	end
end

function get_all_read_adapters()
	local types = ConnectionPool.adapter_types()
	local adapters = table.map(types, function(i, _type) return _G['get_'.._type]() end)
	return table.select(adapters, function(i, adapter) return adapter.reads end)
end

function get_all_write_adapters()
	local types = ConnectionPool.adapter_types()
	local adapters = table.map(types, function(i, _type) return _G['get_'.._type]() end)
	return table.select(adapters, function(i, adapter) return adapter.writes end)
end

function get_write_adapter()
	local types = ConnectionPool.adapter_types()
	if table.include(types, 'rdflite') then
		return get_rdflite()
	elseif table.include(types, 'redland') then
		return get_redland()
	elseif table.include(types, 'yars') then
		return get_yars()
	elseif table.include(types, 'jars2') then
		return get_jars2()
	else		
		error "no suitable adapter found for test"
	end
end

-- TODO use a list of exisiting adapters not only one
function get_different_write_adapter(existing_adapter)
	local types = ConnectionPool.adapter_types()
	if table.include(types, 'rdflite') then
		if oo.class(existing_adapter) == activerdf.adapters.rdflite.RDFLite then
			return ConnectionPool.add { type = 'rdflite', unique = true }
		else
			return get_rdflite()
		end
	elseif table.include(types, 'redland') and oo.class(existing_adapter) ~= activerdf.adapters.redland.RedlandAdapter then
		return get_redland()
	elseif table.include(types, 'yars') and oo.class(existing_adapter) ~= activerdf.adapters.yars.YarsAdapter then
		return get_yars()
	else		
		error "only one write adapter on this system, or no suitable write adapter found for test"
	end
end

function get_sparql()
	return ConnectionPool.add { type = 'sparql', url = "http://sparql.org/books", engine = 'joseki', results = 'sparql_xml' }
end

function get_fetching() return ConnectionPool.add { type = 'fetching'} end
function get_suggesting() return ConnectionPool.add { type = 'suggesting' } end
function get_rdflite() return ConnectionPool.add { type = 'rdflite' } end
function get_redland() return ConnectionPool.add { type = 'redland' } end
function get_yars() return ConnectionPool.add { type = 'yars' } end
function get_jars2() return ConnectionPool.add { type = 'jars2' } end