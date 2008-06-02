-- FetchingAdapter is an extension to rdflite for fetching RDF from online sources.
require 'activerdf'

local ConnectionPool = activerdf.ConnectionPool
local string = activerdf.string
local execute = os.execute
local RDFS = activerdf.RDFS
local oo = activerdf.oo

module "activerdf_rdflite"

FetchingAdapter = oo.class({}, RDFLite)

ConnectionPool.register_adapter('fetching', 'FetchingAdapter')

	-- TODO: check that rapper is installed

	-- fetches RDF/XML data from given url and adds it to the datastore, using the 
	-- source url as context identifier.
function FetchingAdapter:fetch ( url )
    -- check if url starts with http://
    if not url:match('http:\/\/(.*)') then
    	return nil
    end
	
	-- $activerdflog.debug "fetching from #{url}"
	
	--model = Redland::Model.new
	--parser = Redland::Parser.new('rdfxml')
	--scan = Redland::Uri.new('http://feature.librdf.org/raptor-scanForRDF')
	--enable = Redland::Literal.new('1')
	--Redland::librdf_parser_set_feature(parser, scan.uri, enable.node)
	--parser.parse_into_model(model, url)
	--triples = Redland::Serializer.ntriples.model_to_string(nil, model)
	
	local triples = os.execute('rapper --scan --quiet "'..url..'"')
	local lines = string.split( triples, '\n' )
	-- $activerdflog.debug "found #{lines.size} triples"
	
	local context = RDFS.Resource( url )
	return self:add_ntriples(triples, context)
end