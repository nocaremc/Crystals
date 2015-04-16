local NKPhysics = include("Scripts/Core/NKPhysics.lua")

-------------------------------------------------------------------------------
-- Container class that stores data for evaluating/processing growth of an
-- object.
if (GrowableData == nil) then
	GrowableData = Class.Subclass("GrowableData")
	
	GrowableData.m_decayWhenFinished = true
	GrowableData.m_formCount = 0
	GrowableData.m_growableMaterialName = ""
	GrowableData.m_checkForTerrain 	= false
	GrowableData.m_checkForMaterial = false
	GrowableData.m_bodyToCheck = "none"
	GrowableData.m_minGrowthTime = 0
	GrowableData.m_maxGrowthTime = 2400
	GrowableData.m_clearanceRadius = 0.0
	GrowableData.m_numAllowedObjectsInRange = 0
	GrowableData.m_ignoreObject = nil -- Object that should be ignored by the
									  -- growth condition checks.
end


-------------------------------------------------------------------------------
function GrowableData:Constructor( args )
	--Read controller variables.
	
	if (args.decayWhenFinished ~= nil) then
		if(args.decayWhenFinished == 0) then
			self.m_decayWhenFinished = false
		else
			self.m_decayWhenFinished = true
		end
	else
		self.m_decayWhenFinished = false
	end
	
	if (args.States ~= nil) then
		--Read form data.
		self.m_forms = {}
		self.m_formCount = 0
		for stateNum, stateTable in pairs(args.States) do
			self.m_forms[tonumber(stateNum)] = {}
			self.m_forms[tonumber(stateNum)].objectName 			= stateTable.objectName
			self.m_forms[tonumber(stateNum)].growthDuration 		= stateTable.growthTime
			self.m_forms[tonumber(stateNum)].beginningScale 		= stateTable.beginningScale
			self.m_forms[tonumber(stateNum)].endingScale 			= stateTable.endingScale
			self.m_forms[tonumber(stateNum)].emitterName 			= stateTable.emitterName
			
			if (stateTable.childToDisable ~= nil) then
				self.m_forms[tonumber(stateNum)].childToDisable = stateTable.childToDisable
			end
			
			if (stateTable.activatePhysics ~= nil) then
				if(stateTable.activatePhysics == 0) then
					self.m_forms[tonumber(stateNum)].activatePhysics = false
				else
					self.m_forms[tonumber(stateNum)].activatePhysics = true
				end
			else
				self.m_forms[tonumber(stateNum)].activatePhysics = false
			end
			
			if (stateTable.pickable ~= nil) then
				if(stateTable.pickable == 0) then
					self.m_forms[tonumber(stateNum)].isPickable = false
				else
					self.m_forms[tonumber(stateNum)].isPickable = true
				end
			else
				self.m_forms[tonumber(stateNum)].isPickable = false
			end
			
			self.m_formCount = self.m_formCount + 1
		end
	end
	
	-- TODO: Add logic here for parsing conditionals.
	-- Can mix growable conditions into this if necessary.
	-- If we do that, we're gonna have to be careful about how
	-- we return info in the Grow function.
	
	if (args.checkForTerrain ~= nil) then
		if (args.checkForTerrain == 1) then
			self.m_checkForTerrain = true
		else
			self.m_checkForTerrain = false
		end
	end
	
	-- Defaults to no material.
	if (args.growableMaterialName ~= nil) then
		self.m_growableMaterialName = args.growableMaterialName
		self.m_checkForMaterial = true
		self.m_checkForTerrain = true
	end
	
	-- Defaults to none.
	if (args.bodyToCheck ~= nil) then
		local lowerBody = string.lower(args.bodyToCheck)
		if (lowerBody == "sun" or lowerBody == "moon") then --No matching type.
			self.m_bodyToCheck = lowerBody
		end
	end
	
	-- Defaults to 0.
	if (args.minimumGrowthTime ~= nil) then
		self.m_minGrowthTime = args.minimumGrowthTime
	end
	
	-- Defaults to 2400.
	if (args.maximumGrowthTime ~= nil) then
		self.m_maxGrowthTime = args.maximumGrowthTime
	end
	
	-- Defaults to 0.
	if (args.clearanceRadius ~= nil) then
		self.m_clearanceRadius = args.clearanceRadius
	end
	
	-- Create detach signal.
	self.m_detachSignal = NKUtils.CreateSignal()
	self.m_storedDetachCallback = nil
