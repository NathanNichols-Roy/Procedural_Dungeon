-- main.lua

--=================================================
-- Housekeeping 
--=================================================
display.setStatusBar(display.HiddenStatusBar)

local centerX = display.contentCenterX
local centerY = display.contentCenterY
--=================================================
-- Forward References 
--=================================================

-- Functions
local setPath
local getPath
local movePlayer
local stopPlayer
local newRoom
local points
local connectRooms
local prims

-- Variables
local width = 40
local height = 40
local cellSize = 16
local sizemin = 2
local sizemax = 9
local startPoint
local endPoint
local map = {}
local player
local isMoving
local roomList = {}

-- game display group (camera)
local game = display.newGroup()
game.x = 0


--=================================================
-- Jumper Library setup
--=================================================

local Grid = require ("jumper.grid")  -- The grid class
local Pathfinder = require ("jumper.pathfinder") -- The pathfinder class

--=================================================
-- Delaunay Library setup
--=================================================

local Delaunay = require ("delaunay.delaunay")
local Point = Delaunay.Point
local Edge = Delaunay.Edge

--=================================================
-- Utility functions
--=================================================

local function gridXYFromPixelXY(x,y)
	local pos = {}
	pos.x = math.floor((x)/cellSize) 
	if pos.x < 1 then pos.x = 1 end
	pos.y = math.floor((y)/cellSize) 
	if pos.y < 1 then pos.y = 1 end
	return pos
end

local function pixelXYFromGrid (x, y)
	local pos = {}
	pos.x = math.floor((x)*cellSize)
	pos.y = math.floor((y)*cellSize) 
	return pos
end

