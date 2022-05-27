--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

function init()
		
	points = {} -- point information
	--[[
		[i]
			.pos : Vec -- position
			.height : float -- same as pos[2]
			.rgDone : bool
			.regionIndex : int
			.color : int -- used for region growing
			.neighbors : table[int] -- all neighborers points
				[j]
					.x : float
					.z : float
					.stage : int
					.edge : bool
			.pf : table -- pathfinder stuff for a point
				.color : int -- 0: waiting, 1: in queue, 2: done
				.previous : int -- index of the previous point in the path
				.dist : table -- squared distance...
					.a : float -- ...from the starting point
					.b : float -- ...from the target point
		.pf : table -- pathfinder stuff for all the points
				.queue : table -- the queue of grey (color 1) points
				.a : Vec() -- starting point
				.b : Vec() -- target point
				.batchSize : int
				.path : table : Vec() -- the list of points to travel to
				.current : int -- index of the node currently computed
				.first : first pass of the pathfinder
	]]
	
	indexList = {} -- index in points
	--[[
		[x] : table[float]
			[z] : float
				[stage] : int
	]]
	
	process = {
		points = {},
		edgesDone = false,
		batchSize = 500,
		batchSizeEdges = 500,
		i = 0
	} -- pos to process
	--[[
		.i : int
		.points : table[float]
			[i]
				.x : float
				.z : float
	]]
	
	timer = {
		raycast = 0,
		edges = 0,
		regionMapping = 0,
		regionMerging = 0,
		regionColoring = 0,
		pathfinder = 0,
		total = 0,
		display = true
	}
	
	status = 0
	
	displayRegions = false
	
	step = 1.0 -- default 1, max 4
	radiusSize = step / 2
	maxDeltaPerMeter = 1.1 --0.75
	connex8 = false
	
	maxStage = 10
	
	rg = {
		i = 1, -- region growing stuff
		NO_COLOR = -1,
		toCompute = {},
		colorCount = 0,
		done = false,
		batchSize = 2500,
		lastBlank = 1,
		colorMapping = {
			region = {},
			color = {},
			size = {}
		},
		status = 1,
		processRegion = {}
	}
	
	world = {}
	world.aa, world.bb = GetBodyBounds(GetWorldBody())
	world.aa = floorVec(world.aa)
	world.bb = floorVec(world.bb)
	
	addPointToProcess(world.aa, world.bb)
	
end