end

-------------------------------------------------------------------------------
-- Attempt to grow to a specific form. 
-- @Param form - The form to grow to.
-- @Param obj  - The object to pull transform data from.  This will either be 
--				 the starter (should never have parent), or the previous form 
--				 (in which case, this object should inherit its parent).  Note
--				 that this object will automatically be added to
--				 ignoredObjects.
-- @Param ignoredObjects - A table containing any other objects that should
--						   be ignored by growth condition checks.
-- @Returns GameObject - The object grown.
function GrowableData:Grow( form, obj, ignoredObjects )
	if (ignoredObjects == nil) then
		ignoredObjects = {}
	end
	table.insert(ignoredObjects,obj)
	local canGrow = 0
	-- Growth conditions only apply to forms after the first.
	if (form ~= 1) then
		canGrow = self:CheckConditions(obj, ignoredObjects)
	end
	self.m_ignoreObject = nil
	if (canGrow ~= 0) then
		return nil
	end
	
--	NKPrint("Passed growth conditions.\n")
	if (self.m_formCount >= form) then
		local newObjName = self.m_forms[form].objectName
		local newObj = Eternus.GameObjectSystem:NKCreateNetworkedGameObject(newObjName, true)
		if (newObj ~= nil) then
			local growArgs = {}
			growArgs.data = self
			growArgs.prevForm = obj:NKGetInstance()
			if (growArgs.prevForm == nil) then
			    NKError("Trying to grow " .. newObjName .. " from " .. obj:NKGetName() .. ", but " .. obj:NKGetName() .. " has no script!\n")
			    return nil
			end
			
			local newObjInst = newObj:NKGetInstance()
			
			
			-- Parenting is handled in the Growable's init function, as well as
			-- transform syncing and physics settings.
			newObjInst:InitializeGrowable(form, growArgs)
			
			return newObj
		else
			NKError("Growable starter could not create object of type " .. newObjName .. "\n")
			return nil
		end
		
	else
		NKError("Attempting to grow from object: " .. obj:NKGetName() .. " with form " .. tostring(form) .. " but this controller only has " .. tostring(self.m_formCount) .. " forms!\n")
		return nil
	end
	
	return nil
end

