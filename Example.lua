local ServerStorage = game:GetService("ServerStorage");
local Module_Index = require(ServerStorage:WaitForChild("Module_Index"));

local DS = require(Module_Index["Generator_Modules"]["DiamondSquare"]);
local biomeSettings = require(Module_Index["Config"]["Biomes"]);

local Map_Generator = {};

local p_math = math;

-- Constructor
function Map_Generator:new(
	threshold,
	sizeX, sizeY,
	flatMap
	)

	local data = {};
	
	data.threshold = threshold or 0.1;
	data.sizeX = sizeX or 128;
	data.sizeY = sizeY or 128;
	if flatMap then
		data.flatMap = true;
	else
		data.flatMap = false;
	end
	
	local meta = setmetatable(data, self);
	self.__index = self;
	
	return meta;
end

--[[
	@getLowestPoint
		Returns the minimum value from the whole map.
		
		@Arguments <array> map
		@Returns <float> lowest
--]]
local function getLowestPoint(map)
	local lowest = p_math.huge;
	for i = 1, map.x, 1 do
		for j = 1, map.y, 1 do
			if (map[i][j] < lowest) then
				lowest = map[i][j];
			end
		end
	end
	return lowest;
end

--[[
	@getHighestPoint
		Returns the maximum value from the whole map.
		
		@Arguments <array> map
		@Returns <float> lowest
--]]
local function getHighestPoint(map)
	local highest = -p_math.huge;
	for i = 1, map.x, 1 do
		for j = 1, map.y, 1 do
			if (map[i][j] > highest) then
				highest = map[i][j];
			end
		end
	end
	return highest;
end

--[[
	@getHighestPointCoordinates
		Returns the highest point coordinates from the whole map.
		
		@Returns <vector> point
--]]
function Map_Generator:getHighestPointCoordinates(map)
	local max = -p_math.huge;
	local point = nil;
	for i = 1, map.x, 1 do
		for j = 1, map.y, 1 do
			if (map[i][j] > max) then
				max = map[i][j];
				point = Vector2.new(i, j);
			end
		end
	end
	return point;
end

--[[
	@getMaxOnTheEdge
		Returns the maximum value from the map edges.
		
		@Arguments <array> map
		@Returns <float> restrictPoint
--]]
local function getMaxOnTheEdge(map)
	local restrictPoint = -1000;
	for i = 1, map.x, 1 do
		local high = p_math.max(map[i][1], map[i][map.y]);
		if high > restrictPoint then
			restrictPoint = high;
		end
	end
	for i = 1, map.y, 1 do
		local high = p_math.max(map[1][i], map[map.x][i]);
		if high > restrictPoint then
			restrictPoint = high;
		end
	end
	return restrictPoint;
end

--[[
	@countBricksWithCondition
		Counts brick that are higher than the restrict point.
		
		@Arguments <array> map, <float> restrictPoint
		@Returns <int> bricks
--]]
local function countBricksWithCondition(map, restrictPoint)
	local bricks = 0;
	for i = 1, map.x, 1 do
		for j = 1, map.y, 1 do
			if map[i][j] > restrictPoint then
				bricks = bricks + 1;
			end
		end
	end
	return bricks;
end


--[[
	@cutLowerFlatten
		Cuts the map to fit the restricted area only (above restrict point).
		Points that are below or equal the restrict point are set to -1.
		
		If flatten is true, then all points that satisfy the condition are set to 0.
			
		Factor defines how much each point on the map is being multiplied by (moved it from Map Drawer).
		This makes the map look better as the differences in height are more visible.
		
		@Arguments <map> map, <map> restrict_map, <float> restrictPoint, <bool> flatten, <float> factor
--]]
local function cutLowerFlattenMultiply(map, restrict_map, restrictPoint, flatten, factor)
	local lowest = getLowestPoint(map);
	for i = 1, map.x, 1 do
		for j = 1, map.y, 1 do
			if restrict_map[i][j] > restrictPoint then
				if flatten then
					map[i][j] = 0
				else
					map[i][j] = (map[i][j] - lowest) * factor;
				end
			else
				map[i][j] = -1; -- means that this will not be generated
			end
		end
	end