function tick(dt)
	--processDebugCross()
	--pointsDebugCross()
	
	if displayRegions then
		edgesDebugLine(true, 0)
	end
	if status > 3 then
		displayPath()
	end
	
	if timer.display then
		debugWatchTable(timer)
	end
	
	if InputPressed('shift') then
		displayRegions = not displayRegions
	end
	
	clearConsole()
	DebugPrint("Status: " .. status .. "." .. rg.status)
	if status > 0 and status < 4 then
		timer.total = timer.total + dt
	end
	
	if status == 0 and InputPressed("c") then
		status = 1

	elseif status == 1 then
		processPoint(process.batchSize)
		timer.raycast = timer.raycast + dt
		DebugPrint(process.i .. " / " .. #process.points)
			
	elseif status == 2 then
		processEdges(process.batchSizeEdges)
		timer.edges = timer.edges + dt
		DebugPrint(process.i .. " / " .. #points)
		
	elseif status == 3 then
		if rg.status == 1 then
			timer.regionMapping = timer.regionMapping + dt
			DebugPrint(rg.i .. " / " .. #points)
		elseif rg.status == 2 then
			timer.regionMerging = timer.regionMerging + dt
			DebugPrint(rg.i .. " / " .. #points)
		elseif rg.status == 3 then
			timer.regionColoring = timer.regionColoring + dt
		end
		regionGrowing(rg.batchSize)
		
	elseif status == 4 then
		if VecLength(points.pf.a) > 0 and VecLength(points.pf.b) > 0 then
			status = 5
			resetPathfinder()
			timer.pathfinder = 0
		elseif InputPressed("grab") then
			points.pf.b = GetPlayerTransform().pos
		elseif InputPressed("usetool") then
			points.pf.a = GetPlayerTransform().pos
		end
		
	elseif status == 5 then
		pathfinderDebugCross()
		computePath(points.pf.batchSize)
		timer.pathfinder = timer.pathfinder + dt
		DebugPrint("Computing")
		
	elseif status == 6 then
		points.pf.a = Vec(0, 0, 0)
		points.pf.b = Vec(0, 0, 0)
		status = 4
	end
end


function update(dt)
	
end


function draw(dt)

end

---------------------------------

function clearConsole()
	for i=1, 25 do
		DebugPrint("")
	end
end

function rand(minv, maxv)
	minv = minv or nil
	maxv = maxv or nil
	if minv == nil then
		return math.random()
	end
	if maxv == nil then
		return math.random(minv)
	end
	return math.random(minv, maxv)
end

--Helper to return a random number in range mi to ma
function randFloat(mi, ma)
	return math.random(1000)/1000*(ma-mi) + mi
end

--Return a random vector of desired length
function randVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


function floorVec(v)
	return Vec(math.floor(v[1]), math.floor(v[2]), math.floor(v[3]))
end

function round(value, dec)
	local d = dec or 0
	local mult = math.pow(10, d)
	return math.floor(value * mult) / mult
end

function roundVec(vec, dec)
	local d = dec or 0
	for i=1, #vec do
		vec[i] = round(vec[i])
	end
	return vec
end

function exportToRegistry()
	--TODO
end

function importFromRegistry()
	--TODO
end

function debugWatchTable(t)
	for k, v in pairs(t) do
		if type(v) ~= "boolean" then
			DebugWatch(k, string.format("%.1f", v))
		end
	end
end

---------------------------------

function downRaycast(origin, maxDist, ignoreVehicles, ignoreWater, radius, toIgnore)
	
	ignoreWater = ignoreWater or false
	maxDist = maxDist or (wbb[2] - waa[2])
	radius = radius or 0
	
	local dir = Vec(0, -1, 0)
	local hitPos = nil
	
	for i=1, #toIgnore do
		QueryRejectShape(toIgnore[i])
	end
	
	local hit, dist, normal, shape = QueryRaycast(origin, dir, maxDist, radius, false)
	if hit then
		hitPos = deepcopy(origin)
		hitPos[2] = hitPos[2] - dist
		if IsPointInWater(hitPos) and not ignoreWater then
			hit = false
		end
	end
	
	return hit, deepcopy(hitPos), shape, dist
end

function abRaycast(a, b, ignoreVehicles, radius)
	ignoreVehicles = ignoreVehicles or false
	radius = radius or 0
	
	local diff = VecSub(b, a)
	local dir = VecNormalize(diff)
	
	local hit, dist, normal, shape = QueryRaycast(a, dir, VecLength(diff), radius, false)
	
	return hit
end

function addPointToProcess(infParam, supParam, s)
	local inf = deepcopy(infParam)
	inf[2] = 0
	local sup = deepcopy(supParam)
	sup[2] = 0
	
	s = s or step
	
	local cursor = {}
	cursor.x = inf[1]
	cursor.z = inf[3]
	
	while cursor.x < sup[1] do
		while cursor.z < sup[3] do
			processInsert(cursor)
			cursor.z = cursor.z + s
		end
		cursor.x = cursor.x + s
		cursor.z = inf[3]
	end
end

function processInsert(v)
	v = deepcopy(v)
	process.points[#process.points + 1] = {}
	process.points[#process.points].x = v.x
	process.points[#process.points].z = v.z
end

function pathfinderDebugCross()
	for i=1, #points do
		if points[i].pf.color > 0 then
		local r = 0
		local g = 1
		local b = 0
		if points[i].pf.color == 1 then
			r = 1
			g = 0
		end
		DebugCross(points[i].pos, r, g, b, 1)
		end
	end
end

function processDebugCross()
	for i=1, #process.points do
		local r = 1
		local g = 0
		if i > process.i then
			r = 0
			g = 1
		end
		DebugCross(Vec(process.points[i].x, 0 , process.points[i].z), r, g, 0, 1)
	end
end

function pointsDebugCross()
	for i=1, #points do
		DebugCross(points[i].pos, 0, 0, 1, 1)
	end
end

function edgesDebugLine(notDebugLine, threshold)
	threshold = threshold or 0
	edgeCount = 0
	for i=1, #points do
		for j=1, #points[i].neighbors do
			if points[i].neighbors[j].x > points[i].pos[1] or points[i].neighbors[j].z > points[i].pos[3] then
				if points[i].neighbors[j].edge then
					--edgeCount = edgeCount + 1
					local npointIndex = nil
					if indexList[points[i].neighbors[j].x] ~= nil then
						if indexList[points[i].neighbors[j].x][points[i].neighbors[j].z] ~= nil then
							npointIndex = indexList[points[i].neighbors[j].x][points[i].neighbors[j].z][points[i].neighbors[j].stage]
						end
					end
					--DebugPrint(npointIndex)
					local npoint = points[npointIndex]
					if npoint ~= nil then
						local r = 0
						local g = 1
						local b = 0
						local alpha = 1
						local valid = true
						if #rg.colorMapping.region > 0 then
							local regionIndex = npoint.regionIndex
							r = rg.colorMapping.color[regionIndex][1]
							g = rg.colorMapping.color[regionIndex][2]
							b = rg.colorMapping.color[regionIndex][3]
							
							valid = false
							DebugPrint(regionIndex)
							DebugPrint(rg.colorMapping.size[regionIndex])
							if rg.colorMapping.size[regionIndex] > threshold then
								valid = true
							end
						end
						
						if valid then
							if notDebugLine then
								DrawLine(points[i].pos, npoint.pos, r, g, b, alpha)
							else
								DebugLine(points[i].pos, npoint.pos, r, g, b, alpha)
							end
						end
					end
				end
			end
		end
	end
end

function processPoint(batchSize, s)
	batchSize = batchSize or 1
	s = s or step
	for i=1, batchSize do
		local index = i + process.i
		if index > #process.points then
			process.points = {}
			process.i = 0
			process.edgesDone = false
			status = 2
			break
		end
		local addIndex = nil
		if indexList[process.points[index].x] ~= nil then
			addIndex = indexList[process.points[index].x][process.points[index].z]
			-- useful to refresh the list, but not working yet
		end
		if addIndex == nil then
			addIndex = #points + 1
			--DebugPrint(addIndex)
			--if indexList[deepcopy(process.points[index].x)] == nil then
				--indexList[deepcopy(process.points[index].x)] = {}
			--end
			--indexList[deepcopy(process.points[index].x)][deepcopy(process.points[index].z)] = addIndex
		end
		
		local hit = true
		local hitPos = nil
		local shapeHit = nil
		local toIgnore = {}
		local stage = 1
		local offset = 0
		local bonusOffset = s
		local dist = nil
		
		while hit and stage <= maxStage do
			hit, hitPos, shapeHit, dist = downRaycast(Vec(process.points[index].x, world.bb[2] - offset, process.points[index].z), world.bb[2] - world.aa[2] - offset, false, false, radiusSize, toIgnore)
			if hit then
				points[addIndex] = {}
				points[addIndex].pos = hitPos
				points[addIndex].height = hitPos[2]
				points[addIndex].rgDone = false
				points[addIndex].rgIndex = -1
				points[addIndex].color = rg.NO_COLOR
				points[addIndex].neighbors = addNeighbors(hitPos, s, connex8)
				--points[addIndex].pf = {}
				--points[addIndex].pf.color = 0
				--points[addIndex].pf.dist = {}
				
				if indexList[hitPos[1]] == nil then
					indexList[hitPos[1]] = {}
				end
				if indexList[hitPos[1]][hitPos[3]] == nil then
					indexList[hitPos[1]][hitPos[3]] = {}
				end
				indexList[hitPos[1]][hitPos[3]][stage] = addIndex
				
				stage = stage + 1
				
				toIgnore[#toIgnore + 1] = shapeHit
				
				--local minb = Vec(process.points[index].x - s / 2, world.aa[2], process.points[index].z - s / 2)
				local minb = Vec(process.points[index].x - s / 2, world.bb[2] - offset - s, process.points[index].z - s / 2)
				local maxb = Vec(process.points[index].x + s / 2, world.bb[2] - offset, process.points[index].z + s / 2)
				local allShapes = QueryAabbShapes(minb, maxb)
				for i=1, #allShapes do
					--if IsShapeTouching(shapeHit, allShapes[i]) then
						--local value = GetShapeMaterialAtPosition(allShapes[i], hitPos)
						--if value ~= "" then
							toIgnore[#toIgnore + 1] = allShapes[i]
						--end
					--end
				end
				
				offset = offset + dist + bonusOffset
				addIndex = addIndex + 1
			end
		end
	end
	process.i = process.i + batchSize
end

function addNeighbors(origin, s, diag)
	diag = diag or false
	s = s or step
	local flat = deepcopy(origin)
	flat[2] = 0
	
	local n = {}
	
	local offsets = {}
	offsets[#offsets + 1] = Vec(-s, 0, 0)
	offsets[#offsets + 1] = Vec(s, 0, 0)
	offsets[#offsets + 1] = Vec(0, 0, -s)
	offsets[#offsets + 1] = Vec(0, 0, s)
	if diag then
		offsets[#offsets + 1] = Vec(-s, 0, -s)
		offsets[#offsets + 1] = Vec(s, 0, -s)
		offsets[#offsets + 1] = Vec(-s, 0, s)
		offsets[#offsets + 1] = Vec(s, 0, s)
	end
	
	for i=1, #offsets do
		for j=1, maxStage do
			local pos = VecAdd(flat, offsets[i])
			n[#n + 1] = {}
			n[#n].x = pos[1]
			n[#n].z = pos[3]
			n[#n].stage = j
			n[#n].edge = false
		end
	end
	
	return deepcopy(n)
end

function processEdges(batchSize, s)
	batchSize = batchSize or 1
	s = s or step
	for i=1, batchSize do
		local index = i + process.i
		if index > #points then
			process.edgesDone = true
			status = 3
			rg.i = 1
			rg.toCompute = {}
			rg.colorCount = 0
			rg.lastBlank = 1
			rg.done = false
			rg.status = 1
			process.i = 0
			break
		end
		
		local neighbors = {}
		
		for j=1, #points[index].neighbors do
			--DebugPrint(points[i].neighbors[j].x .. " " .. points[i].neighbors[j].z)
			--if points[i].neighbors[j].x > points[i].pos[1] or points[i].neighbors[j].z > points[i].pos[3] then
				neighbors[#neighbors + 1] = points[index].neighbors[j]
			--end
		end
		local newNeighbors = {}
		for j=1, #neighbors do
			points[index].neighbors[j].edge = true
			local npointIndex = nil
			if indexList[points[index].neighbors[j].x] ~= nil then
				if indexList[points[index].neighbors[j].x][points[index].neighbors[j].z] ~= nil then
					npointIndex = indexList[points[index].neighbors[j].x][points[index].neighbors[j].z][points[index].neighbors[j].stage]
				end
			end
			local npoint = points[npointIndex]
			
			if npointIndex == nil then -- nil failure
				points[index].neighbors[j].edge = false
				
			elseif math.abs(npoint.height - points[index].height) / s > maxDeltaPerMeter then -- delta failure
				points[index].neighbors[j].edge = false
				
			elseif abRaycast(points[index].pos, npoint.pos, false, s / 2 - 0.2) then -- raycast failure
				points[index].neighbors[j].edge = false
				
			end
			if points[index].neighbors[j].edge then
				newNeighbors[#newNeighbors + 1] = points[index].neighbors[j]
			end
		end
		points[index].neighbors = deepcopy(newNeighbors)
	end
	process.i = process.i + batchSize
end

function regionGrowing(batchSize)
	threshold = threshold or 0 -- stricly >
	batchSize = batchSize or 1
	
	for i=1, batchSize do
		if rg.done then
			status = 4
			rg.status = 1
			rg.toCompute = {}
			break
		end
		
		if rg.status == 1 then -- assign colors
			local pointIndex = getNextGreyIndex()
			local point = points[pointIndex]
			if point == nil then
				for j=rg.lastBlank, #points do
					if points[j].color == rg.NO_COLOR then
						pointIndex = j
						point = points[j]
						rg.colorCount = rg.colorCount + 1
						point.color = rg.colorCount
						rg.processRegion[point.color] = {}
						rg.processRegion[point.color][#rg.processRegion[point.color] + 1] = j
						rg.lastBlank = j
						break
					end
				end
				if point == nil then
					rg.status = 2
					rg.i = 1
					break
				end
			end
			for j=1, #point.neighbors do
				local index = nil
				if indexList[point.neighbors[j].x] ~= nil then
					if indexList[point.neighbors[j].x][point.neighbors[j].z] ~= nil then
						index = indexList[point.neighbors[j].x][point.neighbors[j].z][point.neighbors[j].stage]
					end
				end
				if index ~= nil then
					local color = points[index].color
					if color ~= rg.NO_COLOR then
						point.color = color
						rg.processRegion[point.color][#rg.processRegion[point.color] + 1] = pointIndex
					else
						if not points[index].rgDone then
							points[index].rgDone = true
							rg.toCompute[#rg.toCompute + 1] = index
						end
					end
				end
			end
			
		elseif rg.status == 2 then -- merge regions
			if rg.i > #points then
				rg.status = 3
				break
			end
			for j=1, #points[rg.i].neighbors do
				if points[rg.i].neighbors[j].edge then
					local index = nil
					if indexList[points[rg.i].neighbors[j].x] ~= nil then
						if indexList[points[rg.i].neighbors[j].x][points[rg.i].neighbors[j].z] ~= nil then
							index = indexList[points[rg.i].neighbors[j].x][points[rg.i].neighbors[j].z][points[rg.i].neighbors[j].stage]
						end
					end
					if index ~= nil then
						if points[index].color ~= points[rg.i].color then
							convertColor(points[index].color, points[rg.i].color)
						end
					end
				end
			end
			rg.i = rg.i + 1
			
		elseif rg.status == 3 then -- get visual colors
			rg.colorMapping.region = {}
			rg.colorMapping.color = {}
			rg.colorMapping.size = {}
			local existRegion = {}
			local regionSize = {}
			local regionIndex = {}
			for j=1, #points do
				local exist = (existRegion[points[j].color] ~= nil)
				
				if not exist then
					existRegion[points[j].color] = true
					rg.colorMapping.region[#rg.colorMapping.region + 1] = points[j].color
					points[j].regionIndex = #rg.colorMapping.region
					regionSize[points[j].color] = 1
					regionIndex[points[j].color] = points[j].regionIndex
					rg.colorMapping.size[points[j].regionIndex] = 1
					rg.colorMapping.color[#rg.colorMapping.color + 1] = Vec(rand(100) / 100, rand(100) / 100, rand(100) / 100)
					
				else
					points[j].regionIndex = regionIndex[points[j].color]
					rg.colorMapping.size[points[j].regionIndex] = rg.colorMapping.size[points[j].regionIndex] + 1
					regionSize[points[j].color] = regionSize[points[j].color] + 1
				end
			end

			rg.status = 4
			rg.done = true
			initPathFinder()
			break
		end
	end
end

function getNextGreyIndex()
	rg.i = rg.i + 1
	return rg.toCompute[rg.i - 1]
end

function convertColor(oldColor, newColor)
	for i=1, #rg.processRegion[oldColor] do
		points[rg.processRegion[oldColor][i]].color = newColor
		rg.processRegion[newColor][#rg.processRegion[newColor] + 1] = rg.processRegion[oldColor][i]
	end
	rg.processRegion[oldColor] = {}
end

function initPathFinder(skipPointReset)
	skipPointReset = skipPointReset or false
	if skipPointReset == false then
		points.pf = {}
		points.pf.a = Vec(0, 0, 0)
		points.pf.b = Vec(0, 0, 0)
	end
	points.pf.queue = {}
	points.pf.path = {}
	points.pf.batchSize = 150
	points.pf.current = nil
	points.pf.first = true
end

function computePath(batchSize)
	if points.pf.first then
		points.pf.a = getClosestNodeIndex(points.pf.a)
		points.pf.b = getClosestNodeIndex(points.pf.b)
		if points[points.pf.a].color ~= points[points.pf.b].color then
			status = 6
			DebugWatch("Not the same region!", rand(100))
		end
		points.pf.first = false
		local returnVal = addInQueue(points.pf.a, nil)
		--DebugWatch("first", returnVal)
	end
	
	local complete = false
	for i=1, batchSize do
		points.pf.current = getNextIndexInQueue()
		if points.pf.current == points.pf.b or points.pf.current == nil then
			complete = true
			break
		else
			addNeighboursToQueue(points.pf.current)
		end
	end
	
	if complete then
		-- build the path table
		local cursor = points.pf.b
		while cursor ~= nil and cursor ~= points.pf.a do
			points.pf.path[#points.pf.path + 1] = cursor
			cursor = points[cursor].pf.previous
		end
		points.pf.path[#points.pf.path + 1] = cursor -- add the points.pf.a point
		status = 6
	end
end

function addInQueue(pointIndex, previousIndex)
	if points[pointIndex].pf.color == 0 then
		points[pointIndex].pf.color = 1
		points[pointIndex].pf.previous = previousIndex
		if previousIndex ~= nil then
			points[pointIndex].pf.dist.a = points[previousIndex].pf.dist.a + VecLength(VecSub(points[previousIndex].pos, points[pointIndex].pos))
		else
			points[pointIndex].pf.dist.a = 0
		end
		points[pointIndex].pf.dist.b = VecLength(VecSub(points[pointIndex].pos, points[points.pf.b].pos))
		points.pf.queue[#points.pf.queue + 1] = pointIndex
		--DebugWatch("color", points[pointIndex].pf.color)
		return true -- added
	end
	return false -- not added
end

function getClosestNodeIndex(inputVec)
	local p = deepcopy(inputVec)
	local bmu = {
		index = nil,
		dist = 0
	}
	p[1] = p[1] - (p[1] % step) + (world.aa[1] % step)
	p[3] = p[3] - (p[3] % step) + (world.aa[3] % step)

	for stage=1, #indexList[p[1]][p[3]] do
		if indexList[p[1]][p[3]][stage] ~= nil then
			local dist = VecLength(VecSub(points[indexList[p[1]][p[3]][stage]].pos, p))
			if bmu.index == nil or dist < bmu.dist then
				bmu.index = indexList[p[1]][p[3]][stage]
				bmu.dist = dist
			end
		end
	end
	return bmu.index
end

function getNextIndexInQueue()
	local bmu = {
		index = nil,
		dist = 0
	}
	
	local updatedQueue = {}
	
	--DebugWatch("size", #points.pf.queue)
	for i=1, #points.pf.queue do
		--local dist = VecLength(VecSub(points[points.pf.queue[i]].pos, points[points.pf.b].pos))
		local dist = points[points.pf.queue[i]].pf.dist.b
		if bmu.index == nil or dist < bmu.dist then
			if bmu.index ~= nil then
				updatedQueue[#updatedQueue + 1] = bmu.index
			end
			bmu.index = points.pf.queue[i]
			bmu.dist = dist
		else
			updatedQueue[#updatedQueue + 1] = points.pf.queue[i]
		end
	end
	--DebugWatch("index", bmu.index)
	if bmu.index ~= nil then
		points[bmu.index].pf.color = 2
	end
	points.pf.queue = deepcopy(updatedQueue)
	
	return bmu.index
end

function addNeighboursToQueue(current)
	for i=1, #points[current].neighbors do
		local index = indexList[points[current].neighbors[i].x][points[current].neighbors[i].z][points[current].neighbors[i].stage]
		if points[current].neighbors[i].edge then
			if points[index].pf.color == 0 then
				addInQueue(index, current)
			elseif points[index].pf.color == 1 and points[current].pf.dist.a < points[points[index].pf.previous].pf.dist.a then
				points[index].pf.previous = current
			end
		end
	end
end

function displayPath()
	for i=1, #points.pf.path - 1 do
		DrawLine(points[points.pf.path[i]].pos, points[points.pf.path[i + 1]].pos, 1, 1, 0, 1)
	end
end

function resetPathfinder()
	for i=1, #points do
		points[i].pf = {}
		points[i].pf.color = 0
		points[i].pf.dist = {}
	end
	initPathFinder(true)
end










































