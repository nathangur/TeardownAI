--Credit to Elboydo's old ai mod for some reference.


detectRange = 5--2.5--3

isAiActive = true

vehicle = {}

maxSpeed = 20

--initialPos = Vec(0,0,0) 
--generalPos = initialPos
generalPos = Vec(0,0,0)

gAmount = 1

testHeight = 1
drivePower = 3

detectPoints = {
	[1] = Vec(0,0,-detectRange),
	[2] = Vec(detectRange,0,-detectRange),
	[3] = Vec(-detectRange,0,-detectRange),
	[4] = Vec(-detectRange,0,0),
	[5] = Vec(detectRange,0,0),
	[6] = Vec(0,0,detectRange),

}

weights = {
	[1] = 0.85,
	[2] = 0.85,
	[3] = 0.85,
	[4] = 0.5,
	[5] = 0.5,
	[6] = 0.25,
}

ai = {

	commands = {
	[1] = Vec(0,0,-detectRange*4),
	[2] = Vec(detectRange*1.5,0,-detectRange*2.5),
	[3] = Vec(-detectRange*1.5,0,-detectRange*2.5),
	[4] = Vec(-detectRange,0,0),
	[5] = Vec(detectRange,0,0),
	[6] = Vec(0,0,detectRange),

	},

	weights = {
	[1] = 0.860,
	[2] = 0.85,
	[3] = 0.85,
	[4] = 0.8,
	[5] = 0.8,
	[6] = 0.7,
	},

	directions = {
		forward = Vec(0,0,1),

		back = Vec(0,0,-1),

		left = Vec(1,0,0),

		right = Vec(-1,0,0),
	},

	numScans = 7,
	scanThreshold = 0.5,

	--altChecks = Vec(0.25,0.4,-0.6),
	altChecks = {
				[1] = -2,
				[2] =0.2,
				[3] = 0.4
			},
	altWeight ={
			[1] = 1,
			[2] =1,
			[3] = -1,
			[4] = -1,
	},


	validSurfaceColours ={ 
			[1] = {
				r = 0.20,
				g = 0.20,
				b = 0.20,
				range = 0.05
			},
			[2] = {
				r = 0.34,
				g = 0.34,
				b = 0.34,
				range = 0.05
			},
			[3] = {
				r = 0.6,
				g = 0.6,
				b = 0.6,
				range = 0.05
			},
		}
}
targetMoves = {
	list = {},
	target = Vec(0,0,0),
	targetIndex = 1
}


scan = 0
scanCount = 5

hitColour = Vec(1,0,0)
detectColour = Vec(1,1,0)
clearColour = Vec(0,1,0)

aiStarted = nil
aiNodes = 1
currentNode = nil

reset = 1
resetTimer = reset 