-------------------------------------------------------------------------------
-- Checks growth conditions for obj and returns if and, if applicable, how
-- the check failed.
-- @Param obj - The object to check growth conditions for.  This will normally
--				be the growable that holds this object.
-- @Param ignoredObjects - A list of objects to be ignored when checking growth
--						   conditions.
-- @Returns int - 0 if the check passed, a higher number otherwise.  
--					1 - Failed time of day check.
--					2 - Failed material check.
--					3 - Failed trace to sun/moon.
--					4 - Failed clearance radius check.
function GrowableData:CheckConditions( obj, ignoredObjects )
	local location = obj:NKGetWorldPosition()
	
	-- Time check.
	local curTime = Eternus.World:NKGetMilitaryTime()
	if (self.m_minGrowthTime <= self.m_maxGrowthTime) then
		if (not (curTime >= self.m_minGrowthTime and curTime <= self.m_maxGrowthTime)) then
			--self.m_debugMessage = "Failed growth condition: Current time outside growth period."
			--NKPrint("--= Failed Growth Check: Incorrect time period.\n") 
			return 1
		end
	else
		if (not (curTime >= self.m_minGrowthTime or curTime <= self.m_maxGrowthTime)) then
			--self.m_debugMessage = "Failed growth condition: Current time outside growth period."
			--NKPrint("--= Failed Growth Check: Incorrect time period.\n")
			return 1
		end
	end
	
	-- Check to make sure the voxel below is the correct voxel.
	if (self.m_checkForTerrain == true) then
		local canPassMatCheck = true
		local origin = location + vec3.new(0.0, 0.5, 0.0)
		local direction = vec3.new(0.0, -1.0, 0.0)
		local distance = 1.0
		
		--Only check if we have a name.  If we don't pass this check automatically.
		local hits = NKPhysics.RayCastCollectAll(origin, direction, distance, ignoredObjects)
				
		if (hits) then
			for key, hit in pairs(hits) do
				if (hit.gameobject == nil) then --hit a voxel
					local objHeight = location:y()
					local traceHeight = hit.queryPosition:y()
					local diff = math.abs(objHeight - traceHeight)
					if (diff > 0.25) then
						--self.m_debugMessage = "Failed growth condition: Object not touching terrain."
						--NKPrint("--= Failing growth: Object not touching terrain.\n")
						return 2
					end
					
					local matType = hit.matID
					
					-- Note that this COULD behave strangely for objects that require a voxel, but no material
					-- could still fail depending on the order things happen in.  This will be fixed when
					-- the ignored objects list in the ray cast is fixed.
					if (self.m_checkForMaterial) then
						local matName = Eternus.GameObjectSystem:NKGetPlaceableMaterialByID(matType):NKGetName()
						if (self.m_growableMaterialName ~= "" and matName ~= self.m_growableMaterialName) then
							--self.m_debugMessage = "Failed growth condition: Object not planted on correct material."
							--NKPrint("--= Failing growth: Hit object mat name: " .. matName .. " does not match " .. self.m_growableMaterialName .. "\n")
							return 2
						end
					end
					
					canPassMatCheck = true
					break
				else
					canPassMatCheck = false
					--self.m_debugMessage = "Failed growth condition: Object placed above another object."
					--NKPrint("--= Might fail growth: Found object: " .. hit.gameobject:NKGetName() .. " below growable.\n")
					--return 3
				end
			end
		else
			self.m_debugMessage = "Failed growth condition: No ground below object."
			--NKPrint("--= Failed growth check: No ground below object.\n")
			return 2 -- No hits
		end
		
		if (not canPassMatCheck) then
			--NKPrint("--= Failed growth check: Object below growable.\n")
			return 2 --We MUST actually find the correct voxel to pass.  Its possible to hit
				 --just the seed object and NOT the voxel, and still reach this point.
		end
	end
	
	-- Voxel below check has passed.  Now we trace the sun/moon.  Or not.  One of the three.
	-- Pass automatically if we don't have sun/moon specified.
	if (self.m_bodyToCheck ~= "none") then
		local direction = Eternus.World:NKGetSunPosition()
		if (self.m_bodyToCheck == "moon") then
			direction = vec3.new(-direction:x(), -direction:y(), -direction:z())
		end
		origin = location + vec3.new(0.0, 1.0, 0.0)
		distance = 100
		hits = NKPhysics.RayCastCollectAll(origin, direction, distance, ignoredObjects)
		
		if (hits) then
			for key, hit in pairs(hits) do
				if	(hit.gameobject == nil) then
					--NKPrint("--= Failed growth check: Terrain between object and " .. self.m_bodyToCheck .. "\n")
					return 3 -- Hit terrain.  Bail.
				end
			end
		end
	end
	
	--Checking space stuff up here for testing.
	if (self.m_clearanceRadius > 0.0) then
		local itemTab = Eternus.GameObjectSystem:NKGetGameObjectsInRadius(location, self.m_clearanceRadius, "all", true)
		
		local numObjectsInRange = #itemTab
		
		--We allow for only one object to be in range, this is this object itself.
		if (numObjectsInRange > self.m_numAllowedObjectsInRange) then
			local counter = 0
			local objList = ""
			
			-- The distance cap is here to try and remedy an issue where objects are erroneously caught in the 2.5
			-- clearance area because their AABBs are large despite them not actually being visually near the growable.
			-- We throw out any collisions that are not physically near the growable but still end up in the list to
			-- try and avoid these large objects causing false positives.
			local objDistCap = (self.m_clearanceRadius*4.0)
			
			for key,value in pairs(itemTab) do
				if (not self:IsValueIgnored(value, ignoredObjects)) then
					-- Now check literal distance.
					local objLoc = value:NKGetWorldPosition()
					local dist = (location - objLoc):length()
					
					if (dist <= objDistCap) then
						counter = counter + 1
						objList = objList .. " --= " .. value:NKGetName() .. "\n"
					else
						--NKPrint("--= Discarding " .. value:NKGetName() .. " from interfering objects due to distance: " .. tostring(dist) .. "\n")
					end
				end
				
			end
			
			self.m_debugMessage = "Failed growth condition: Too many objects within range of " .. tostring(self.m_clearanceRadius) .. "\nFound:\n" .. objList .. "\nTotal " .. tostring(numObjectsInRange) .. "\nAllowed " .. tostring(self.m_numAllowedObjectsInRange) .. " objects.\n"
			if (counter > self.m_numAllowedObjectsInRange) then
				--NKPrint("--= Failed growth check: Too many objects in range: \n" .. objList .. "--===--\n")
				return 4
			end
		end
	end
	
	return 0