end

--[[
	@getApproxAvgHeight
		Returns the approximated average height of the map.
		
		@Arguments <map> map
--]]
local function getApproxAvgHeight(map) 
	local sum = 0;
	for i = 1, 300, 1 do
		sum = sum + map[p_math.random(1, map.x)][p_math.random(1, map.y)];
	end
	return sum / 400; -- 400 is intentional to make the average point be lower a bit (for better looking results)
end

--[[
	@lowerByAvg
		Lowers the map so that the approximated average height point is at 0.
		
		@Arguments <map> map
--]]
local function lowerByAvg(map)
	local lowest = getApproxAvgHeight(map);
	for i = 1, map.x, 1 do
		for j = 1, map.y, 1 do
			map[i][j] = (map[i][j] - lowest);
		end
	end
end

--[[
	@lower
		Lowers the map so that the lowest point is at height 0.
		
		@Arguments <map> map
--]]
local function lower(map)
	local lowest = getLowestPoint(map);
	for i = 1, map.x, 1 do
		for j = 1, map.y, 1 do
			map[i][j] = (map[i][j] - lowest);
		end
	end
end

--[[
	@Clean
		Removes all lonely floating blocks (points on the map surrounded by void)
		
		@Arguments <map> map
--]]
function Clean(map)
	-- theese loops check inside the map, the edge is omitted (anyways the generator never uses the edge so it is not necessary to check it)
	for i = 2, map.x - 1, 1 do
		for j = 2, map.y - 1, 1 do
			if map[i][j] ~= -1 then
				local A, B, C, D = map[i - 1][j], map[i][j - 1], map[i + 1][j], map[i][j + 1]
				if A == -1 and B == -1 and C == -1 and D == -1 then
					map[i][j] = -1;
				end
			end
		end
	end
end

--[[
	@Create
		Generates the map or returns false if generation failed (due to brick threshold condition).
--]]
function Map_Generator:Create(biome)
	local setA = biomeSettings[biome].GeneratorAlphaSettings;
	local setB = biomeSettings[biome].GeneratorBetaSettings;
	local factor = biomeSettings[biome].GeneratorMultiplyFactor;
	
	local map = DS.Generate(self.sizeX, self.sizeY, unpack(setA));
	local map2 = DS.Generate(self.sizeX, self.sizeY, unpack(setB));
	
	local maxBricks = map.x * map.y;
	local restrictPoint = getMaxOnTheEdge(map2);
	local bricks = countBricksWithCondition(map2, restrictPoint);
	
	cutLowerFlattenMultiply(map, map2, restrictPoint, self.flatMap, factor);
	Clean(map);
	
	if (bricks/maxBricks < self.threshold) then
		return false;
	else
		map.Biome = biome;
		map.BrickCount = bricks;
		
		map.HighestValue = getHighestPoint(map);
		map.AverageValue = getApproxAvgHeight(map);
		map.LowestValue = getLowestPoint(map);
		return map;
	end
end

--[[
	@Generate
		Generates the map or returns false if generation failed (due to brick threshold condition).
--]]
function Map_Generator:Generate(biome)
	if biome == nil then
		error("Biome value is nil");
	end
	if not biomeSettings[biome] then
		error("Biome " .. biome .. " does not exist.");
	end
	while wait() do 
		local map = self:Create(biome);
		if map then
			map.threshold = self.threshold;
			return map;
		end
	end
end

--[[
	@DSRawGenerate
		Returns the map directly from Diamond-Square without any modification nor restriction.
		Uses biome settings.
--]]
function Map_Generator:DSRawGenerate(biome)
	local setA = biomeSettings[biome].GeneratorAlphaSettings;
	local map = DS.Generate(self.sizeX, self.sizeY, unpack(setA));
	lowerByAvg(map);
	map.HighestValue = getHighestPoint(map);
	map.AverageValue = getApproxAvgHeight(map);
	map.LowestValue = 0;
	return map;
end

return Map_Generator;
