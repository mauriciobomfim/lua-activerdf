-- The SuggestingAdapter is an extension to rdflite that can recommand
-- additional predicates for a given resource, based on usage statistics in the
-- whole dataset. E.g. given a dataset with FOAF data, one can ask a suggestion
-- for a person and get a recommendation for this person to also use
-- foaf:birthday. You can use this adapter in any collaborative editing setting:
-- it leads the community to converge on terminology (everybody will use the
-- same foaf:birthday to define somebody's birthday).
require 'activerdf'

local ConnectionPool = activerdf.ConnectionPool
local string = activerdf.string
local execute = os.execute
local time = os.time
local RDFS = activerdf.RDFS
local table = activerdf.table
local oo = activerdf.oo

module "activerdf_rdflite"

SuggestingAdapter = oo.class({}, FetchingAdapter)

ConnectionPool.register_adapter( 'suggesting', SuggestingAdapter )

local _old_initialize = FetchingAdapter

-- initialises the adapter, see RDFLite for description of possible parameters.
function SuggestingAdapter.new(...)
	return SuggestingAdapter(...)
end

function SuggestingAdapter:__init(params)
	obj = _old_initialize(params)
	obj.db:execute('drop view if exists occurrence')
	obj.db:execute('create view occurrence as select p, count(distinct s) as count from triple group by p')

	obj.db:execute('drop view if exists cooccurrence')
	obj.db:execute('create view cooccurrence as select t0.p as p1,t1.p as p2, count(distinct t0.s) as count from triple as t0 join triple as t1 on t0.s=t1.s and t0.p!=t1.p group by t0.p, t1.p')
	return obj
end

  -- suggests additional predicates that might be applicable for the given resource
function SuggestingAdapter:suggest(resource)
	-- $activerdflog.debug "starting suggestions for #{size} triples"
	local time = time()

	local predicates = {}
	local own_predicates = resource:direct_predicates()

	construct_occurrence_matrix()
	construct_cooccurrence_matrix()

	table.foreach ( own_predicates, function ( i, p )
		if occurrence(p) > 1 then
			table.insert( predicates , p )
		end 
	end)

	-- fetch all predicates co-occurring with our predicates
	local candidates = table.map ( predicates, function ( i, p ) return cooccurring(p) end )
	
	if table.empty ( candidates ) then
		return nil
	end 

	-- perform set intersection
	
	candidates = table.flatten( table.inject( candidates, function( intersec, n ) return table.intersection(intersec, n) end ) )
	candidates = table.difference(candidates, own_predicates)

	local suggestions = table.map ( candidates, function ( i, candidate )
		local score = table.inject(1.0, predicates, function ( score, p )
			return score * cooccurrence(candidate, p) / occurrence(p)
		end)
		return { candidate, score }
	end)
	-- $activerdflog.debug "suggestions for #{resource} took #{Time.now-time}s"
	return suggestions
end

	-- private
	local function construct_occurrence_matrix(self)
		self.occurrence = {}
		local row = {}
		local cur = self.db:execute('select * from occurrence where count > 1')		
		while cur:fetch(row, 'a') do
			self.occurrence[parse(row.p)] = tonumber(row.count)
		end
		cur:close()
	end
	
	local function construct_cooccurrence_matrix(self)
		self.cooccurrence = {}
		local row = {}
		local cur = self.db:execute('select * from cooccurrence')
		
		while cur:fetch(row, 'a') do
			self.cooccurrence[parse(row.p1)] = self.cooccurrence[parse(row.p1)] or {}
			self.cooccurrence[parse(row.p1)][parse(row.p2)] = tonumber(row.count)
		end
	end

	local function occurrence(self, predicate)
		return self.occurrence[predicate] or 0
	end

	local function cooccurrence(self, p1, p2)
		return self.cooccurrence[p1][p2] or 0
	end

	local function cooccurring(self, predicate)
		return table.keys ( self.cooccurrence[predicate] )
	end