-- runs in O(n²)...
local function removeDuplicates(point)
	local duplicates = {}
	
	for i = 1, #point.adj do
		if (i < #point.adj) then
			for j = i + 1, #point.adj do
				if(point.adj[i].x == point.adj[j].x and point.adj[i].y == point.adj[j].y) then
					duplicates[#duplicates + 1] = j
				end
			end
		end
	end
	
	-- Sort table
	table.sort(duplicates)
	-- Remove duplicates from back to front to ensure correct order
	for i = #duplicates, 1, -1 do
		table.remove(point.adj, duplicates[i])
	end
end

local function getDist(p1, p2)
	return p1:dist(p2)
end

local function entryExists (tab, entry)
	for i = 1, #tab do
		if (entry == tab[i]) then
			return true
		end
	end
	return false
end

local function randomize (percent)
	math.randomseed(os.time())
	
	if(math.random(1, 100) > percent) then
		return false
	else
		return true
	end
end

local function walkables (value)
	if (value > 0 and value < 5) then
		return true
	else
		return false
	end
end

--=================================================
-- Create room corridors
-- Using pathing from center point of one room to another
--=================================================
local function buildCorridor(startX, startY, endX, endY)
	local diggerNodes
	local diggerSteps = {}
	local startPos = {}
	local endPos = {}
	startPos.x = startX
	startPos.y = startY
	endPos.x = endX
	endPos.y = endY
	
	diggerNodes = getPath(startPos, endPos)
	if (diggerNodes ~= nil) then
		-- Get x,y steps for corridor digger
		for node, count in diggerNodes do
			diggerSteps[#diggerSteps + 1] = { x = node.x, y = node.y }
		end
		
		if(#diggerSteps > 1) then
			for i = 1, #diggerSteps do
				map[diggerSteps[i].y][diggerSteps[i].x] = 2
			end
		
		end
	else
		print("DiggerPath NOT FOUND")
	end
end
--=================================================
-- Create the grid map
-- Tap event on tiles to set end position of path
-- 0 = walkable
-- 1 = wall
-- 3 = door
--=================================================
local function drawMap()
	math.randomseed(os.time())
	-- Random number of rooms
	numRooms = math.random(10, 20)
	print(("There are %d rooms on this floor") :format(numRooms))
	for i = 1, numRooms do
		newRoom()
	end
	-- Create blank map
	for row = 1, height do
		local gridRow = {}
		for col = 1, width do
			gridRow[col] = 1
		end
		map[row] = gridRow
	end
	
	-- Fill map with rooms
	local function buildRoom(x1, y1, x2, y2)
		for row = y1, y2 do
			for col = x1, x2 do
				map[row][col] = 2
			end
		end
	end
	
	for i = 1, #roomList do
		buildRoom(roomList[i].x1,
				  roomList[i].y1,
				  roomList[i].x2,
				  roomList[i].y2)
	end

	local points = points()
	local triangles = triangles(points)
	prims(triangles, points)
	
	for row = 1, height do
		for col = 1, width do
			-- Import tile sheet
			-- frames: 1 = wall 2 = tile 3 = door
			local tileSheet = graphics.newImageSheet( "art/tileSheet.png", { width = 16, height = 16, numFrames = 3 })
			
			local tile
			-- Draw walls/objects
			if (map[row][col] == 1) then
				tile = display.newImage( tileSheet, 1 )
				map[row][col] = 0
			elseif (map[row][col] == 3) then
				tile = display.newImage( tileSheet, 3 )
			elseif (map[row][col] == 2) then
				tile = display.newImage( tileSheet, 2 )
			end
			-- insert into game display group at bottom (1)
			game:insert( 1, tile )
			tile.x = col * cellSize
			tile.y = row * cellSize
			-- Set the tile's pixel coordinates
			tile.xyPixelCoordinate = {x = tile.x, y = tile.y}
			-- Set the tile's Grid coordinates
			tile.xyGridCoordinate = {x = col, y = row}			

			tile:addEventListener ( "tap", setPath )
		end
	end
	

end

-- Set starting position and ending position
function setPath(event)

	-- If moving, stop player
	if (isMoving) then
		stopPlayer()
	else	
		local obj = event.target

		if(not endPoint) then
			endPoint = display.newText( "b", obj.x, obj.y, native.systemFont, 5 )
			game:insert( 5, endPoint )
			endPoint.xyGridCoordinate = { x = obj.xyGridCoordinate.x, y = obj.xyGridCoordinate.y }
		else
			endPoint.x = obj.x
			endPoint.y = obj.y

			endPoint.xyGridCoordinate.x = obj.xyGridCoordinate.x
			endPoint.xyGridCoordinate.y = obj.xyGridCoordinate.y
		end
		
		local startPos = gridXYFromPixelXY(player.x,player.y)
		local endPos = endPoint.xyGridCoordinate
		player.pathNodes = getPath(startPos, endPos)
		if(player.pathNodes ~= nil) then
			movePlayer()
		end
		return true
	end
end

--=================================================
-- Compute path from startPos to endPos
--=================================================

function getPath(startPos, endPos)
	local startx, starty = startPos.x, startPos.y
	local endx, endy = endPos.x, endPos.y

	-- value for walkable tiles
	local walkable = 0
	-- Create a grid object
	local grid = Grid(map)
	-- Create a pathfinder object using Jump Point Search
	local pather = Pathfinder (grid, 'JPS', walkables)
	pather:setMode( 'ORTHOGONAL' )

	-- Calculate the path and its length
	local path = pather:getPath(startx, starty, endx, endy)
	
	if path then 
		--print (('Path found! Length: %.2f'):format(path:getLength()))
		
		-- Store each path node into table
		if (path:getLength() > 0) then
			path:fill()
		end
		--player.pathNodes = path:nodes()
	else
		print ('Path not found!')
		return nil
	end
	return path:nodes()
end

--=================================================
-- Move player from point to point until
-- completed full path
--=================================================

function movePlayer()
	-- Init table for pathing steps
	player.pathSteps = {}
	player.index = 2
	
	for node, count in player.pathNodes do
		--print (('Step: %d - x: %d - y: %d'):format(count, node.x, node.y))
		player.pathSteps[#player.pathSteps+1] = { x = node.x, y = node.y }
	end

	if (#player.pathSteps > 1) then
		local function nextStep()
			isMoving = true
			if (player.index < #player.pathSteps+1) then
				local pos = pixelXYFromGrid( player.pathSteps[player.index].x, player.pathSteps[player.index].y )
				transition.to( player, { time = 200, x = pos.x, y = pos.y, onComplete = nextStep })
				player.index = player.index + 1
			else
				-- after path finished set isMoving to false
				isMoving = false
			end
		end
		nextStep()
	end
end

--=================================================
-- Camera Control
--=================================================
--local function lockedCamera( target, world )
	--world.lx = target.x
	--world.ly = target.y

-- Controls the game layer (camera)
local function moveCamera()
	game.x = -player.x + (display.contentCenterX)
	game.y = -player.y + (display.contentCenterY)
		--local dx = target.x - world.lx
		--local dy = target.y - world.ly
		
		--if(dx or dy) then
		--	world:translate(-dx, -dy)
		--	world.lx = target.x
		--	world.ly = target.y
		--end
end
	Runtime:addEventListener( "enterFrame", moveCamera )
--end


--=================================================
-- Halt player if already in movement
--=================================================
function stopPlayer()
	for i = 1, #player.pathSteps do
		player.pathSteps[i] = nil
	end
end


--=================================================
-- Room function to detect room collision
--=================================================

local function checkCollision(t1, t2)
	-- If collision return true
	-- Added extra 'padding' on rooms to ensure rooms are not adjacent
	if(t1.x1-1 < t2.x2+1 and
	   t1.x2+1 > t2.x1-1 and
	   t1.y1-1 < t2.y2+1 and
	   t1.y2+1 > t2.y1-1) then
	   return true
	else
		return false
	end
end

--=================================================
-- Function to create rooms
--=================================================
-- room constructor
function newRoom()

	local x1, y1, x2, y2
	local midx, midy
	
	-- top left corner of room
	x1 = math.random (2, width-(sizemax+1))
	y1 = math.random (2, height-(sizemax+1))
	
	-- bottom right corner of room
	x2 = x1 + math.random (sizemin, sizemax)
	y2 = y1 + math.random (sizemin, sizemax)
	
	midx = math.round((x1 + x2)/2)
	midy = math.round((y1 + y2)/2)

	roomList[#roomList + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, midx = midx, midy = midy }
		
	--Check for collisions
	if (#roomList > 1) then
		for i = 1, #roomList - 1 do
			if(checkCollision(roomList[i], roomList[#roomList])) then
				-- If there is a collision
				-- remove last room from the list and redo
				table.remove(roomList)
				newRoom()
			end
		end
	end

end

--=================================================
-- Delaunay Triangulation
-- Used to create room connections
--=================================================
function triangles(points)
	-- triangulate points
	local triangles = Delaunay.triangulate(unpack(points))
	return triangles
end

-- Generate points for triangulation from room midpoints
function points()
	local points = {}
	for i = 1, #roomList do
		points[i] = Point(roomList[i].midx, roomList[i].midy)
		-- create adjacency lists for all points
		points[i].adj = {}
		print('Room ' .. i ..': (' .. roomList[i].midx .. ',' .. roomList[i].midy .. ')')
	end
	return points
end

--=================================================
-- Prims Algorithm
-- Used to create minimum spanning tree
--=================================================
function prims(t, points)
	-- keep track of vertices already in mst
	local mst = {}
	-- keep track of edges in mst
	local edges = {}
	-- update all adjacency lists
	for i = 1, #t do
		t[i].p1.adj[#t[i].p1.adj + 1] = t[i].p2
		t[i].p1.adj[#t[i].p1.adj + 1] = t[i].p3
		
		t[i].p2.adj[#t[i].p2.adj + 1] = t[i].p1
		t[i].p2.adj[#t[i].p2.adj + 1] = t[i].p3
		
		t[i].p3.adj[#t[i].p3.adj + 1] = t[i].p1
		t[i].p3.adj[#t[i].p3.adj + 1] = t[i].p2
	end

	for i = 1, #points do
		removeDuplicates(points[i])
	end
	
	-- First vertex
	mst[1] = points[1]

	-- Create MinimumSpanningTree
	while (#mst ~= #points) do
		local startPoint
		local entry
		local minDist = 10000
		for i = 1, #mst do
			for j = 1, #mst[i].adj do
				-- if distance from point to point in adj list is less than min
				-- and if adj point is not already in MST
				local distance = getDist(mst[i], mst[i].adj[j])
				if (distance < minDist and entryExists(mst, mst[i].adj[j]) == false) then
					minDist = distance
					startPoint = mst[i]
					entry = mst[i].adj[j]
				end
			end
		end
		edges[#edges + 1] = { startPoint = startPoint, endPoint = entry }
		local line = display.newLine(game, startPoint.x*16, startPoint.y*16, entry.x*16, entry.y*16)
		local miniline = display.newLine(game, startPoint.x, startPoint.y, entry.x, entry.y)
		-- Make hallways
		buildCorridor(startPoint.x, startPoint.y, entry.x, entry.y)
		-- add next closest point to mst
		mst[#mst + 1] = entry
	end
	
	local function addLoops(edges, points)
		local count = 0
		local loops = {}
		-- total number of paths
		local paths = 0
		-- percent of edges to keep from delaunay triangulation
		local percent = 0.15
		
		for i = 1, #points do
			for j = 1, #points[i].adj do
				paths = paths + 1
			end
		end
		print('Total Num Paths: ' .. paths)
		
		paths = math.round(percent * paths)
		print('Num Paths to keep: ' .. paths)
		
		--while count < paths do
			local randPoint = math.random(#points)
			local randPath = math.random(#points[randPoint].adj)
			
			if(entryExists(edges, points[randPoint].adj[randPath]) == false) then
				startPoint = points[randPoint]
				endPoint = points[randPoint].adj[randPath]
				count = count + 1
				print("Keeping Edge")
				print(points[randPoint])
				print(points[randPoint].adj[randPath])
			end
		--end
	end	
	
	addLoops(mst, points)
end
--=================================================
-- Setup display and run the game
--=================================================

function runGame()
	-- Add Player
	local playerSheet = graphics.newImageSheet( "art/playerSheet.png", { width = 16, height = 16, numFrames = 7 })
	player = display.newImage( playerSheet, 1, display.contentCenterX, display.contentCenterY )
	player.xyGridCoordinate = { x = 1, y = 1 }
	-- insert into game display obj at top
	game:insert( 20,  player )
	
	drawMap()

	--lockedCamera( player, game )
end


runGame()