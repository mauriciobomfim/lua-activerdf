require 'activerdf'
--require 'activerdf.federation.connection_pool'
require 'activerdf.test.common'

local ConnectionPool = activerdf.ConnectionPool
local Namespace = activerdf.Namespace
local RDFS = activerdf.RDFS

-- TestResourceWriting 
function setup()
	ConnectionPool.clear()
end

function test_update_value()
	Namespace.register('ar', 'http://activerdf.org/test/')
	local adapter = get_write_adapter()

	local eyal = RDFS.Resource.new( 'http://activerdf.org/test/eyal' )
	assert ( not pcall ( loadstring "eyal.age = 18" ) )

	eyal.ar.age = 100
	assert ( 100 == eyal.ar.age )
	assert ( activerdf.table.equals ( { 100 }, eyal.all_ar.age ) )

	eyal.ar.age = { 100, 80 }
	assert ( activerdf.table.equals ( { 100, 80 }, eyal.ar.age ) )
end

setup()
test_update_value()