function init()

	for i=1,10 do 
		targetMoves.list[i] = Vec(0,0,0)
	end

	for i = 1,#ai.commands*1 do 
		detectPoints[i] = deepcopy(ai.commands[(i%#ai.commands)+1])
		if(i> #ai.commands) then
			detectPoints[i] = VecScale(detectPoints[i],0.5)
			detectPoints[i][2] = ai.altChecks[2]

		else 
			detectPoints[i][2] = ai.altChecks[1]
		end
		weights[i] = ai.weights[(i%#ai.commands)+1]--*ai.altWeight[math.floor(i/#ai.commands)+1]

	end

	vehicleLoc = FindLocation("vehicleLoc")
	vlTransform = GetLocationTransform(vehicleLoc)
	vlpos = vlTransform.pos

	vehicle.id = FindVehicle("aicar")
	local carTransform = GetVehicleTransform(vehicle.id)
	localPos = TransformToLocalPoint(carTransform, vlpos)

	nodeloc = FindLocation("node")
	--nodes = GetLocationTransform(nodeLoc).pos --nodePos aka the location of the node
	--local value = GetTagValue(vehicle.id, "aicar")
	nodes = nodeloc

	for key,value in ipairs(nodes) do
		if(tonumber(GetTagValue(value, "node"))==aiNodes) then 
			currentNode = value
		end
	end

end

function tick(dt)
	vehicleTransform = GetVehicleTransform(vehicle.id)
	worldPos = TransformToParentPoint(vehicleTransform, localPos)
	DebugCross(worldPos)

	hit, point, normal, shape = QueryClosestPoint(GetCameraTransform().pos, 10)
	if hit then
		local mat,r,g,b = GetShapeMaterialAtPosition(shape, point)
		--DebugWatch("Raycast hit voxel made out of ", mat.." | r:"..r.."g:"..g.."b:"..b)
	end

	markLoc()

	ripUpdate()

end

--make a function that will get the variable location.a from main_road_detection_AI.lua and set that to 



function markLoc()
	if GetTime() <= 5 then
		initialPos = nodes --Remember! Nodes is the global get location transform
		generalPos = VecAdd(initialPos,Vec(math.random(-0,0),0,math.random(-0,0)))
	end

	if(VecLength(generalPos)~= 0) then 
		DebugWatch("generalPos",VecLength(generalPos))
		SpawnParticle("fire", generalPos, Vec(0,5,0), 0.5, 1)
	end
	if(aiStarted) then 
		vecFind = Vec(1, 1 ,1)
		if nodes and worldPos <= vecFind then
			aiNodes = (aiNodes%#nodes)+1
			for key,value in ipairs(aiNodes) do 
				
				if(tonumber(GetTagValue(value, "node"))==aiNodes) then 
					currentNode = value
					initialPos = GetLocationTransform(currentNode).pos

					generalPos = VecAdd(initialPos,Vec(math.random(-0,0),0,math.random(-0,0)))
				end
			end

		end
		DebugWatch("node1: ",aiNodes)
		DebugWatch("node2: ",currentNode)
		DebugWatch('initialPos',initialPos)
		DebugWatch("generalPos",VecLength(generalPos))
		SpawnParticle("fire", generalPos, Vec(0,5,0), 0.5, 1)
	end

	if(isAiActive and (GetVehicleHealth(vehicle.id)<0.1 or  IsPointInWater(GetVehicleTransform(vehicle.id).pos))) then
		isAiActive = false
	end
end

function update(dt)
end

function ripUpdate()
	if(isAiActive) then 
		targetAmount = vehicleDetection()
		DebugWatch("targetAmount:",VecStr(targetAmount.target ))

		targetAmount.target = MAV(targetAmount.target)

		controlVehicle(targetAmount)
	end

	 if(aiStarted and isAiActive and VecLength(GetBodyVelocity(GetVehicleBody(vehicle.id)))<1) then
	 	resetTimer = resetTimer
	 	if(resetTimer <=0 )then
	 		local lastNode = aiNodes-1
			if(lastNode<=0) then
				lastNode = 1
			end
				
			for key,value in ipairs(nodes) do 
				
				if(tonumber(GetTagValue(value, "node"))== lastNode) then 
					local resetLocation = GetLocationTransform(value)
					resetLocation.pos = VecAdd(resetLocation.pos,Vec(math.random(-0,0),0,math.random(-0,0)))   
					--SetBodyTransform(GetVehicleBody(vehicle.id),resetLocation)
					resetTimer = reset
				end
			end
	 		

	 	end
	 elseif aiStarted and isAiActive and   resetTimer<reset then
	 	resetTimer = reset
	 end

	DebugWatch("Vehicle ",vehicle.id)


	DebugWatch("velocity:", VecLength(GetBodyVelocity(GetVehicleBody(vehicle.id))))
end

function scanPos(detect,boundsSize)

	QueryRejectVehicle(vehicle.id)
    local fwdPos = TransformToParentPoint(vehicleTransform,detect)
    local direction = VecSub(fwdPos,vehicleTransform.pos)
    hit,dist,normal, shape = QueryRaycast(vehicleTransform.pos, direction, VecLength(direction)*.5,boundsSize[1]*.1)
    
    if hit then
		local hitPoint = VecAdd(vehicleTransform.pos, VecScale(direction, dist))
		local mat = GetShapeMaterialAtPosition(shape, hitPoint)
		DebugPrint("Raycast hit voxel made out of " .. mat)
    end

	return hit,dist,normal, shape

end

function amountFunc2(testPos,hit,dist,shape,key)
	local amount = 10000 
	if(not hit) then 
		amount = VecLength(VecSub(testPos,generalPos))*(1-weights[key])
	end
	return amount
end

function vehicleDetection()

	local vehicleBody = GetVehicleBody(vehicle.id)
	local vehicleTransform = GetVehicleTransform(vehicle.id)
	local min,max = GetBodyBounds(vehicleBody)
	vehicleTransform.pos = TransformToParentPoint(vehicleTransform,Vec(0,testHeight,0))
	local vehicleTransformOrig = TransformCopy(vehicleTransform) 
	local fwd = TransformToParentPoint(vehicleTransform,Vec(0,0,-detectRange*1.5))
	local fwdL = TransformToParentPoint(vehicleTransform,Vec(detectRange,0,-detectRange))
	local fwdR = TransformToParentPoint(vehicleTransform,Vec(-detectRange,0,-detectRange))
	local boundsSize = VecSub(max, min)
	--DebugWatch("min",VecStr(min))

	--DebugWatch("max",VecStr(max))
	--DebugWatch("boundsize",boundsSize)
	amounts = { }
	bestAmount = {key = 0, val = 1000, target = Vec(0,0,0)}

	if(VecLength(generalPos)> 0.5 and VecLength(VecSub(GetVehicleTransform(vehicle.id).pos,generalPos))>1) then	
		for key,detect in ipairs(detectPoints) do 
			--vehicleTransform = GetVehicleTransform(vehicle.id)
			vehicleTransform.pos = TransformToParentPoint(vehicleTransform,Vec(0,testHeight*.25,0))
			if(detect[3] <0) then
				vehicleTransform.pos = TransformToParentPoint(vehicleTransform,Vec(0,0,-boundsSize[3]*.50))
			elseif(detect[3] >0) then
				vehicleTransform.pos = TransformToParentPoint(vehicleTransform,Vec(0,0,boundsSize[3]*.50))
			end
			if(detect[1] <0) then
				vehicleTransform.pos = TransformToParentPoint(vehicleTransform,Vec(-boundsSize[1]*.25),0,0)
			elseif(detect[1] >0) then
				vehicleTransform.pos = TransformToParentPoint(vehicleTransform,Vec(boundsSize[1]*.25),0,0)
			end
			-- QueryRejectVehicle(vehicle.id)
		    local fwdPos = TransformToParentPoint(vehicleTransform,detect)
		    local direction = VecNormalize(VecSub(fwdPos,vehicleTransform.pos))
		    QueryRejectVehicle(vehicle.id)
		    QueryRequire("physical static large")
		    DebugWatch("direction",direction)
		    DebugWatch("length", VecLength(direction)*2)
		    local hit,dist,normal, shape = QueryRaycast(vehicleTransform.pos, direction, VecLength(detect))
		    local lineColour = detectColour
		    local amountModifider = 5

		    if hit then
				local hitPoint = VecAdd(vehicleTransform.pos, VecScale(direction, dist))
				local mat,r,g,b  = GetShapeMaterialAtPosition(shape, hitPoint)
				if(mat =="masonry") then
					for colKey, validSurfaceColours in ipairs(ai.validSurfaceColours) do 
						
						local validRange = validSurfaceColours.range
						DebugPrint((validSurfaceColours.r-validRange.." | "..validSurfaceColours.r+validRange.." | "..r))
						if(inRange(validSurfaceColours.r-validRange,validSurfaceColours.r+validRange,r)
						 and inRange(validSurfaceColours.g-validRange,validSurfaceColours.g+validRange,g) 
						 and inRange(validSurfaceColours.b-validRange,validSurfaceColours.b+validRange,b)) then 
							hit = false
							lineColour = clearColour
							amountModifider = 1
						end
					end
				else
					DebugPrint("Raycast hit voxel made out of " .. mat)
				end
		    end		   
			
		    amounts[key] = amountFunc2(TransformToParentPoint(vehicleTransform,detect),hit,dist,shape,key)
		    amounts[key] = amounts[key] * amountModifider

		    DebugWatch("amounts: "..key,amounts[key].." | "..VecStr(detect))
		    if hit then
		    	lineColour = hitColour
		    else
			    if amounts[key] < bestAmount.val  then
			    	bestAmount.key = key
			    	bestAmount.val = amounts[key] 
			    	bestAmount.target = detect
			    end
		    end
		    DebugLine(vehicleTransform.pos, fwdPos, lineColour[1], lineColour[2], lineColour[3])

		end
	end
	DebugLine(vehicleTransform.pos, fwd, 1, 0, 0)
	DebugLine(vehicleTransform.pos, fwdL, 1, 0, 0)
	DebugLine(vehicleTransform.pos, fwdR, 1, 0, 0)
	return bestAmount
end

function MAV(targetAmount)
	targetMoves.targetIndex = (targetMoves.targetIndex%#targetMoves.list)+1 
	targetMoves.target = VecSub(targetMoves.target,targetMoves.list[targetMoves.targetIndex])
	targetMoves.target = VecAdd(targetMoves.target,targetAmount)
	targetMoves.list[targetMoves.targetIndex] = targetAmount
	return VecScale(targetMoves.target,(#targetMoves.list/100))

end

function controlVehicle( targetCost)
	local hBrake = false
	if(VecLength(goalPos)> 0.5) then
		local targetMove = VecNormalize(targetCost.target)

		if(VecLength(VecSub(GetVehicleTransform(vehicle.id).pos,goalPos))>2) then
			--DebugWatch("pre updated",VecStr(targetMove))
			if(targetMove[1] ~= 0 and targetMove[3] ==0) then 
				targetMove[3] = 1
				targetMove[1] = -targetMove[1]
			end
			if(targetMove[1]~= 0) then
				targetMove[3] = targetMove[3]*0.8
				targetMove[1] = targetMove[1] * 3
			end 

			DriveVehicle(vehicle.id, -targetMove[3]*drivePower,-targetMove[1], hBrake)
			--DebugWatch("post updated",VecStr(targetMove))
			--DebugWatch("motion2",VecStr(detectPoints[targetCost.key]))
		else 
			DriveVehicle(vehicle.id, 0,0, true)
		end
	end
end

function amountFunc(testPos,hit,key)
	local amount = 10000 
	if(not hit) then 
		amount = VecLength(VecSub(testPos,generalPos))*(1-weights[key])
	end
	return amount
end

function vehicleMovement(vel,angVel)
	local vehicleTransform = GetBodyTransform(vehicle.body)
	local targetVel = 	TransformToParentPoint(vehicleTransform,vel)
	targetVelocity = VecSub(targetVel, vehicleTransform)
	local targetAngVel = angVel---TransformToParentPoint(vehicleTransform,angVel)
	local currentVel = GetBodyVelocity(vehicle.body)
	local currentAngVel = GetBodyAngularVelocity(vehicle.body)

	if(VecLength(currentVel)<maxSpeed) then
		SetBodyVelocity(vehicle.body,VecAdd(currentVel,targetVelocity))
	end
	SetBodyAngularVelocity(vehicle.body, VecAdd(currentAngVel,targetAngVel))

end

function clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end -- swap if boundaries supplied the wrong way
    return math.max(lower, math.min(upper, val))
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

function inRange(min,max,value)
		if(min < value and value<=max) then 
			return true
		else
			return false
		end
end