end

-------------------------------------------------------------------------------
-- Sets a pointer to an object that should be ignored in growth condition
-- checks.
function GrowableData:SetIgnoreObject( ignoreObject )
	self.m_ignoreObject = ignoreObject
end


-------------------------------------------------------------------------------
-- Check a list to see if the given value is in it.  This is used by the
-- objects in range check to verify if an item found in range is on the ignore
-- list.
-- @Param obj 			 - The value to be checked for in the list.
-- @Param ignoredObjects - The list of objects to search in.
function GrowableData:IsValueIgnored( obj, ignoredObjects )
	for key, value in pairs(ignoredObjects) do
		if (obj == value) then
			return true
		end
	end
	
	return false
end


-------------------------------------------------------------------------------
function GrowableData:RegisterDetachCallback( callback )
	self.m_detachSignal:Add(callback)
	self.m_storedDetachCallback = callback
end


-------------------------------------------------------------------------------
function GrowableData:FireDetachCallback( obj )
	self.m_detachSignal:Fire(obj)
	if (self.m_storedDetachCallback) then
		self:UnregisterDetachCallback(self.m_storedDetachCallback)
	end
end


-------------------------------------------------------------------------------
function GrowableData:UnregisterDetachCallback( callback )
	self.m_detachSignal:Remove(callback)
end


-------------------------------------------------------------------------------
function GrowableData:Save( outData )
	outData.growableMaterialName 	= self.m_growableMaterialName
	outData.bodyToCheck 			= self.m_bodyToCheck
	outData.minimumGrowthTime 		= self.m_minGrowthTime
	outData.maximumGrowthTime 		= self.m_maxGrowthTime
	outData.clearanceRadius 		= self.m_clearanceRadius
	
	if (self.m_checkForTerrain) then
		outData.checkForTerrain = 1
	else
		outData.checkForTerrain = 0
	end
	
	if (self.m_decayWhenFinished) then
	    outData.decayWhenFinished = 1
	else
	    outData.decayWhenFinished = 0
	end
	
	outData.States = {}
	for index, formTable in pairs(self.m_forms) do
		-- Note that index here is a number, but needs to be stored in States
		-- as a string.
		local ind = tostring(index)
		outData.States[ind] = {}
		outData.States[ind].objectName 		= formTable.objectName
		outData.States[ind].growthTime	 	= formTable.growthDuration
		outData.States[ind].beginningScale 	= formTable.beginningScale
		outData.States[ind].endingScale 	= formTable.endingScale
		outData.States[ind].emitterName 	= formTable.emitterName
		
		if (formTable.activatePhysics) then
			outData.States[ind].activatePhysics = 1
		else
			outData.States[ind].activatePhysics = 0
		end
		
		if (formTable.isPickable) then
			outData.States[ind].pickable = 1
		else
			outData.States[ind].pickable = 0
		end
	end
end

return GrowableData