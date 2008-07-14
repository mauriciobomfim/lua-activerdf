-- ActiveRDF Tests
loadfile('lua/activerdf/test/test_adapters.lua')()
loadfile('lua/activerdf/test/federation/test_connection_pool.lua')()
loadfile('lua/activerdf/test/federation/test_federation_manager.lua')()
loadfile('lua/activerdf/test/objectmanager/test_literal.lua')()
loadfile('lua/activerdf/test/objectmanager/test_namespace.lua')()
loadfile('lua/activerdf/test/objectmanager/test_object_manager.lua')()
loadfile('lua/activerdf/test/objectmanager/test_resource_reading.lua')()
loadfile('lua/activerdf/test/objectmanager/test_resource_writing.lua')()
loadfile('lua/activerdf/test/queryengine/test_ntriples_parser.lua')()
loadfile('lua/activerdf/test/queryengine/test_query2sparql.lua')()
loadfile('lua/activerdf/test/queryengine/test_query_engine.lua')()

-- Sparql Adapter Tests
loadfile('lua/activerdf_sparql/test/test_sparql_adapter.lua')()

-- RDFLite Tests
loadfile('lua/activerdf_rdflite/test/test_rdflite.lua')()