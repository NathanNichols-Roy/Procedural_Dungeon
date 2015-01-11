--levelGeneration.lua

--=================================================
-- Variables
--=================================================
local width = 50
local height = 50
local sizemin = 3
local sizemax = 9


-- Room class
local room = {}
room.List = {}

--=================================================
-- PRIVATE
-- Function to detect room collision
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

local function createDoor(room)
	-- Pick a side to connect to
	side = math.random(4)
	
	local door
	-- north
	if (side == 1) then
		door.x = math.random(room.x1, room.x2)
		door.y = room.y1
	-- east
	elseif (side == 2) then
		door.x = room.x2
		door.y = math.random(room.y1, room.y2)
	-- south
	elseif (side == 3) then
		door.x = math.random(room.x1, room.x2)
		door.y = room.y2
	-- west
	elseif (side == 4) then
		door.x = room.x1
		door.y = math.random(room.y1, room.y2)	
	end
end
--=================================================
-- PUBLIC
-- Function to create rooms
--=================================================
-- room constructor
function room.new()

	local x1, y1, x2, y2

	-- top left corner of room
	x1 = math.random (2, width-(sizemax+1))
	y1 = math.random (2, height-(sizemax+1))
	
	-- bottom right corner of room
	x2 = x1 + math.random (sizemin, sizemax)
	y2 = y1 + math.random (sizemin, sizemax)

	room.List[#room.List + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
	
	print('(' .. x1 .. ',' .. y1 .. ')' .. ' ' .. '(' .. x2 .. ',' .. y2 .. ')' )
	
	--Check for collisions
	if (#room.List > 1) then
		for i = 1, #room.List - 1 do
			if(checkCollision(room.List[i], room.List[#room.List])) then
				print("Room " .. #room.List .. " collides with room " .. i)
				-- If there is a collision
				-- remove last room from the list and redo
				table.remove(room.List)
				room.new()
			end
		end
	end

	
end


return room
