

--AStarSearch


--[[

* DESCRIPTION :
*       Implements A Star search in Teardown 2020
*
]]

AStar = {
    maxChecks = 1000,
    cameFrom = {},
    costSoFar = {},
    maxIterations = 10,
    currentIteration = 0,

    heuristicWeight = 1

}





function AStar:Heuristic(a, b)
      return (math.abs(a[1] - b[1]) + math.abs(a[2] - b[2])) * self.heuristicWeight
 end 



function AStar:AStarSearch(graph, start, goal)
    
        frontier =  deepcopy(PriorityQueue)
        frontier:init(#graph,#graph[1])
        frontier:put(deepcopy(start), 0);

        local startIndex = start:getIndex()
        -- DebugPrint(type(start:getIndex()).." | "..type(start:getIndex()[2]))
        -- DebugPrint("Val = " ..startIndex[1]..startIndex[2])
        local cameFrom = {}
        cameFrom[startIndex[2]] = {}
        cameFrom[startIndex[2]][startIndex[1]] = start;
        local lastIndex = nil
        local costSoFar = {}
        costSoFar[startIndex[2]] = {}
        costSoFar[startIndex[2]][startIndex[1]] = start:getCost();

        local current = nil
        local currentIndex = nil
        local nextNode = nil
        local newCost = 0
        local priority = 0
        local currentIndex = nil
        local nodeExists = false

        local totalNodes = 0
        -- DebugPrint(frontier:empty())
        -- for i=1,self.maxChecks do 
        local checks = 0
        for i=1,frontier:size() do 
       --- while not frontier:empty() do
            checks = checks + 1
        
            current = deepcopy(frontier:get()) 

            totalNodes = totalNodes + 1
            if (type(current)~="table" or not current or  current:Equals(goal)) then
                -- DebugPrint("goal found")
                break
            end  
            currentIndex = current:getIndex()
             for key, val in ipairs(current:getNeighbors()) do
                    nextNode =  deepcopy(graph[val.y][val.x])
                
                    newCost = costSoFar[currentIndex[2]][currentIndex[1]] + nextNode:getCost()
                    nodeExists = ( self:nodeExists(costSoFar,val.y,val.x) )
                    if(nextNode.validTerrain and( not nodeExists or (not (cameFrom[currentIndex[2]][currentIndex[1]]:indexEquals({val.y,val.x}))  and 
                                        newCost < costSoFar[val.y][val.x])) )
                    then 
                        if(not nodeExists) then 
                            if(not costSoFar[val.y]) then 
                                costSoFar[val.y] = {}
                                cameFrom[val.y] = {}
                            end
                        end
                        costSoFar[val.y][val.x] = newCost
                        priority =   newCost +  self:Heuristic(nextNode:getIndex(),goal:getIndex())
                        frontier:put(nextNode, priority)
                        cameFrom[val.y][val.x] = deepcopy(current)

                        -- DebugPrint(newCost.." | "..val.y.." | "..val.x.." | ")
                        -- lastIndex = deepcopy(val)
                        
                        -- DebugPrint(nextNode:getIndex()[1].." | "..nextNode:getIndex()[2])
                    --+ graph.Cost(current, next);
                    end
             end
         end
         -- DebugPrint("total checks = "..checks)
         
         local path = self:reconstructPath(graph,cameFrom,current,start,totalNodes)
         -- DebugPrint("total nodes: "..totalNodes)
         return path
 end

 function AStar:nodeExists(listVar,y,x)
     if(listVar[y] and listVar[y][x]) then
        return true
    else
        return false
    end
 end

function AStar:reconstructPath(graph,cameFrom,current,start,totalNodes)
    local path = {}
    local index = current:getIndex()
    -- for i=1,100 do 
    while not current:Equals(start) do
    -- DebugPrint("came from: "..index[1].." | "..index[2])
        path[#path+1] = index
        index = cameFrom[current:getIndex()[2]][current:getIndex()[1]]:getIndex()
        current = deepcopy(graph[index[2]][index[1]])
        
        if(current:Equals(start)) then
                -- DebugPrint("found, nodes: "..totalNodes) 

            break

        end


    end
    local tmp = {}
    for i = #path, 1, -1 do
        tmp[#tmp+1] = path[i]
    end
    path = tmp
    return path


end


 function AStar:drawPath(graph,path)
    local node1,node2 = nil,nil
    for i = 1, #path-1 do
        node1 = graph[path[i][2]][path[i][1]]:getPos()
        node2 = graph[path[i+1][2]][path[i+1][1]]:getPos()
        DebugLine(node1,node2, 1, 0, 0)
    end
 end

 function AStar:drawPath2(graph,path,colours)
    local node1,node2 = nil,nil

    for i = 1, #path-1 do
        node1 = graph[path[i][2]][path[i][1]]:getPos()
        node2 = graph[path[i+1][2]][path[i+1][1]]:getPos()
        DebugLine(node1,node2, 1,0,0)
    end
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

--AI 



--[[
         
*
* DESCRIPTION :
*       File that implements racing AI inside teardown 2020, with PID controllers
* 		to ensure cars respond to coordinates in a good fashion and can handle high speed
*		Also includes simple goal achievement and collision avoidance 
*		Including "driver ai" to make them more / less aggressive with speed, cornering
*		overtaking, and driving. 

]]

raceMap = GetStringParam("map", "teardownRacing")



RACESTARTED = false

RACECOUNTDOWN = false

RACEENDED = false


PLAYER_TOTALED = false

PATHSET = false

mapInitialized = false

PLAYERRACING = true
	
DEBUG = false
DEBUGCARS = false

DEBUG_SAE = false


STOPTHEMUSIC = true


DEBUGCONTROLLERS = false

DEFAULTRACETIME = 1000000

map = {

  xIndex = 0,
  data = {

  },
  smoothingFactor = 3,
  validMaterials = {
  	[1] = {	
  		material = "masonry",


	  validSurfaceColours ={ 
				[1] = {
					r = 0.20,
					g = 0.20,
					b = 0.20,
					range = 0.02
				},
				[2] = {
					r = 0.80,
					g = 0.60,
					b = 0.60,
					range = 0.02
				},
				[3] = {
					r = 0.34,
					g = 0.34,
					b = 0.34,
					range = 0.02
				},
			},
		},
	},
}

-- negative grid pos is solved by simply showing 
mapSize = {
			x=400,
			y=400,
			grid = 6,
      gridHeight = 3,
      gridResolution = 1,
      gridThres      = 0.6,

      scanHeight = 100,

      scanLength = 200,

      weights = {
          goodTerrain = 0.1,
          badTerrain   = 10,
          avoidTerrain = 25,
          impassableTerrain = 50,
      }
		}
    path = nil


--- AI LINKED



RACESTARTED  = false

aiVehicles = {



	}

playerConfig = {
	name = "PLAYER ",
	finished = false,
	car = 0,
	bestLap = 0,
	playerLaps = 0,

	hudInfo = {
		lapInfo = {
			[1] = {
				name = "Race",
				time = 0,
			},

			[2] = {
				name = "Lap",
				time = 0,
			},

			[3] = {
				name = "Best",
				time = 0,
			},
		},
	},
}


aiPresets = {
	
	EASY = 1,
	MEDIUM = 2,
	HARD = 3,
	INSANE = 4,	
	DGAF = 5,
	ROADRAGE = 6,

	difficulties = {
		[1] = {
			name =  "easy", 
			steeringThres = 0.1,
			speedSteeringThres = 0.1, 
			tenacity = 0.7,
			errorCoef = 0.4,

		}, 
		[2] = {
			name =  "medium", 
			steeringThres = 0.2,
			speedSteeringThres = 0.2, 
			tenacity = 0.8,
			errorCoef = 0.2,

		}, 
		[3] = {
			name =  "hard", 
			steeringThres = 0.4,
			speedSteeringThres = 0.4, 
			tenacity = 0.9,
			errorCoef = 0.1,

		}, 
		[4] = {
			name =  "insane", 
			steeringThres = 0.6,
			speedSteeringThres = 0.6, 
			tenacity = 0.94,
			errorCoef = 0.05,

		}, 
		[5] = {
			name =  "DGAF", 
			steeringThres = 0.9,
			speedSteeringThres = 0.9, 
			tenacity = 0.99,
			errorCoef = 0.1,

		}, 
		[6] = {
			name =  "road rage", 
			steeringThres = 1,
			speedSteeringThres = 0.2, 
			tenacity = 1.1,
			errorCoef = 0.1,

		}, 
		[7] = {
			name =  "Never Overtakes - gentle", 
			steeringThres = 0.1,
			speedSteeringThres = 0.25, 
			tenacity = 0.85,
			errorCoef = 0.1,

		}, 
		[8] = {
			name =  "Never Overtakes - speedDemon", 
			steeringThres = 0.1,
			speedSteeringThres = 0.9, 
			tenacity = 0.85,
			errorCoef = 0.1,

		}, 
		[9] = {
			name =  "Medium corners, overtakes", 
			steeringThres = 0.95,
			speedSteeringThres = 0.5, 
			tenacity = 0.9,
			errorCoef = 0.1,

		}, 

		[10] = {
			name =  "slower corners, overtakes", 
			steeringThres = 0.7,
			speedSteeringThres = 0.35, 
			tenacity = 0.9,
			errorCoef = 0.1,

		}, 

	}


}


ai = {
	active = true,
	goalPos= Vec(0,0,0),



	raceValues = {
		completedGoals  = 0,
		targetNode 		= 1,
		NextNode 		= 2,
		passedCheckPoints = 0,
		nextCheckpoint = 1,
		completionRange = 4.5,--4.5,
		lookAhead = 2,
		laps = 0 	,
		lastLap = 0,
		splits = {},

		bestLap = nil,

	},

	targetNode = nil,
	NextNode =nil,

	controller = {
		aiType = "default",

		accelerationValue = 0,
		steeringValue = 0,
		handbrake = false,

		steeringThres  = aiPresets.HARD, --0.4
		steeringForce  = 0.5,
		speedSteeringThres = aiPresets.HARD,
		tenacity 			= 0.9,
		relativeThreshold = 0.8,
		minDist = 2--.5,--5,
	},

	reversingController = {
		reversing = false,
		minVelocity = 1,
		waitTime = 2.5,
		currentWait = 3,
		reverseTime = 2.5,
		currentReverseTime = 2.5,
	},


	detectRange = 3,
	commands = {
	[1] = Vec(0,0,-1),
	[2] = Vec(1*0.8,0,-1*1.5),
	[3] = Vec(-1*0.8,0,-1*1.5),
	[4] = Vec(-1,0,0),
	[5] = Vec(1,0,0),
	[6] = Vec(0,0,1),

	},

	weights = {

	[1] = 0.870,
	[2] = 0.86,
	[3] = 0.86,
	[4] = 0.84,
	[5] = 0.84,
	[6] = 0.80,

			} ,

	targetMoves = {
		list        = {},
		target      = Vec(0,0,0),
		targetIndex = 1
	},


	directions = {
		forward = Vec(0,0,1),

		back = Vec(0,0,-1),

		left = Vec(1,0,0),

		right = Vec(-1,0,0),
	},

	maxVelocity = 0,

	cornerCoef = 16,

	accelerationCoef = 0.75,
	steeringCoef = 2.55,

	pidState = {

			--- pid gain params
		pGain = 0.765,
		iGain = -0.08,
		dGain = -1.3,

		intergralTime = 5,

		integralIndex = 1,
		integralSum = 0,
		integralData = {

		},
		lastCrossTrackError = 0,
		lastPnt = Vec(0,0,0),

			-- pid output value 
		controllerValue = 0,


			--- pid update and training params
			training = false,
		inputrate=0.0665,
		learningrateweights=0.009,
		learningrateThres = 0.02,
	    bestrate=0.05,
	    secondbestrate=0.01,
	    gammasyn=0.9,
	    gammaref=0.7,
	    gammapsp=0.9,
	},
	usingClustering = false,

	clustering = {
		pass = 1,
		maxPass = 10,
		centroids = 2,
		iterations = 5,
		prior = 1,
		dataSize = 100,
		mode = -1,
		previousOutput = -1,
		output = nil,
		clusters = {
			centroids = {
				pass = 1,
				index = 1,
				data = {},
			},
			current = {
				pass = 1,
				index = 1,
				data = {},


			},
			prior = {
				pass = 1,
				index = 1,
				data = {},


			},
		},

	},

	scanning = {
		numScans = 2,
		scanThreshold = 0.5,
		maxScanLength = 10,
		scanLength = 50,
		scanDepths = 2,
		vehicleHeight = 2,
		cones = {
			left   = {
				direction = "left",
				startVec = Vec(0.25,0,-1.5),
				size = 110,
				scanColour = {
					r = 1,
					g = 1, 
					b = 0,
				},
				weight = 0.5

			},
			centre = {
				direction = "centre",
				startVec = Vec(0,0,-1),
				size = 0.5,
				scanColour = {
					r = 0,
					g = 0, 
					b = 1,
				},
				weight = 0.6

			},
			right  = {
				direction = "right",
				size = 110,
				startVec = Vec(-0.25,0,-1.5),
				scanColour = {
					r = 0,
					g = 1, 
					b = 0,
				},
				weight = 0.5

			},
		},
		positions = {
			left   = {
				direction = "left",
				startVec = Vec(0.25,0,-1.5),
				size = 110,
				scanColour = {
					r = 1,
					g = 1, 
					b = 0,
				},
				weight = 0.5

			},
			sideL  = {
				direction = "sideL",
				size = 110,
				startVec = Vec(1.25,0,-1.5),
				scanColour = {
					r = 0,
					g = 1, 
					b = 0,
				},
				weight = 0.5

			},
			centre = {
				direction = "centre",
				startVec = Vec(0,0,-1),
				size = 0.5,
				scanColour = {
					r = 0,
					g = 0, 
					b = 1,
				},
				weight = 0.6

			},
			right  = {
				direction = "right",
				size = 110,
				startVec = Vec(-0.25,0,-1.5),
				scanColour = {
					r = 0,
					g = 1, 
					b = 0,
				},
				weight = 0.5

			},
			sideR  = {
				direction = "sideR",
				size = 110,
				startVec = Vec(-1.25,0,-1.5),
				scanColour = {
					r = 0,
					g = 1, 
					b = 0,
				},
				weight = 0.5

			},
		},

	},



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
				range = 0.02
			},
			[2] = {
				r = 0.60,
				g = 0.60,
				b = 0.60,
				range = 0.02
			},
			[3] = {
				r = 0.34,
				g = 0.34,
				b = 0.34,
				range = 0.02
			},
		},
	hitColour = Vec(1,0,0),
	detectColour = Vec(1,1,0),
	clearColour = Vec(0,1,0),
}



function init()


	----------- stuff from drive 2 drive_to_survive
	sndConfirm = LoadSound("MOD/sounds/confirm.ogg")
	sndReject = LoadSound("MOD/sounds/reject.ogg")
	sndWarning = LoadSound("MOD/sounds/warning-beep.ogg")
	sndPickup = LoadSound("MOD/sounds/pickup.ogg")
	sndRocket = LoadLoop("MOD/sounds/rocket.ogg")
	sndFail = LoadSound("MOD/sounds/fail.ogg")
	sndWin = LoadSound("MOD/sounds/win.ogg")
	sndReady = LoadSound("MOD/sounds/ready.ogg")
	sndStart = LoadSound("MOD/sounds/start.ogg")

	--------------


	--initMap()

  	-- local smoothingSum = {0,0}
  	-- for i = 1,#path do
  	-- 	smoothingSum = {0,0}
  	-- 	for j = -1,1,1 do 
  	-- 		if(i+j <=0) then
  	-- 			smoothingSum[1] = smoothingSum[1]+path[#path+j][1] 
  	-- 			smoothingSum[2] = smoothingSum[2]+path[#path+j][2]
  	-- 		elseif(i+j >#path) then
  	-- 			smoothingSum[1] = smoothingSum[1]+path[(i+j)-#path][1] 
  	-- 			smoothingSum[2] = smoothingSum[2]+path[(i+j)-#path][2]
  	-- 		else
  	-- 			smoothingSum[1] = smoothingSum[1]+path[i+j][1] 
  	-- 			smoothingSum[2] = smoothingSum[2]+path[i+j][2]
  	-- 		end
	  -- 	end
	  -- 	path[i][1] = math.floor(smoothingSum[1]/map.smoothingFactor)
	  -- 	path[i][2] = math.floor(smoothingSum[2]/map.smoothingFactor)
  	-- end
  	
	-- for i = 1,#ai.commands*1 do 
	-- 	detectPoints[i] = deepcopy(ai.commands[(i%#ai.commands)+1])
	-- 	if(i> #ai.commands) then
	-- 		detectPoints[i] = VecScale(detectPoints[i],0.5)
	-- 		detectPoints[i][2] = ai.altChecks[2]


	-- 	else 
	-- 		detectPoints[i][2] = ai.altChecks[1]
	-- 	end
	-- 	weights[i] = ai.weights[(i%#ai.commands)+1]--*ai.altWeight[math.floor(i/#ai.commands)+1]

	-- end

	checkpoints = FindTriggers("checkpoint",true)

	for i = 1,#checkpoints do 
		if(GetTagValue(value, "checkpoint")=="") then 
			SetTag(checkpoints[i],"checkpoint",i)
		end

	end

	vehicles = FindVehicles("cfg",true)


	--[[

	set custom name info for trackDescriptions 

	also grab fastest time for that track 

	]]


	playerState = FindLocation("player",true) 

	if(IsHandleValid(playerState)and GetTagValue(playerState,"player")=="true") then
		if(DEBUG) then 
			DebugPrint("player in race")
		end
		PLAYERRACING = true
	else
		if(DEBUG) then
			DebugPrint("player not in race")
		end
		PLAYERRACING = false
	end

	--- set custom track values
	if(trackDescriptions[raceMap]) then
		map.validMaterials = deepcopy(trackDescriptions[raceMap].validMaterials)
		map.name = trackDescriptions[raceMap].name
		map.lines = deepcopy(trackDescriptions[raceMap].lines)
		raceManager.laps = trackDescriptions[raceMap].trackLaps
		if(trackDescriptions[raceMap].grid ) then
			mapSize.grid =  trackDescriptions[raceMap].grid
		end
		if(trackDescriptions[raceMap].grid ) then
			ai.raceValues.completionRange =  trackDescriptions[raceMap].grid
		end
		if(trackDescriptions[raceMap].completionRange ) then
			ai.raceValues.completionRange =  trackDescriptions[raceMap].completionRange 
		end
	else
		raceMap = "teardownRacing"

		map.validMaterials = deepcopy(trackDescriptions[raceMap].validMaterials)
		map.name = trackDescriptions[raceMap].name
		map.lines = deepcopy(trackDescriptions[raceMap].lines)
		raceManager.laps = trackDescriptions[raceMap].trackLaps
	end


	 initMapArr()

	roundCar = FindLocation("trackinfo",true)

	if(PLAYERRACING and roundCar) then

		if roundCar and HasKey("savegame.mod.besttime."..raceMap.."." .. GetTagValue(roundCar,"trackinfo")) then
			firstRoundWithCar = false
			savedBest = GetFloat("savegame.mod.besttime."..raceMap.."." .. GetTagValue(roundCar,"trackinfo"))
		else
			firstRoundWithCar = true
			savedBest = DEFAULTRACETIME
		end


	end

	--DebugPrint("saved best: "..savedBest.." roundcar: "..roundCar)
	-- savedBest = DEFAULTRACETIME
	--DebugPrint("saved best: "..savedBest.." roundcar: "..roundCar)

	--[[
	
	prepare ai vehicles

	]]

	for key,vehicle in pairs(vehicles) do 
		local value = GetTagValue(vehicle, "cfg")
		if(value == "ai") then
			local index = #aiVehicles+1
			aiVehicles[index] = deepcopy(ai)
			aiVehicles[index]:initVehicle(vehicle) 


		end
	end

	if(PLAYERRACING) then
		playerConfig.car = math.random(1,#aiVehicles)
		aiVehicles[playerConfig.car].playerName = playerConfig.name
		SetPlayerVehicle(aiVehicles[playerConfig.car].id)
	end



	-- DebugPrint("started")

end



function initPlayer()
	if roundCar and HasKey("savegame.mod.besttime.car" .. roundCar) then
		firstRoundWithCar = false
		savedBest = GetFloat("savegame.mod.besttime.car" .. roundCar)
	else
		firstRoundWithCar = true
		savedBest = 0
	end

end


function initMapArr()
	for y= -mapSize.y/2,mapSize.y/2,mapSize.grid do
	    pos = posToInt(Vec(0,0,y))
	    map.data[pos[3]] = {}
	    for x= -mapSize.x,mapSize.x/2,mapSize.grid do
	        pos = posToInt(Vec(x,0,y))
	        map.data[pos[3]][pos[1]] = nil 
	    end
	end
end

function initMap( )
local pos = Vec(0,0,0)
  local gridCost = 0
  local maxVal  = {math.modf((mapSize.x)/mapSize.grid),math.modf((mapSize.y)/mapSize.grid)}

	for y= -mapSize.y/2,mapSize.y/2,mapSize.grid do
    pos = posToInt(Vec(0,0,y))
    -- map.data[pos[3]] = {}
	    for x= -mapSize.x,mapSize.x/2,mapSize.grid do
	        pos = posToInt(Vec(x,0,y))
	        gridCost,validTerrain,avgHeight =  scanGrid(x,y) 
	        -- if(pos[3] ~= nil and pos[1]~= nil) then
	          
	          map.data[pos[3]][pos[1]] = deepcopy(mapNode) 
	          map.data[pos[3]][pos[1]]:push(x,avgHeight,y,gridCost,pos[3],pos[1],validTerrain,maxVal )

	        -- end
	  		  -- DebugPrint(x.." | "..y)
	    end
	end


	mapInitialized = true
	

end


function initPaths()

  pos = posToInt(GetPlayerPos())
   goalPos = map.data[60][30]
   startPos = map.data[55][72]
  startPos = map.data[pos[3]][pos[1]]



  paths = {}
  gateState = {}
  gates = {}
  triggers = FindTriggers("gate",true)
  for i=1,#triggers do
    gateState[tonumber(GetTagValue(triggers[i], "gate"))] = 0
    gates[tonumber(GetTagValue(triggers[i], "gate"))] = triggers[i]
  end

  for i =1,#triggers do 
    startPos = posToInt(GetTriggerTransform(gates[i]).pos)
    startPos = map.data[startPos[3]][startPos[1]]
    if(i==#triggers) then 
      goalPos = posToInt(GetTriggerTransform(gates[1]).pos )
    else
      goalPos = posToInt(GetTriggerTransform(gates[i+1]).pos )
    end
    goalPos = map.data[goalPos[3]][goalPos[1]]
    paths[#paths+1] =  AStar:AStarSearch(map.data, startPos, goalPos)
  end
  	path = paths[#paths]
  	for i = 1,#paths-1 do
  		for j = 1,#paths[i] do 
	  		path[#path+1] = paths[i][j]
	  	end
  	end
end


function tick(dt)

	if(DEBUG) then 
	  local playerTrans = GetPlayerTransform()
	  playerTrans.pos,pos2 = posToInt(playerTrans.pos)
	  DebugWatch("Player Pos: ",playerTrans.pos)

	end


	if(PATHSET) then 

	  	if(DEBUG)then 

		    AStar:drawPath(map.data,path)

			local t = GetCameraTransform()
			local dir = TransformToParentVec(t, {0, 0, -1})

			local hit, dist, normal, shape = QueryRaycast(t.pos, dir, 10)
			DebugWatch("Hit", hit)
			if hit then
				--Visualize raycast hit and normal
				local hitPoint = VecAdd(t.pos, VecScale(dir, dist))
				local mat,r,g,b = GetShapeMaterialAtPosition(shape, hitPoint)
				DebugWatch("Raycast hit voxel made out of ", mat.." | r:"..r.."g:"..g.."b:"..b)
				DebugWatch("Terrain cost",checkIfTerrainValid(mat,r,g,b))
				DebugWatch("body mass",GetBodyMass(GetShapeBody(shape)))
			end

		end



		for key,vehicle in pairs(aiVehicles) do 
			vehicle:tick(dt)
		end	

		raceManager:raceTick()
		-- DebugWatch("time",math.floor(GetTime()/5))
		-- DebugWatch("time",GetTime()%5)


		if(raceManager.countdown>0 and   RACECOUNTDOWN) then
			raceManager:raceCountdown()
		elseif(raceManager.countdown<0)then

			RACECOUNTDOWN = false
		end



	  if DEBUG and  InputPressed("r") and not RACESTARTED  then
	    RACESTARTED = true
	    -- DebugPrint("race started!")
	    raceManager:startRace()
	    PlaySound(sndStart)
	    -- PlayMusic("MOD/sounds/drive_to_survive.ogg")
	     -- path =  AStar:AStarSearch(map.data, startPos, goalPos)
	  elseif(RACESTARTED and path)then 





	    -- DebugWatch("running",#paths)
	    -- for key,val in ipairs(paths) do  
	    --    AStar:drawPath2(map.data,val)
	    -- end
	  end
	  -- local playerTrans = GetPlayerTransform()
	  -- playerTrans.pos,pos2 = posToInt(playerTrans.pos)
	  -- DebugWatch("Player Pos: ",playerTrans.pos)
	  -- -- --  DebugWatch("original Player Pos: ", GetPlayerTransform().pos)
	  -- --  -- DebugWatch("Pos 2: ",pos2) 
	  --  local pos = VecCopy(playerTrans.pos)
	  --  if(pos[3] ~= nil and pos[1]~= nil) then
	  --   	-- DebugPrint(pos[3].." | "..pos[1])
	  --   	 DebugWatch("player Grid Cost: ",map.data[pos[3]][pos[1]]:getCost())

	  --    DebugWatch("player Grid neighbors: ",#map.data[pos[3]][pos[1]].neighbors)

	  --    local totalCost = 0
	  --    for key, val in ipairs(map.data[pos[3]][pos[1]]:getNeighbors()) do
	  --         totalCost = totalCost + map.data[val.y][val.x]:getCost()
	  --    end

	  --    DebugWatch("player Grid neighbor: ",totalCost)

	  --    DebugWatch("player Grid VALID: ",map.data[pos[3]][pos[1]].validTerrain)
	  -- -- else

	  -- end

	elseif not PATHSET and GetTime() >0.1 then 
		if(not mapInitialized) then 
			initMap()
		end
		-- DebugPrint("prepping paths")

		
			initPaths()


			for key,vehicle in pairs(aiVehicles) do 
				vehicle:initGoalPos()
			end	
			PATHSET = true
		-- DebugPrint("Paths set")

		-------

		 --- init racing values

		 -----


			raceManager:init(aiVehicles,path)
		
	end



	---- ----------------


	------- handle player tick stuff


	---------------

	if(PLAYERRACING) then 
		raceManager:playerHandler()
		if((raceManager.countdown > 0 and  raceManager.preCountdown <=0) or playerConfig.finished  ) then
	-- 		raceManager:StartCamPos()

			 raceManager:cameraOperator(playerConfig.car)
			-- CAMMODE = false
		elseif(CAMMODE and raceManager.countdown<=0) then
			-- CAMMODE = false
		end

	end


	---------------------
			---------- keypress stuff
	---------------

	if InputPressed("c") then 
		CAMMODE = not CAMMODE

	end

	if(InputPressed("p")) then

		raceManager:setDisplayRange()
	end


end

function update(dt )
	for key,vehicle in pairs(aiVehicles) do 
		if(key ~= playerConfig.car) then 
			vehicle:update(dt)
		end
	end	



	if(RACESTARTED and CAMMODE) then 
		raceManager:cameraManager()

	end
	raceManager:cameraControl()
	
end




function ai:initVehicle(vehicle) 

	self.id = vehicle
	self.body = GetVehicleBody(self.id)
	self.transform =  GetBodyTransform(self.body)
	self.shapes = GetBodyShapes(self.body)



	--- declare driver name 

	if(math.random(0,200)<=1) then
		self.driverName = uniqueNames[math.random(1,#uniqueNames)]
	else
		self.driverFName = fNames[math.random(1,#fNames)] 
		self.driverSName = sNames[math.random(1,#sNames)]
		self.driverName = self.driverFName.." "..self.driverSName
	end
		--- find largest shape and dclare that the main vehicle SpawnParticle

	local largestKey = 0
	local shapeVoxels = 0
	local largestShapeVoxels = 0
	for key,shape in ipairs(self.shapes) do
		shapeVoxels = GetShapeVoxelCount(shape)
		if(shapeVoxels> largestShapeVoxels) then
			largestShapeVoxels = shapeVoxels
			largestKey = key
		end
	end
	self.mainBody = self.shapes[largestKey]
	self.bodyXSize,self.bodyYSize ,self.bodyZSize  = GetShapeSize(self.mainBody)
	-- DebugPrint("body Size: "..self.bodyXSize.." | "..self.bodyYSize.." | "..self.bodyZSize)


	for i=1,3 do 
		self.targetMoves.list[i] = Vec(0,0,0)
	end

	self.raceCheckpoint = 1
	self.currentCheckpoint = nil

	for key,value in ipairs(checkpoints) do
		if(tonumber(GetTagValue(value, "checkpoint"))==self.raceCheckpoint) then 
			self.currentCheckpoint = value
		end
	end	

	for i = 1, self.pidState.intergralTime do
		self.pidState.integralData[i] = 0

	end


	self.hudColour = {math.random(0,100)/100,math.random(0,100)/100,math.random(0,100)/100}

	local aiLevel = aiPresets.difficulties[math.random(1,#aiPresets.difficulties)]

	self.controller.aiLevel = aiLevel.name

	self.controller.steeringThres  = aiLevel.steeringThres --0.4

	self.controller.speedSteeringThres = aiLevel.speedSteeringThres
	self.controller.tenacity = aiLevel.tenacity

	self.controller.errorCoef = aiLevel.errorCoef


	self.scanning.maxScanLength = self.scanning.maxScanLength * (math.random(90,350)/100) 



end

function ai:initGoalPos()
	self.goalPos = map.data[path[self.raceValues.targetNode][2]][path[self.raceValues.targetNode][1]]:getPos()
	self.targetNode = map.data[path[self.raceValues.targetNode][2]][path[self.raceValues.targetNode][1]]



	self.NextNode = map.data[path[self.raceValues.targetNode][2]][path[self.raceValues.targetNode][1]]
	-- self:initClusters()


end


function ai:initClusters()
	for cluster= 1,self.clustering.centroids do 
		self.clustering.clusters.centroids.data[cluster] = deepcopy(node)

		 self.clustering.clusters.centroids.data[cluster]:loadSprite()
	end
	for i = 1,self.clustering.dataSize do 
		--clustering.clusters.current.data
		self.clustering.clusters.current.data[i] = deepcopy(node)
		self.clustering.clusters.prior.data[i] = deepcopy(node)
		self.clustering.clusters.current.data[i]:loadSprite()
	end

	self:scanPos()
	self:clusteringCentroids()

end

function ai:tick(dt)
		-- DebugWatch("datasize = ",#self.clustering.clusters.centroids.data)

		self:raceController()
		-- self:controlActions()
	if(RACESTARTED and (not PLAYERRACING or (self.id ~= aiVehicles[playerConfig.car].id or playerConfig.finished))) then 
		self:vehicleController()

		if(GetPlayerVehicle() == self.id and DEBUG) then
			DebugWatch("current lap:",self.raceValues.laps)

		end
	end
		-- DebugWatch("velocity:", VecLength(GetBodyVelocity(GetVehicleBody(self.id))))

	
end

function ai:update(dt)
	if(RACESTARTED) then

		-- self:vehicleController()
	end
	
end

function ai:raceController()
	if(RACESTARTED) then 

		self:raceDetailsHandler()


		self:controlActions()

		local vehiclePos = GetVehicleTransform(self.id).pos
		local indexVal = posToInt(vehiclePos)
		-- DebugWatch("vec1: ",Vec(indexVal[1],0,indexVal[3]))
		-- DebugWatch("vec2: ",Vec(path[self.raceValues.targetNode][1],0,path[self.raceValues.targetNode][2]))
		-- 	DebugWatch("dist to goal",VecLength( VecSub(
			-- 	Vec(indexVal[1],0,indexVal[3]),
			-- 	Vec(path[self.raceValues.targetNode][1],0,path[self.raceValues.targetNode][2])))
			-- )
		if(VecLength( VecSub(
				Vec(indexVal[1],0,indexVal[3]),
				Vec(path[self.raceValues.targetNode][1],0,path[self.raceValues.targetNode][2])))
		<self.raceValues.completionRange) then 
			
				self.raceValues.targetNode = self.raceValues.targetNode%#path +1
				self.raceValues.NextNode = self.raceValues.targetNode%#path +1

				self.goalPos = map.data[path[self.raceValues.targetNode][2]][path[self.raceValues.targetNode][1]]:getPos()
				self.targetNode = map.data[path[self.raceValues.targetNode][2]][path[self.raceValues.targetNode][1]]
				
				self.NextNode = map.data[path[self.raceValues.targetNode][2]][path[self.raceValues.targetNode][1]]




				self.raceValues.completedGoals = self.raceValues.completedGoals + 1

				if(math.floor(self.raceValues.completedGoals/(#path+1))>self.raceValues.laps) then 

					if(	not self.raceValues.bestLap) then
						self.raceValues.bestLap = raceManager:lapTime()

					elseif (raceManager:lapTime()-self.raceValues.lastLap < self.raceValues.bestLap )then
						self.raceValues.bestLap = raceManager:lapTime()-self.raceValues.lastLap
					end

					--- add player lastlap if vehicle is player 
					if(PLAYERRACING and (self.id == aiVehicles[playerConfig.car].id and not playerConfig.finished)) then 
						playerConfig.bestLap = self.raceValues.bestLap 
						playerConfig.hudInfo.lapInfo[3].time =  self.raceValues.bestLap 
						-- DebugPrint(playerConfig.hudInfo.lapInfo[3].time)
					end
					self.raceValues.lastLap = raceManager:lapTime()
					playerConfig.hudInfo.lapInfo[2].time = self.raceValues.lastLap 

				end
				self.raceValues.laps = math.floor(self.raceValues.completedGoals/(#path+1))
		else
			-- SpawnParticle("fire", self.goalPos, Vec(0,5,0), 0.5, 1)
		end


	end

	-- DebugWatch("checkpoint: ",self.goalPos)



end


--- handle race position / laps / checkpoints
	-- raceValues = {
	-- 	completedGoals  = 0,
	-- 	targetNode 		= 1,
	-- nextCheckpoint = 1,
		-- passedCheckPoints = 0,
	-- 	completionRange = 4,
	-- 	lookAhead = 2,
	-- 	laps = 0 	
		-- splits = {}

	-- },



function ai:raceDetailsHandler()
	
	if IsVehicleInTrigger(self.raceValues.nextCheckpoint, self.id) then
		

	end


	if (self.raceValues.targetNode%#path) == 0 then
		

	end
	
end


function ai:goalDistance()
	return VecLength( VecSub(self:getPos(),self.goalPos))
end

function ai:getPos()
	return GetVehicleTransform(self.id).pos
end

function ai:markLoc()
	
	if InputPressed("g") and not RACESTARTED  then

		RACESTARTED = true
		DebugPrint("race Started")
		self.currentCheckpoint = self.currentCheckpoint+1
		self.goalOrigPos = GetTriggerTransform(self.currentCheckpoint).pos

		self.goalPos = TransformToParentPoint(GetTriggerTransform(self.currentCheckpoint),Vec(math.random(-7,7),0,math.random(5,10)))

		-- local camera = GetCameraTransform()
		-- local aimpos = TransformToParentPoint(camera, Vec(0, 0, -300))
		-- local hit, dist,normal = QueryRaycast(camera.pos,  VecNormalize(VecSub(aimpos, camera.pos)), 200,0)
		-- if hit then
			
		-- 	self.goalPos = TransformToParentPoint(camera, Vec(0, 0, -dist))

		-- end 	

		-- DebugPrint("hitspot"..VecStr(goalPos).." | "..dist.." | "..VecLength(
		-- 							VecSub(GetVehicleTransform(vehicle.id).pos,goalPos)))
	end

	if(RACESTARTED) then 
		if(IsVehicleInTrigger(self.currentCheckpoint,self.id)) then
			self.raceCheckpoint = (self.raceCheckpoint%#checkpoints)+1
			for key,value in ipairs(checkpoints) do 
				
				if(tonumber(GetTagValue(value, "checkpoint"))==self.raceCheckpoint) then 
					self.currentCheckpoint = value
					self.goalOrigPos = GetTriggerTransform(self.currentCheckpoint).pos

					self.goalPos =TransformToParentPoint(GetTriggerTransform(self.currentCheckpoint),Vec(math.random(-7,7),0,math.random(5,10)))
				end
			end

			end

		-- DebugWatch("checkpoint: ",raceCheckpoint)
		-- DebugWatch("goalpos",VecLength(goalPos))
		SpawnParticle("fire", self.goalPos, Vec(0,5,0), 0.5, 1)
	end


end



	-- reversingController = {
	-- 	reversing = false,
	-- 	minVelocity = 1,
	-- 	waitTime = 3,
	-- 	currentWait = 3,
	-- 	reverseTime = 2,
	-- 	currentReverseTime = 2,
	-- },

function ai:controlActions(dt)
	if(not self.reversingController.reversing) then 
		if(VecLength(GetBodyVelocity(GetVehicleBody(self.id)))<self.reversingController.minVelocity) then
			if(self.reversingController.currentWait<0) then
				self.reversingController.reversing = true
			end
			self.reversingController.currentWait = self.reversingController.currentWait - GetTimeStep()
		elseif(self.reversingController.currentWait  ~= self.reversingController.waitTime) then
			self.reversingController.currentWait  = self.reversingController.waitTime
		end

		if(self.usingClustering) then
			self:scanPos()
		end
		local steeringValue = -self:pid()
		local accelerationValue = self:accelerationError()
		
		
		-- DebugWatch("pre acceletation: ",self.controller.accelerationValue)
		-- DebugWatch("pre steering: ",self.controller.steeringValue)


		self.controller.steeringValue = steeringValue * self.steeringCoef
		self.controller.accelerationValue = accelerationValue*self.accelerationCoef

		self:controllerAugmentation()
		-- DebugWatch("post acceletation: ",self.controller.accelerationValue)
		-- DebugWatch("post steering: ",self.controller.steeringValue)

		self:obstacleAvoidance()



		self:applyError()
			
			--- apply reversing error

		local directionError =  self:directionError()
		self.controller.accelerationValue = self.controller.accelerationValue * directionError
		
		    --- apply steering safety error
		if(self.controller.accelerationValue>0)then 
			local corneringErrorMagnitude = self:corneringError()
			self.controller.accelerationValue = self.controller.accelerationValue * corneringErrorMagnitude
		end
		self.controller.steeringValue = self.controller.steeringValue  * directionError
	else
		if(self.reversingController.currentReverseTime >0) then
			self.controller.accelerationValue = -1
			self.controller.steeringValue = -self.controller.steeringValue 
			self.reversingController.currentReverseTime = self.reversingController.currentReverseTime - GetTimeStep()
		else
			self.reversingController.reversing = false
			self.reversingController.currentReverseTime = self.reversingController.reverseTime
			self.reversingController.currentWait = self.reversingController.waitTime
		end
		
	end
end


function ai:controllerAugmentation()
	local velocity =  VecLength(GetBodyVelocity(GetVehicleBody(self.id)))

	if(math.abs(self.controller.accelerationValue)>1.5 and velocity>self.cornerCoef and self.controller.accelerationValue*0.8 ~=0
		and math.abs(self.controller.steeringValue) >= self.controller.speedSteeringThres) then
		
		self.controller.accelerationValue = (math.log(self.controller.accelerationValue*0.4)) - math.abs(self.controller.steeringValue*self.steeringCoef)
	else 
		self.controller.accelerationValue  = 1
	end
	
	
end

function ai:obstacleAvoidance()
	local scanResults = {centre=nil,left =nil,sideL =nil,sideR =nil,right = nil}
	local scanShapes = {centre=nil,left =nil,sideL =nil,sideR =nil,right = nil}
	local scanhitPos = {centre=nil,left =nil,sideL =nil,sideR =nil,right = nil}
	local scanDists = {centre=0,left =0, sideL =0 , sideR =0, right = 0}
	local vehicleTransform = GetVehicleTransform(self.id)

	local front = self.bodyYSize/4 
	local side = self.bodyXSize/4
	local height = self.bodyZSize /6
	-- DebugWatch("height",self.bodyZSize)
	-- DebugWatch("width",self.bodyXSize)
	-- DebugWatch("length",self.bodyYSize)
	vehicleTransform.pos = TransformToParentPoint(vehicleTransform,Vec(0,height/4	,-front/4))
	local testScanRot = nil
	local fwdPos = nil
	local direction = nil
	local scanStartPos = TransformToParentPoint(vehicleTransform,Vec(0,0,0))
	local scanEndPos = TransformToParentPoint(vehicleTransform,Vec(0,0,0))

	local scanLength = 2+ self.scanning.maxScanLength*((VecLength(GetBodyVelocity(GetVehicleBody(self.id))))/self.scanning.maxScanLength)

	for key,scan in pairs(self.scanning.positions) do 


		if(scan.direction == "centre") then 
			scanStartPos =VecCopy(vehicleTransform.pos)
		elseif(scan.direction =="left") then
			scanStartPos = TransformToParentPoint(vehicleTransform,Vec(side/6,0,front/8))
		elseif(scan.direction =="right") then
			scanStartPos = TransformToParentPoint(vehicleTransform,Vec(-side/6,0,front/8))
		elseif(scan.direction =="sideR") then
			scanStartPos = TransformToParentPoint(vehicleTransform,Vec(-side/5,0,front/4))
		elseif(scan.direction =="sideL") then
			scanStartPos = TransformToParentPoint(vehicleTransform,Vec(side/5,0,front/4))
		end

		scanEndPos = TransformToParentPoint(Transform(scanStartPos,vehicleTransform.rot),scan.startVec)
		testScanRot = QuatLookAt(scanEndPos,scanStartPos)

		fwdPos = TransformToParentPoint(Transform(scanStartPos,testScanRot),  
				Vec(0,0,-scanLength))---self.scanning.maxScanLength))
		direction = VecSub(scanStartPos,fwdPos)
		direction = VecNormalize(direction)
	    QueryRejectVehicle(self.id)
	    QueryRequire("dynamic large")

	    local hit,dist,normal, shape = QueryRaycast(scanStartPos, direction, scanLength)--self.scanning.maxScanLength)
	    scanResults[key] = hit
	    scanDists[key] = dist
	    scanShapes[key] = shape
	    scanhitPos[key]	= VecScale(direction,dist)
	    if(hit and DEBUGCARS) then

			 DrawLine(scanStartPos, VecAdd(scanStartPos, VecScale(direction, dist)), 1, 0, 0)
		elseif(DEBUGCARS) then
			DrawLine(scanStartPos, VecAdd(scanStartPos, VecScale(direction, dist)), 0, 1, 0)
		end
	end

	local turnBias = math.random()

	if(scanResults.centre ) then 
		-- DebugWatch("pre val:",self.controller.accelerationValue )
		self.controller.accelerationValue =self.controller.accelerationValue* (self:getRelativeSpeed(scanShapes.centre,scanhitPos.center))--/self.controller.tenacity)
		-- self.controller.accelerationValue = self.controller.accelerationValue    * self.controller.tenacity

		-- DebugWatch("post val:",self.controller.accelerationValue )
		-- DebugWatch("relative val:",relative )
		
	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and not scanResults.centre and  
				(scanResults.left or scanResults.right or scanResults.sideL or scanResults.sideR)	) then
		self.controller.accelerationValue = self.controller.accelerationValue    * 2

	end
	if(scanResults.left and scanResults.right) then 

		self.controller.accelerationValue = self.controller.accelerationValue    * 0.5

	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.left) then

		self.controller.steeringValue = self.controller.steeringForce +(scanDists.left/(self.scanning.maxScanLength/2)/2)
	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.right) then 

		self.controller.steeringValue = -self.controller.steeringForce - (scanDists.right/(self.scanning.maxScanLength/2)/2)
	

	--- handle sides 

	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.sideL) then

		self.controller.steeringValue = self.controller.steeringForce +(scanDists.sideL/(self.scanning.maxScanLength/2)/4)

	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.sideR) then

		
		self.controller.steeringValue = -self.controller.steeringForce - (scanDists.sideR/(self.scanning.maxScanLength/2)/4)

	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.centre ) then 
		--- random moving vs best direction 

		 -- sign((Bx - Ax) * (Y - Ay) - (By - Ay) * (X - Ax))


		if turnBias <0.5 then
			self.controller.steeringValue = self.controller.steeringForce*2
		else
			self.controller.steeringValue = -self.controller.steeringForce*2
		end

	
	end
end




-- function ai:obstacleAvoidance()
-- 	local scanResults = {centre=nil,left =nil,sideL =nil,sideR =nil,right = nil}
-- 	local scanShapes = {centre=nil,left =nil,sideL =nil,sideR =nil,right = nil}
-- 	local scanhitPos = {centre=nil,left =nil,sideL =nil,sideR =nil,right = nil}
-- 	local scanDists = {centre=0,left =0, sideL =0 , sideR =0, right = 0}
-- 	local vehicleTransform = GetVehicleTransform(self.id)

-- 	local front = self.bodyYSize/4 
-- 	local side = self.bodyXSize/4
-- 	local height = self.bodyZSize /4

-- 	vehicleTransform.pos = TransformToParentPoint(vehicleTransform,Vec(0,height/4	,-front/4))
-- 	local testScanRot = nil
-- 	local fwdPos = nil
-- 	local direction = nil
-- 	local scanStartPos = TransformToParentPoint(vehicleTransform,Vec(0,0,0))
-- 	local scanEndPos = TransformToParentPoint(vehicleTransform,Vec(0,0,0))

-- 	local scanLength = 2+ self.scanning.maxScanLength*((VecLength(GetBodyVelocity(GetVehicleBody(self.id))))/self.scanning.maxScanLength)

-- 	for key,scan in pairs(self.scanning.positions) do 


-- 		if(scan.direction == "centre") then 
-- 			scanStartPos =VecCopy(vehicleTransform.pos)
-- 		elseif(scan.direction =="left") then
-- 			scanStartPos = TransformToParentPoint(vehicleTransform,Vec(side/6,0,front/8))
-- 		elseif(scan.direction =="right") then
-- 			scanStartPos = TransformToParentPoint(vehicleTransform,Vec(-side/6,0,front/8))
-- 		elseif(scan.direction =="sideR") then
-- 			scanStartPos = TransformToParentPoint(vehicleTransform,Vec(-side/5,0,front/4))
-- 		elseif(scan.direction =="sideL") then
-- 			scanStartPos = TransformToParentPoint(vehicleTransform,Vec(side/5,0,front/4))
-- 		end

-- 		scanEndPos = TransformToParentPoint(Transform(scanStartPos,vehicleTransform.rot),scan.startVec)
-- 		testScanRot = QuatLookAt(scanEndPos,scanStartPos)

-- 		fwdPos = TransformToParentPoint(Transform(scanStartPos,testScanRot),  
-- 				Vec(0,0,-scanLength))---self.scanning.maxScanLength))
-- 		direction = VecSub(scanStartPos,fwdPos)
-- 		direction = VecNormalize(direction)
-- 	    QueryRejectVehicle(self.id)
-- 	    QueryRequire("dynamic large")

-- 	    local hit,dist,normal, shape = QueryRaycast(scanStartPos, direction, scanLength)--self.scanning.maxScanLength)
-- 	    scanResults[key] = hit
-- 	    scanDists[key] = dist
-- 	    scanShapes[key] = shape
-- 	    scanhitPos[key]	= VecScale(direction,dist)
-- 	    if(hit and DEBUGCARS) then

-- 			 DrawLine(scanStartPos, VecAdd(scanStartPos, VecScale(direction, dist)), 1, 0, 0)
-- 		elseif(DEBUGCARS) then
-- 			DrawLine(scanStartPos, VecAdd(scanStartPos, VecScale(direction, dist)), 0, 1, 0)
-- 		end
-- 	end

-- 	local turnBias = math.random()

-- 	if(scanResults.centre ) then 
-- 		-- DebugWatch("pre val:",self.controller.accelerationValue )
-- 		self.controller.accelerationValue =self.controller.accelerationValue* (self:getRelativeSpeed(scanShapes.centre,scanhitPos.center))--/self.controller.tenacity)
-- 		-- self.controller.accelerationValue = self.controller.accelerationValue    * self.controller.tenacity

-- 		-- DebugWatch("post val:",self.controller.accelerationValue )
-- 		-- DebugWatch("relative val:",relative )
		
-- 	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and not scanResults.centre and  
-- 				(scanResults.left or scanResults.right or scanResults.sideL or scanResults.sideR)	) then
-- 		self.controller.accelerationValue = self.controller.accelerationValue    * 2

-- 	end
-- 	if(scanResults.left and scanResults.right) then 

-- 		self.controller.accelerationValue = self.controller.accelerationValue    * 0.5



-- 	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.centre ) then 
-- 		--- random moving vs best direction 

-- 		 -- sign((Bx - Ax) * (Y - Ay) - (By - Ay) * (X - Ax))

-- 		if(scanResults.left and not scanResults.right) then
-- 			self.controller.steeringValue = 0.5
-- 		elseif(not scanResults.left and scanResults.right) then
-- 			self.controller.steeringValue = -0.5
-- 		elseif(not scanResults.left and not scanResults.right) then 

-- 			if turnBias <0.5 then
-- 				self.controller.steeringValue = self.controller.steeringForce*2
-- 			else
-- 				self.controller.steeringValue = -(self.controller.steeringForce)*2
-- 			end
-- 		end

-- 	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.left) then

-- 		self.controller.steeringValue = self.controller.steeringForce +(scanDists.left/(self.scanning.maxScanLength/2)/2)
-- 	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.right) then 

-- 		self.controller.steeringValue = -self.controller.steeringForce - (scanDists.right/(self.scanning.maxScanLength/2)/2)
	

-- 	--- handle sides 

-- 	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.sideL) then

-- 		self.controller.steeringValue = self.controller.steeringForce +(scanDists.sideL/(self.scanning.maxScanLength/2)/4)

-- 	elseif(math.abs(self.controller.steeringValue) < self.controller.steeringThres and scanResults.sideR) then

		
-- 		self.controller.steeringValue = -self.controller.steeringForce - (scanDists.sideR/(self.scanning.maxScanLength/2)/4)

-- 	end
-- end



--[[

	calculate relative speed, if vehicle moving towards then stop / avoid. 

	if movng faster than gap between then stop, otherwise move proportionally to the distance between vehicles vs speed

]]

function ai:getRelativeSpeed(shape,hitPos)
	local otherShapeBody = GetShapeBody(shape)
	local otherShapeBodyPos = GetBodyTransform(otherShapeBody).pos
	local otherShapeVelocity =  GetBodyVelocity(otherShapeBody)
	local vehicleBody = GetVehicleBody(self.id)
	local vehicleBodyPos = GetBodyTransform(vehicleBody).pos
	local vehicleVelocity = GetBodyVelocity(vehicleBody) 

	local toPoint = VecSub(vehicleBodyPos,otherShapeBodyPos)
	local movingTowards = false
	---VecSub(vehicleVelocity,otherShapeVelocity)
	-- DebugWatch("otherShapeVelocity",VecLength(otherShapeVelocity))
	-- DebugWatch("vehicleVelocity",VecLength(vehicleVelocity))

	local adjustmentValue = 0 

	--[[
		if crash likely then set adjustment to -1 (GTFO mode)
		elseif speed greater than safe range then force slow down
			else adjust speed to maintain safe distance 
		else set to higher speed to get closer for overtaking
	]]
	local minDist = self.controller.minDist
	if(VecLength(vehicleVelocity) >0) then 
		 minDist = minDist / math.log(VecLength(vehicleVelocity))
	end

	
	if(VecDot(toPoint,otherShapeVelocity)>0) then 
		adjustmentValue = -1
		if(DEBUG_SAE) then 
			DebugWatch("slowing for safety",1)
		end
	elseif(VecLength(otherShapeVelocity)<VecLength(vehicleVelocity)) then 
		local relativeSpeed = VecLength(vehicleVelocity)-VecLength(otherShapeVelocity) 
		local relativeDistance = VecLength(VecSub(vehicleBodyPos,hitPos))
			--- set mindist to be math.log of relative speed, relative speed is negative if they are faster
			--- dist coef 
		if(relativeSpeed ~=0) then 
			 minDist =  math.log((relativeSpeed))*math.sign(relativeSpeed)
		end
		local distCoef = relativeDistance-minDist

		if((relativeSpeed) > distCoef) then
			adjustmentValue = -(distCoef/(relativeSpeed*2))
		else
			adjustmentValue = (relativeSpeed/distCoef)--(0.2) + relativeSpeed/(relativeDistance)--*self.controller.tenacity)
			-- adjustmentValue=1
		end
		
	else
		adjustmentValue=2
	end
	if(DEBUG_SAE) then
		DebugWatch("minDist",minDist)
		DebugWatch("adjusting",adjustmentValue)
	end
	return adjustmentValue
-- bool isMovingTowards(vec2 testPoint, vec2 objectPosition, vec2 objectVelocty) {
--     vec2 toPoint = testPoint - objectPosition; //a vector going from your obect to the point
--     return dot(toPoint, objectVelocity) > 0;
-- }
end

function ai:turnDirection()
	
end


function ai:applyError()
	local errorCoef = self.controller.errorCoef--0.1
	local errorVal = math.random(-errorCoef,errorCoef) / 100
	self.steeringCoef = self.steeringCoef + errorVal
end

function ai:scanPos()

	self.scanning.scanLength = self.scanning.maxScanLength+(VecLength(GetBodyVelocity(GetVehicleBody(self.id))))

	local vehicleTransform = GetVehicleTransform(self.id)
	local min, max = GetBodyBounds(self.body)
	local boundsSize = VecSub(max, min)
	local center = VecLerp(min, max, 0.5)


	-- DebugWatch("boundsize",boundsSize)
	-- DebugWatch("center",center)

	vehicleTransform.pos = TransformToParentPoint(vehicleTransform,Vec(0,1.2	,0))


	for key,scan in pairs(self.scanning.cones) do 

		for i=1,ai.scanning.scanDepths do 
			local scanLength = self.scanning.scanLength * i



			local projectionAngle =  (math.sin(math.rad(scan.size)) * ((scanLength)))
			if(scan.startVec[1]>0) then
				projectionAngle = -projectionAngle	
			end
			local scanStartPos = TransformToParentPoint(vehicleTransform,scan.startVec)
			if(scan.startVec[1]==0) then
				scanStartPos = TransformToParentPoint(vehicleTransform, Vec(-projectionAngle/2,0,-1))
			end 
			
			local scanStartRot = QuatLookAt(vehicleTransform.pos,scanStartPos)
			local scanEndPos = TransformToParentPoint(Transform(vehicleTransform.pos,scanStartRot), Vec(projectionAngle,0,-1))
			if(scan.startVec[1]==0) then
				scanEndPos = TransformToParentPoint(vehicleTransform, Vec(projectionAngle/2,0,-1))
			end 
			local scanEndRot = QuatLookAt(vehicleTransform.pos,scanEndPos)
			for i=1,self.scanning.numScans do 
				QueryRejectVehicle(self.id)
				local testScanRot = QuatSlerp(scanStartRot,scanEndRot,i/self.scanning.numScans)
				local fwdPos = TransformToParentPoint(Transform(vehicleTransform.pos,testScanRot),  
						Vec(0,-self.scanning.vehicleHeight*2,-scanLength))
				local direction = VecSub(fwdPos,vehicleTransform.pos)
				direction = VecNormalize(direction)
			    QueryRejectVehicle(self.id)
			    QueryRequire("physical static") --large")

			    local hit,dist,normal, shape = QueryRaycast(vehicleTransform.pos, direction, scanLength)

			     -- DebugWatch("hitpos",(VecAdd(vehicleTransform.pos, VecScale(direction, dist))))

			    self:pushData(hit,dist,normal,shape,VecAdd(vehicleTransform.pos, VecScale(direction, dist)))

				 -- DebugLine(vehicleTransform.pos, VecAdd(vehicleTransform.pos, VecScale(direction, dist)), scan.scanColour.r, scan.scanColour.g, scan.scanColour.b)

				 -- DebugWatch("transform pos",(vehicleTransform.pos))

				 -- DebugWatch("forward pos",(fwdPos))
			end
		end	

	end


	self:clusteringOperations()


	self.clustering.clusters.current.pass = (self.clustering.clusters.current.pass%self.clustering.dataSize )+1 
	self.clustering.clusters.current.index = 1

end


--init clusters 
function ai:clusteringCentroids()
	local valRange = { min = { 100000, 100000, 100000},
						max = {-100000 , -100000 , -100000 } 
					}
	local pos = Vec(0,0,0)
	for index = 1,self.clustering.clusters.current.index do 

		pos = self.clustering.clusters.current.data[index]:getPos()
		for i = 1,3 do
			if(pos[i] ~= 0 and pos[i] < valRange.min[i]) then

				valRange.min[i] = pos[i]
			end
			if(pos[i] ~= 0 and pos[i] > valRange.max[i]) then
				valRange.max[i] = pos[i]
			end
		end
	end

	for i = 1,self.clustering.centroids do
		if(self.clustering.clusters.centroids.data[i].GNnumber==0 ) then 
			self.clustering.clusters.centroids.data[i]:push(
													math.random(valRange.min[1],valRange.max[1]),
													math.random(valRange.min[2],valRange.max[2]),
													math.random(valRange.min[3],valRange.max[3]),
													0)
		end

	end

	--DebugPrint("min:"..valRange.min[1]..","..valRange.min[2]..","..valRange.min[2].."\nMax: "..valRange.max[1]..","..valRange.max[2]..","..valRange.max[3])
end

--init clusters 
function ai:clusteringUpdateCentroids()
	local pos = Vec(0,0,0)
	local inputData = nil
	for index = 1,self.clustering.clusters.current.index do 

		inputData = self.clustering.clusters.current.data[index] 
		if inputData.value >=0 then
		pos = inputData:getPos()
		self.clustering.clusters.centroids.data[inputData:getMinID()]:growCluster(pos)
		end
	end
	self:clusteringCentroids()
	for i = 1,self.clustering.centroids do
		self.clustering.clusters.centroids.data[i]:updateCluster()
	end
end


-- find euclidian distance of data to clusters and update centroid locations
function ai:clusteringCalculateClusters()
	local pos = Vec(0,0,0)
	local center = Vec(0,0,0)
	local dist = 0

	for i = 1,self.clustering.iterations do 
		for index = 1,self.clustering.clusters.current.index do 
			self.clustering.clusters.current.data[index]:resetMins()
			
			pos = self.clustering.clusters.current.data[index]:getPos()

			for i = 1,self.clustering.centroids do
				 self.clustering.clusters.current.data[index]:computeNodeDistance(i,self.clustering.clusters.centroids.data[i])
			end
		end
		self:clusteringUpdateCentroids()
	end

end

--- perform operations on clusters to extract target
function ai:clusteringOperations()
	
	self:clusteringCalculateClusters()


	self:pseudoSNN()

	for i = 1,self.clustering.centroids do
		 self.clustering.clusters.centroids.data[i]:showSprite()
		 -- DebugWatch("cluster - "..i,VecSub(self.clustering.clusters.centroids.data[i]:getPos(),
		 -- 	 GetVehicleTransform(self.id).pos))
		 --DebugWatch("cluster - "..i,self.clustering.clusters.centroids.data[i]:getPos())
	-- VecLength(self.clustering.clusters.centroids.data[i]:getPos(),Vec(0,0,0)))
	end

	self.targetNode = self.clustering.clusters.centroids.data[self.clustering.mode]

end


--- simulate an snn network slightly to get best node

-- if(SNNpspprev[j]<SNNpsp[i])
--  {
--      SNNweights[j][i]=tanh(gammaweights*SNNweights[j][i]+learningrateweights*SNNpspprev[j]*SNNpsp[i]);
--  }

function ai:pseudoSNN()
	local bestpsp = 100000000
	local mode = -1
	local inputData = nil
	local pos = Vec(0,0,0)
	local value = 0
	for index = 1,self.clustering.clusters.current.index do 
		inputData = self.clustering.clusters.current.data[index] 
		self.clustering.clusters.centroids.data[inputData:getMinID()]:growPulse(inputData.value)
	end
	local psp = 100000000
	local dist = 0
	for i = 1,self.clustering.centroids do
		if(VecLength(self.clustering.clusters.centroids.data[i]:getPos())>0) then
			self.clustering.clusters.centroids.data[i]:firePulse()
			psp =self.clustering.clusters.centroids.data[i].SNNstate 
			if(psp>self.clustering.clusters.centroids.data[i].outputthreshold) then 
				dist = self.clustering.clusters.centroids.data[i]:getDistance(self.goalpos)
				psp = dist * (1-psp)
				if(psp<bestpsp) then 
					bestpsp = psp
					mode = i
				end 
			end
		end
	--		if(self.clustering.clusters.centroids.data[i].SNNstate > self.clustering.clusters.centroids.data[i].threshold) then
	end
	if(mode == -1) then
		mode = self.clustering.previousOutput 
	else
		self.clustering.previousOutput = mode

	end
	self.clustering.mode = mode
	-- DebugPrint(mode)
	if(self.clustering.mode ~=-1) then
		self.clustering.clusters.centroids.data[self.clustering.mode].spriteColour={0,0,1}
	end
end

function ai:pushData(hit,dist,normal,shape,hitPos)
	local index = self.clustering.clusters.current.index 
	local hitValue = 0
	if(hit) then 
		local mat,r,g,b  = GetShapeMaterialAtPosition(shape, hitPos)
		if(mat =="masonry") then
			for colKey, validSurfaceColours in ipairs(self.validSurfaceColours) do 
				
				local validRange = validSurfaceColours.range
				if(inRange(validSurfaceColours.r-validRange,validSurfaceColours.r+validRange,r)
				 and inRange(validSurfaceColours.g-validRange,validSurfaceColours.g+validRange,g) 
				 and inRange(validSurfaceColours.b-validRange,validSurfaceColours.b+validRange,b)) then 
					hitValue = 1
				end
			end
		else

			hitValue = -1
		end
	end
	--DebugPrint((#self.clustering.clusters.current.data))
	
	--DebugPrint("values: index: "..index.."\nhitpos:"..VecStr(hitPos).."\nhitval: "..hitValue.."\nClusterPos = "..VecStr(self.clustering.clusters.current.data[index]:getPos()))
	self.clustering.clusters.current.data[index]:push(hitPos[1],hitPos[2],hitPos[3],hitValue) 


	self.clustering.clusters.current.index = (self.clustering.clusters.current.index%self.clustering.dataSize )+1
end

function ai:pid()
	
	--- perform computations
	local targetNode, crossTrackErrorValue = self:currentCrossTrackError()
	-- DebugWatch("cross track error: ",crossTrackErrorValue)
	local crossTrackErrorRate = self:calculateCrossTrackErrorRate(crossTrackErrorValue)
	-- DebugWatch("cross track error rate: ",(crossTrackErrorRate))
	local integralErrorValue = self:calculateSteadyStateError(crossTrackErrorValue)
	-- DebugWatch("cross track error rate: ",(crossTrackErrorRate))
	-- update values 
	self.pidState.lastCrossTrackError = crossTrackErrorValue
	self.pidState.lastPnt = targetNode:getPos()
	-- calculate state 
	local output = (crossTrackErrorValue * self.pidState.pGain) + 
					(integralErrorValue * self.pidState.iGain) + 
					(crossTrackErrorRate * self.pidState.dGain)
	self.pidState.controllerValue = output
	-- DebugWatch("pid output: ",output)


	if(RACESTARTED and  self.pidState.training) then
		if math.abs(crossTrackErrorRate) > self.pidState.learningrateThres then 
			if(crossTrackErrorRate>0) then 
				self.accelerationCoef = self.accelerationCoef - self.pidState.learningrateweights
				self.steeringCoef = self.steeringCoef + self.pidState.learningrateweights

			else
				self.accelerationCoef = self.accelerationCoef + self.pidState.learningrateweights
				self.steeringCoef = self.steeringCoef - self.pidState.learningrateweights

			end

		end

	end

	return output
end


function ai:currentCrossTrackError()
	local crossTrackErrorValue = 0
	local vehicleTransform = GetVehicleTransform(self.id)
	local targetNode = self.targetNode
	if(targetNode) then
		local pnt = targetNode:getPos()
		crossTrackErrorValue,sign = self:crossTrackError(pnt,vehicleTransform)
	end	
	return targetNode, crossTrackErrorValue,sign
end

--- calculate distance to target direction and apply steering by force
--- fill in the gap here related to the distance ebtween the aprrelel lines of target nod3e to vehicle pos to solve it all
function ai:crossTrackError(pnt,vehicleTransform)


		
		vehicleTransform.pos[2] = pnt[2]
		
		local linePnt = vehicleTransform.pos
		local fwd = TransformToParentPoint(vehicleTransform, Vec(0,0,-100))
		local d = VecLength(VecScale( VecCross(
							VecSub(fwd,linePnt),VecSub(pnt,linePnt)),
										VecLength(VecNormalize(VecSub(fwd,linePnt)))))/1000
		pnt = VecSub(pnt,linePnt)
		fwd = VecSub(fwd,linePnt)
		linePnt = VecSub(linePnt,linePnt)
		local sign = (fwd[1]-linePnt[1])*(pnt[3]-linePnt[3])-(fwd[3]-linePnt[3])*(pnt[1]-linePnt[1])
		if(sign<0) then
			sign = -1
		elseif(sign>0) then
			sign = 1
		else
			sign = 0
		end


		return d*sign,sign

		-- Use the sign of the determinant of vectors (AB,AM), where M(X,Y) is the query point:	
		---position = sign((Bx - Ax) * (Y - Ay) - (By - Ay) * (X - Ax))

		---d=np.cross(p2-p1,p3-p1)/norm(p2-p1)

		-- local linePnt = vehizcleTransform.pos
		-- local lineDir = TransformToParentPoint(vehicleTransform, Vec(0,0,-1))
		-- lineDir = VecNormalize(VecSub(vehicleTransform.pos,fwd1	))

		-- local v = (VecSub(pnt,linePnt))
		-- local d = VecDot(v,lineDir)
		-- local out = VecAdd(linePnt,VecScale(lineDir,d))
		-- DebugWatch("point pos : ",pnt)
		-- DebugWatch("output pos : ",out)

		-- DebugWatch("output value: ",VecSub(out,pnt))







		-- local vehicleTransform = GetVehicleTransform(self.id)
		-- vehicleTransform.pos[2] = targetNode:getPos()[2]
		-- local fwd1 = TransformToParentPoint(vehicleTransform, Vec(0,0,-1))
		-- local norm = VecNormalize(VecSub(vehicleTransform.pos,fwd1	))
		-- local vBase =  VecSub(targetNode:getPos(),vehicleTransform.pos)
		-- local lineDir = VecSub(targetNode:getPos(),vehicleTransform.pos)
		-- local v1 = VecDot(vBase,norm)
		-- local pntDist = VecAdd(,VecScale(norm,v1))
		-- DebugWatch("distance to point: ",VecLength(pntDist))
		-- DebugWatch("V1 VAL: ",v1)
		-- local v = VecLength(VecSub(vehicleTransform.pos,fwd1))
		-- local d = VecLength(VecScale(VecSub(targetNode:getPos(),vehicleTransform.pos),v))
		-- -- DebugWatch("vector : ",v)
		-- DebugWatch("delta : ", d/10)
		-- DebugWatch("value from origin",VecSub(vehicleTransform.pos,fwd1))

end

function ai:calculateCrossTrackErrorRate(crossTrackErrorValue)
	local verifyCrossCheckErrorVal = 0
	local vehicleTransform = GetVehicleTransform(self.id)
	
	local pnt = self.pidState.lastPnt
	if(pnt) then
		
		verifyCrossCheckErrorVal = self:crossTrackError(pnt,vehicleTransform)
		verifyCrossCheckErrorVal = self.pidState.lastCrossTrackError - verifyCrossCheckErrorVal

	end	

	return verifyCrossCheckErrorVal
end


function ai:calculateSteadyStateError(crossTrackErrorValue)
	local index = self.pidState.integralIndex

	self.pidState.integralSum = self.pidState.integralSum - self.pidState.integralData[index]
	self.pidState.integralSum = self.pidState.integralSum + crossTrackErrorValue
	self.pidState.integralData[index] = crossTrackErrorValue

	self.pidState.integralIndex = (self.pidState.integralIndex%#self.pidState.integralData) +1

	return self.pidState.integralSum	
end

function ai:accelerationError()
	local accelerationErrorValue = 0
	local vehicleTransform = GetVehicleTransform(self.id)
	local targetNode = self.NextNode
	if(targetNode) then
		local pnt = targetNode:getPos()
		vehicleTransform.pos[2] = pnt[2]
		local linePnt = vehicleTransform.pos
		local lineDir = TransformToParentPoint(vehicleTransform, Vec(0,0,-1))
		lineDir = VecNormalize(lineDir)	
		local v = (VecSub(pnt,linePnt))
		local d = VecDot(v,lineDir)

		local out = VecAdd(linePnt,VecScale(lineDir,d))
		-- DebugWatch("line distance: ",VecLength(VecSub(vehicleTransform.pos,out))/self.scanning.scanLength*self.scanning.scanDepths)
		
		--- random debugging, please ignore

		-- DebugWatch("d value: ",d)
		-- DebugWatch("out value: ",out)
		-- DebugWatch("error value: ",VecLength(VecSub(vehicleTransform.pos,out)))
		-- local fwd = VecNormalize(TransformToParentPoint(vehicleTransform, Vec(0,0,-1)))
		-- local relative = VecDot(VecNormalize(VecSub(pnt,linePnt)),fwd)
		-- DebugWatch("fwd",pnt)
		-- DebugWatch("direction : ",math.acos( relative))

		-- local forward_vec = TransformToParentPoint(vehicleTransform, Vec(0,0,-1))
		-- local is_forward = VecDot(forward_vec, VecSub(pnt, vehicleTransform.pos)) > 0
		-- DebugWatch("is forward",is_forward)
		-- DebugWatch("local point  forwar", TransformToLocalPoint(vehicleTransform, pnt)[3])


		return VecLength(VecSub(vehicleTransform.pos,out))
	end	
end


	-- thanks to  iaobardar for help on getting the vecdot to work
function ai:directionError()
	local vehicleTransform = GetVehicleTransform(self.id)
	local targetNode = self.targetNode
	if(targetNode) then
		local pnt = targetNode:getPos()
		vehicleTransform.pos[2] = pnt[2]	
		-- local forward_vec = TransformToParentPoint(vehicleTransform, Vec(0,0,-1))
		-- local is_forward = VecDot(forward_vec, VecSub(pnt, vehicleTransform.pos)) > 0
		is_forward = TransformToLocalPoint(vehicleTransform, pnt)[3] <-1
		-- DebugWatch("is forward",is_forward)
		
		if(is_forward) then
			return 1
		else
			return -1
		end
	else
		return 0 
	end
			
			-- DebugWatch("local point  forwar", TransformToLocalPoint(vehicleTransform, pnt)[3])

end

function ai:corneringError()
	local vehicleTransform = GetVehicleTransform(self.id)
	local targetNode = self.NextNode
	if(targetNode) then
		local pnt = targetNode:getPos()
		vehicleTransform.pos[2] = pnt[2]	
		-- local forward_vec = TransformToParentPoint(vehicleTransform, Vec(0,0,-1))
		-- local is_forward = VecDot(forward_vec, VecSub(pnt, vehicleTransform.pos)) > 0
		local forward = TransformToLocalPoint(vehicleTransform, pnt)[3] 
		local angleToTarget = TransformToLocalPoint(vehicleTransform, pnt)[1]
		local angleError =  angleToTarget/forward
		if(DEBUGCONTROLLERS) then
			DebugWatch("angle error",angleError)
		end
		
		angleError = 1- clamp(math.abs(angleError), 0, 0.5)
		return angleError

		-- if(forward>1) then
		-- 	return 1
		-- else
		-- 	return -1
		-- end
	else
		return 0 
	end
			
			-- DebugWatch("local point  forwar", TransformToLocalPoint(vehicleTransform, pnt)[3])

end





		-- Use the sign of the determinant of vectors (AB,AM), where M(X,Y) is the query point:	
		---position = sign((Bx - Ax) * (Y - Ay) - (By - Ay) * (X - Ax))

		---d=np.cross(p2-p1,p3-p1)/norm(p2-p1)

		-- local linePnt = vehizcleTransform.pos
		-- local lineDir = TransformToParentPoint(vehicleTransform, Vec(0,0,-1))
		-- lineDir = VecNormalize(VecSub(vehicleTransform.pos,fwd1	))

		-- local v = (VecSub(pnt,linePnt))
		-- local d = VecDot(v,lineDir)
		-- local out = VecAdd(linePnt,VecScale(lineDir,d))
		-- DebugWatch("point pos : ",pnt)
		-- DebugWatch("output pos : ",out)


	-- //linePnt - point the line passes through
	-- //lineDir - unit vector in direction of line, either direction works
	-- //pnt - the point to find nearest on line for
	-- public static Vector3 NearestPointOnLine(Vector3 linePnt, Vector3 lineDir, Vector3 pnt)
	-- {
	--     lineDir.Normalize();//this needs to be a unit vector
	--     var v = pnt - linePnt;
	--     var d = Vector3.Dot(v, lineDir);
	--     return linePnt + lineDir * d;
	-- }

 

function ai:vehicleController()
	DriveVehicle(self.id, 0.05+self.controller.accelerationValue,
							self.controller.steeringValue,
							 self.controller.handbrake)
end

function ai:MAV(targetCost)
	self.targetMoves.targetIndex = (self.targetMoves.targetIndex%#self.targetMoves.list)+1 
	self.targetMoves.target = VecSub(self.targetMoves.target,self.targetMoves.list[self.targetMoves.targetIndex])
	self.targetMoves.target = VecAdd(self.targetMoves.target,targetCost)
	self.targetMoves.list[self.targetMoves.targetIndex] = targetCost
	return VecScale(self.targetMoves.target,(#self.targetMoves.list/100))

end



function ai:costFunc(testPos,hit,dist,shape,key)



	local cost = 10000 
	if(not hit) then
		cost = VecLength(VecSub(testPos,self.goalPos))*(1-self.weights[key])
	end
	return cost
end



function ai:controlVehicle( targetCost)
	local hBrake = false
	if(VecLength(self.goalPos)> 0.5) then
		local targetMove = VecNormalize(targetCost.target)

		if(VecLength(
										VecSub(GetVehicleTransform(self.id).pos,self.goalPos))>2) then
			-- DebugWatch("pre updated",VecStr(targetMove))
			if(targetMove[1] ~= 0 and targetMove[3] ==0) then 
				targetMove[3] = -1
				
					targetMove[1] = -targetMove[1] * 3
				

			end
			if(targetMove[1]~= 0) then
				targetMove[3] = targetMove[3]*	cornerDrivePower 
				targetMove[1] = targetMove[1] * steerPower

			end 
			if(targetMove[1]==0 and targetMove[3]~=0) then

				targetMove[3] = targetMove[3] *3
			elseif(inRange(-0.1,0.1,targetMove[1]) and targetMove[3]~=0) then

				targetMove[3] = targetMove[3] *2
			end


			DriveVehicle(self.id, -targetMove[3]*drivePower,-targetMove[1], hBrake)
			-- DebugWatch("post updated",VecStr(targetMove))
			-- DebugWatch("motion2",VecStr(detectPoints[targetCost.key]))
		else 
			DriveVehicle(vehicle.id, 0,0, true)
		end
	end
end


-- function ai:modulo(a,b )
-- 	return a - math.floor(a/b)*b
	
-- end

------------------------------------------------


---- PATHFINDING


-----------------------------------------------------

---- use flood fill to comap[re to last neighbor  that was known and if neighbor foun and  track then 

---- compare the next based on known locations nd move outwards.]

function scanGrid(x,y)
  local pos = Vec(0,0,0)
  local gridScore = 1
  local spotScore = 0 
  local hitHeight = mapSize.scanHeight
  local heightOrigin = 1000000
  local minHeight = heightOrigin
  local maxHeight = -heightOrigin
  local validTerrain  = true
  local xLocal = 0
  local yLocal = 0
  for y1= 1, mapSize.grid, mapSize.gridResolution do
  	yLocal = (y+y1) - mapSize.grid/2
    for x1= 1, mapSize.grid, mapSize.gridResolution do
    	xLocal = (x+x1) - mapSize.grid/2
      spotScore,hitHeight,hit =  getMaterialScore3(xLocal, yLocal)
      if(hitHeight == mapSize.scanHeight or IsPointInWater(Vec(xLocal,hitHeight,yLocal))or not hit) then
        minHeight = -mapSize.scanLength
        maxHeight = mapSize.scanLength
        validTerrain = false
      elseif(minHeight == heightOrigin or maxHeight == heightOrigin) then
        minHeight = hitHeight
        maxHeight = hitHeight
      elseif(hitHeight < minHeight) then
        minHeight = hitHeight
      elseif(hitHeight > maxHeight) then
        maxHeight = hitHeight
      end

      -- local hit,height,hitPos, shape = getHeight(x,y)
      -- spotScore =  getMaterialScore2(hit,hitPos,shape)
      gridScore = gridScore + spotScore

    end
  end
  --DebugPrint("max: "..maxHeight.." min: "..minHeight.." sum: "..(((maxHeight - minHeight) / (mapSize.gridHeight*mapSize.gridThres)))  )  
  if(((maxHeight - minHeight) )>mapSize.gridHeight) then
    validTerrain = false
  end  
  if(((maxHeight) - (minHeight)) ~=0 ) then
    gridScore = gridScore + ((1+((maxHeight) - (minHeight))/100))
  end
  return gridScore,validTerrain, minHeight
end



function getHeight(x,y)

  local probe = Vec(x,mapSize.scanHeight,y)
  local hit, dist,normal,shape = QueryRaycast(probe, Vec(0,-1,0), mapSize.scanLength)
  local hitHeight = 0
  if hit then
    hitHeight = mapSize.scanHeight - dist
  end 
  return hit,hitHeight,VecAdd(probe, VecScale(Vec(0,-1,0), dist)),shape

end

function getMaterialScore(x,z,y)
  local score = 0
  local probe = Vec(x,z+(mapSize.gridHeight/2),y)
  QueryRequire("physical static")
  local hit, dist,norm,shape = QueryRaycast(probe, Vec(0,-1,0), mapSize.gridHeight)
  if hit then
    local hitPoint = VecAdd(probe, VecScale(Vec(0,-1,0), dist))
    local mat,r,g,b  = GetShapeMaterialAtPosition(shape, hitPoint)
    if(mat =="masonry") then
      for colKey, validSurfaceColours in ipairs(map.validSurfaceColours) do 
        
        local validRange = validSurfaceColours.range
        if(inRange(validSurfaceColours.r-validRange,validSurfaceColours.r+validRange,r)
         and inRange(validSurfaceColours.g-validRange,validSurfaceColours.g+validRange,g) 
         and inRange(validSurfaceColours.b-validRange,validSurfaceColours.b+validRange,b))
          then 
            score = 0.1
        end
      end
    else

      score = 1
    end    
  else
    score = 10
  end

  return score

end

function getMaterialScore2(hit,hitPoint,shape)
  local score = 0
  if hit then
    local mat,r,g,b  = GetShapeMaterialAtPosition(shape, hitPoint)
    if(mat =="masonry") then
      for colKey, validSurfaceColours in ipairs(map.validSurfaceColours) do 
        
        local validRange = validSurfaceColours.range
        if(inRange(validSurfaceColours.r-validRange,validSurfaceColours.r+validRange,r)
         and inRange(validSurfaceColours.g-validRange,validSurfaceColours.g+validRange,g) 
         and inRange(validSurfaceColours.b-validRange,validSurfaceColours.b+validRange,b))
          then 
            score = 0.1
        end
      end
    else

      score = 1
    end    
  else
    score = 10
  end

  return score

end


function getMaterialScore3(x,y)
  local score = 0
  local probe = Vec(x,mapSize.scanHeight,y)
  QueryRequire("static")
  local hit, dist,normal,shape = QueryRaycast(probe, Vec(0,-1,0), mapSize.scanLength)
  if hit then
	    local hitPoint = VecAdd(probe, VecScale(Vec(0,-1,0), dist))
	    local mat,r,g,b  = GetShapeMaterialAtPosition(shape, hitPoint)
		for matKey, matBase in ipairs(map.validMaterials) do 
			if(score ~= mapSize.weights.goodTerrain ) then 
			    if(mat ==matBase.material) then
			      for colKey, validSurfaceColours in ipairs(matBase.validSurfaceColours) do 
			        
			        local validRange = validSurfaceColours.range
			        if(inRange(validSurfaceColours.r-validRange,validSurfaceColours.r+validRange,r)
			         and inRange(validSurfaceColours.g-validRange,validSurfaceColours.g+validRange,g) 
			         and inRange(validSurfaceColours.b-validRange,validSurfaceColours.b+validRange,b))
			          then 
			            score = mapSize.weights.goodTerrain
			        end
			      end
			      if(score ~= mapSize.weights.goodTerrain ) then 
			        score = mapSize.weights.badTerrain
			      end
			    else

			      score = mapSize.weights.badTerrain
			    end  
			end
	    end  
  else
    score = mapSize.weights.impassableTerrain
  end
  local hitHeight = mapSize.scanHeight - dist

  return score,hitHeight,hit

end

function posToInt(pos)
  local pos2 = VecCopy(pos)
  for i=1,3 do 
    pos[i] = math.modf((pos[i]+200)/mapSize.grid)
    --math.floor(pos[i]))
    pos2[i] = (pos[i]*mapSize.grid)
    if(i == 1 or i == 3 ) then
      pos2[i] = pos2[i] + (mapSize.grid/2)
    end
    pos2[i] = pos2[i] -200
  end
  return pos,pos2
end

function posToIndex(pos)
  local pos2 = VeC(0,0,0)
  for i=1,3 do 
    pos[i] = math.modf((pos[i]+200)/mapSize.grid)
    --math.floor(pos[i]))
    pos2[i] = (pos[i]*mapSize.grid)
    if(i == 1 or i == 3 ) then
      pos2[i] = pos2[i] + (mapSize.grid/2)
    end
    pos2[i] = pos2[i] -200
  end
  return pos,pos2
end


function Heuristic(a, b)
      return Math.Abs(a[1] - b[1]) + Math.Abs(a[3] - b[3]);
 end 

function checkIfTerrainValid(mat,r,g,b)
		local score = 0
		if(DEBUG) then
			DebugWatch("r",#map.validMaterials)
		end
		for matKey, matBase in ipairs(map.validMaterials) do 
			if(score ~= mapSize.weights.goodTerrain ) then 
			    if(mat ==matBase.material) then
			      for colKey, validSurfaceColours in ipairs(matBase.validSurfaceColours) do 
			        
			        local validRange = validSurfaceColours.range
			        if(inRange(validSurfaceColours.r-validRange,validSurfaceColours.r+validRange,r)
			         and inRange(validSurfaceColours.g-validRange,validSurfaceColours.g+validRange,g) 
			         and inRange(validSurfaceColours.b-validRange,validSurfaceColours.b+validRange,b))
			          then 
			            score = mapSize.weights.goodTerrain
			            if(DEBUG) then 
				            DebugWatch("r","goodTerrain")
				        end
			        end
			      end
			      if(score ~= mapSize.weights.goodTerrain ) then 
			        score = mapSize.weights.badTerrain
			      end
			    else

			      score = mapSize.weights.badTerrain
			    end  
			end
	    end 
	    return score
end

-------------------------------------------------------

function clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end -- swap if boundaries supplied the wrong way
    return math.max(lower, math.min(upper, val))
end

function math.sign(x) 
	if(x<0) then 
		return -1
	else
		return 1
	end

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
		if(tonumber(min) < tonumber(value) and tonumber(value)<=tonumber(max)) then 
			return true

		else
			return false
		end

end

function draw()


	if(not RACESTARTED and not RACECOUNTDOWN) then
		raceManager:drawIntro()
		-- DebugWatch("TRYING",RACECOUNTDOWN)
	end

	if(PATHSET and not RACEENDED) then 

		-- raceManager:testRect( )
		raceManager:driverNameDisplay()
		raceManager:draw()

	end


	if(raceManager.countdown > 0 and  raceManager.preCountdown <=0 ) then
		raceManager:drawStart()
	end
	
	for key,vehicle in pairs(aiVehicles) do 

		if(RACESTARTED and PLAYERRACING and key == playerConfig.car  and not playerConfig.finished and not RACEENDED and not DEBUGCONTROLLERS ) then
			raceManager:playerRaceStats(vehicle)
			-- DebugPrint(key.. " | "..playerConfig.car )
		elseif( PLAYERRACING and key == playerConfig.car and  RACEENDED) then
			raceManager:endScreen(vehicle)
		end
	end	

end

--nodes

--[[

* DESCRIPTION :
*       File that implements a node type structure for use in GNG/SNN networks 
*		

]]

node = {
	minID = -1,
	secondMinID = -1,
	MinDistance = 1000,
	secondMinDistance = 999,
	x = 0,
	y = 0,
	z = 0,
	value = 0,
	spriteColour = {1,1,0},
	GNconnect = Vec(0,0,0),
	GNnumber = 0,
	SNNpulse = 0,
	SNNstate = 0,
	SNNSum = 0,
	SNNNum = 0,
	threshold = 0.6,
	outputthreshold=0.2,
	SNNpsp    = 0 

}

function node:push(x,y,z,value)
	self.x, self.y, self.z, self.value = x,y,z,value
end

function node:growCluster(data)
	self.GNconnect = VecAdd(self.GNconnect,data)
	self.GNnumber = self.GNnumber +1
end

function node:updateCluster()
	
	if(self.GNnumber > 0 and VecLength(VecSub(self:getPos(),self.GNconnect))>0) then

		self.GNconnect = VecScale(self.GNconnect,(1/self.GNnumber))
	else
		self.GNconnect = VecCopy(self:getPos())
	end
	self:setPos(VecCopy(self.GNconnect))

	-- self.GNconnect = self:getPos()

	self.GNnumber = 0
	self.GNconnect = Vec(0,0,0)
end

function node:growPulse(inputData)
	self.SNNpulse = self.SNNpulse + inputData
	self.SNNSum = self.SNNSum + math.abs(inputData)
	self.SNNNum = self.SNNNum +1
end

function node:firePulse()
	if(self.SNNSum>0) then
		self.SNNstate = self.SNNpulse*(1/self.SNNSum) 
	else
		self.SNNstate = 0
	end
	-- if not self.SNNstate then 
	-- 	self.SNNstate = 0
	-- end
	-- local r = 1
	-- local g = 1
	-- local green = Vec(0,1,0)
	-- local red   = Vec(1,0,0)
	-- local output = VecLerp(green,red,self.SNNstate)
	DebugWatch("output",self.SNNstate)
	self.spriteColour =  {self:clamp(1-self.SNNstate,0,1), self:clamp(1*self.SNNstate,0,1),0}---{output[1],output[2],output[3]}
	-- if(self.SNNstate > self.threshold) then
	-- 	self.spriteColour  = {0,1,0}
	-- elseif(self.SNNstate > self.outputthreshold) then
	-- 	self.spriteColour  = {1,1,0}
	-- else
	-- 	self.spriteColour  = {1,0,0}
	-- end
	if(VecLength(self:getPos())==0) then
		self.spriteColour  = {1,0,0}
	end

	self.SNNpulse = 0
	self.SNNSum = 0
	self.SNNNum = 0
end


function node:computeNodeDistance(CentroidId,centroid)
	local dist = self:getDistance(centroid:getPos())
	if(dist<self.MinDistance) then
		self:setMinID(CentroidId)
		self:setMinDistance(dist)
	elseif(dist<self.secondMinDistance) then
		self:setSecondMinID(CentroidId)
		self:setSecondMinDistance(dist)
	end
end

function node:resetMins()
	self:setMinDistance(10000)
	self:setSecondMinDistance(10000)

	self:setMinID(-1)
	self:setSecondMinID(-1)
end

function node:getPos()
	return Vec(self.x,self.y,self.z)
end

function node:getDistance(altPos)
	return VecLength(VecSub(self:getPos(),altPos))
end

function node:loadSprite()
	self.sprite = LoadSprite("MOD/images/dot.png")
end
function node:showSprite()
	if(not IsHandleValid(self.sprite)) then
		DebugPrint("NO SPRITE FOUND")
	end
	spriteColour = {1,1,1}

	local t = Transform(self:getPos(), QuatEuler(0, GetTime(), 0))
	DrawSprite(self.sprite, t, 1, 1, self.spriteColour[1], self.spriteColour[2], self.spriteColour[3], 1)
	DebugWatch("spritePos",t)
	DebugWatch("clusterPos",self:getPos())
end
-----

 ---- getters

-----

function node:getMinDistance()
	return self.MinDistance 
end

function node:getSecondMinDistance()
	return self.secondMinDistance
end


function node:getMinID()
	return self.minID 
end
function node:getSecondMinID()
	return self.secondMinID 
end
--- 

 --- setters

---
function node:setPos(pos)
	self.x,self.y,self.z = pos[1],pos[2],pos[3]
end


function node:setMinDistance(dist)
	self:setSecondMinDistance(self.MinDistance)
	self.MinDistance = dist
end

function node:setSecondMinDistance(dist)
	self.secondMinDistance = dist
end

function node:setMinID(id)
	self:setSecondMinID(self.minID)
	self.minID = id
end
function node:setSecondMinID(id)
	self.secondMinID = id
end

---

  --- helpers

----

function node:clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end -- swap if boundaries supplied the wrong way
    return math.max(lower, math.min(upper, val))
end

--map nodes

--[[
         
*
* DESCRIPTION :
*       File that implements a structure to represent map nodes and scores
*		used for pathfinding 

]]

mapNode = {
	minID = -1,
	secondMinID = -1,
	MinDistance = 1000,
	secondMinDistance = 999,
	x = 0,
	y = 0,
	z = 0,
	baseCost = 0,
	validTerrain = false,
	spriteColour = {1,1,0},
	neighbors = {},
	maxVal = {},
	indexX = 0,
	indexY = 0,

}


function mapNode:push(x,y,z,value,t_indexY,t_indexX,validTerrain,maxVal)
	self.x, self.y, self.z, self.baseCost,self.indexX , self.indexY, self.validTerrain,self.maxVal = x,y,z,value,t_indexX,t_indexY,validTerrain,maxVal
	-- local index = 0
	for yVal=-1,1,1 do
		for xVal=-1,1,1 do
			-- index = 
			if(t_indexX + xVal >0 and  t_indexX + xVal < self.maxVal[1] and
				t_indexY + yVal >0 and  t_indexY + yVal < self.maxVal[2] and 
				not (xVal == 0 and yVal==0)) then 
				self.neighbors[#self.neighbors +1] = {
					x = t_indexX + xVal ,
					y = t_indexY + yVal ,

				} 
			end
		end
	end
end

function mapNode:getPos()
	return Vec(self.x,self.y,self.z)
end

function mapNode:getIndex()
	return  {self.indexX, self.indexY}
end


function mapNode:Equals(node)
	local nodeIndex = node:getIndex()
	if(self.indexX==nodeIndex[1] and self.indexY==nodeIndex[2])  then 

		return true
	else
		return false
	end
end


function mapNode:indexEquals(nodeIndex)
	if(self.indexX==nodeIndex[1] and self.indexY==nodeIndex[2])  then 

		return true
	else
		return false
	end
end

function mapNode:getDistance(altPos)
	return VecLength(VecSub(self:getPos(),altPos))
end


function mapNode:computeNodeDistance(CentroidId,centroid)
	local dist = self:getDistance(centroid:getPos())
	if(dist<self.MinDistance) then
		self:setMinID(CentroidId)
		self:setMinDistance(dist)
	elseif(dist<self.secondMinDistance) then
		self:setSecondMinID(CentroidId)
		self:setSecondMinDistance(dist)
	end
end

function mapNode:resetMins()
	self:setMinDistance(10000)
	self:setSecondMinDistance(10000)

	self:setMinID(-1)
	self:setSecondMinID(-1)
end


function mapNode:loadSprite()
	self.sprite = LoadSprite("MOD/images/dot.png")
end
function mapNode:showSprite()
	if(not IsHandleValid(self.sprite)) then
		DebugPrint("NO SPRITE FOUND")
	end
	spriteColour = {1,1,1}

	local t = Transform(self:getPos(), QuatEuler(0, GetTime(), 0))
	DrawSprite(self.sprite, t, 1, 1, self.spriteColour[1], self.spriteColour[2], self.spriteColour[3], 1)
	DebugWatch("spritePos",t)
	DebugWatch("clusterPos",self:getPos())
end


-----

 ---- getters

-----

function mapNode:getMinDistance()
	return self.MinDistance 
end

function mapNode:getSecondMinDistance()
	return self.secondMinDistance
end


function mapNode:getMinID()
	return self.minID 
end
function mapNode:getSecondMinID()
	return self.secondMinID 
end


function mapNode:getCost()
	return self.baseCost 
end

function mapNode:getNeighbors()
	return self.neighbors
end

--- 

 --- setters

---

function mapNode:setPos(pos)
	self.x,self.y,self.z = pos[1],pos[2],pos[3]
end


function mapNode:setMinDistance(dist)
	self:setSecondMinDistance(self.MinDistance)
	self.MinDistance = dist
end

function mapNode:setSecondMinDistance(dist)
	self.secondMinDistance = dist
end

function mapNode:setMinID(id)
	self:setSecondMinID(self.minID)
	self.minID = id
end
function mapNode:setSecondMinID(id)
	self.secondMinID = id
end

function mapNode:clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end -- swap if boundaries supplied the wrong way
    return math.max(lower, math.min(upper, val))
end

--Drive the vehicle to each node from closest to furthest using weights.
--Build a pathfinding system to navigate to the nodes with the lowest weight.
--Build a system to determine the weight of each node.
--Query raycast to check if the car can drive to the node safely.



