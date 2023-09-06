
AnimalFoodCalculator = {}
AnimalFoodCalculator.name = g_currentModName
AnimalFoodCalculator.modDir = g_currentModDirectory
AnimalFoodCalculator.useEas = false


function AnimalFoodCalculator:onListSelectionChanged(husbandry, cluster)	
	local overallMonthly = 0
	local overallYearly = 0
	
	for _, cluster in pairs(self.selectedHusbandry:getClusters()) do
		local monthly, yearly = AnimalFoodCalculator:calcFoodPerCluster(cluster)
		overallMonthly = overallMonthly + monthly
		overallYearly = overallYearly + yearly
	end
	
	local daysPerMonth = g_currentMission.environment.daysPerPeriod
	
	local firstRun = (self.dailyFoodLabel == nil)
	
	if firstRun then
		self.dailyFoodLabel = self.foodHeader:clone()
		self.dailyFoodLabel.textAutoWidth = false
		self.yearlyFoodLabel = self.foodHeader:clone()	
		self.yearlyFoodLabel.textAutoWidth = false
	end
	
	
	if firstRun then
		self.requirementsLayout:addElement(self.dailyFoodLabel)
		self.requirementsLayout:addElement(self.yearlyFoodLabel)
	end
	
	
	self.dailyFoodLabel:setText(AnimalFoodCalculator:getText("AFC_DailyLabel") .. ": " .. g_i18n:formatVolume(overallMonthly/daysPerMonth, 0))
	self.yearlyFoodLabel:setText(AnimalFoodCalculator:getText("AFC_YearlyLabel") .. ": " .. g_i18n:formatVolume(overallYearly, 0))
	self.requirementsLayout:invalidateLayout()
end

function AnimalFoodCalculator:calcFoodPerCluster(cluster)
	local age = cluster.age
	local num = cluster.numAnimals
	local subTypeIdx = cluster.subTypeIndex
	local subType = g_currentMission.animalSystem.subTypes[subTypeIdx]
	local food = subType.input["food"]
	
	local firstMonth = AnimalFoodCalculator:calcFoodByAge(cluster, 0)
	local wholeYear = firstMonth
	
	for extraMonth = 1,11 do
		wholeYear = wholeYear + AnimalFoodCalculator:calcFoodByAge(cluster, extraMonth)
	end
	
	return firstMonth*num, wholeYear*num
end

function AnimalFoodCalculator:calcFoodByAge(cluster, extraMonths)
	local age = cluster.age
	local subTypeIdx = cluster.subTypeIndex
	local subType = g_currentMission.animalSystem.subTypes[subTypeIdx]
	local food = subType.input["food"]
	
	local amount = food:get(age + extraMonths)
	local factor = 1.0
	
	if AnimalFoodCalculator.useEas then
		-- caluclate food factor for animals
		factor = AnimalFoodCalculator:lactationFactorForAnimalType(cluster, extraMonths)
	end
	
	return amount * factor
end

function AnimalFoodCalculator:lactationFactorForAnimalType(cluster, extraMonths)
	local subTypeIdx = cluster.subTypeIndex
	local subType = g_currentMission.animalSystem.subTypes[subTypeIdx]
    local animalType = g_currentMission.animalSystem:getTypeByIndex(subType.typeIndex)
    local animalTypeIndex = animalType.typeIndex
    local foodFactor = 1.0
    local values = {}
    if animalTypeIndex == AnimalType.PIG then
        values = AnimalFoodCalculator.EASSettings.PigFoodFactor
    elseif animalTypeIndex == AnimalType.COW then
        values = AnimalFoodCalculator.EASSettings.CowFoodFactor
    elseif animalTypeIndex == AnimalType.HORSE then
        values = AnimalFoodCalculator.EASSettings.HorseFoodFactor
    elseif animalTypeIndex == AnimalType.SHEEP then
        values = AnimalFoodCalculator.EASSettings.SheepFoodFactor
    elseif animalTypeIndex == AnimalType.CHICKEN then
        values = AnimalFoodCalculator.EASSettings.ChickenFoodFactor
    end
	

    if cluster:getCanReproduce() then
		local reproductiveMonths = extraMonths - (subType.reproductionMinAgeMonth - cluster.age)
		local actualReproduction = cluster.reproduction + (100/subType.reproductionDurationMonth)*reproductiveMonths	
		local actualHadABirth = cluster.hadABirth or actualReproduction >= 100
		-- assumes perfect, instant insemination
		local actualMonthsSinceLastBirth = (cluster.monthsSinceLastBirth + reproductiveMonths)%subType.reproductionDurationMonth
		
		if actualHadABirth and actualMonthsSinceLastBirth < #values then
			foodFactor = values[actualMonthsSinceLastBirth + 1]
		end
    end
	
    return foodFactor
end

function AnimalFoodCalculator:getText(key)
	local result = g_i18n.modEnvironments[AnimalFoodCalculator.name].texts[key]
	if result == nil then
		return g_i18n:getText(key)
	end
	return result
end

function AnimalFoodCalculator:loadedMission()
	if g_modIsLoaded["FS22_EnhancedAnimalSystem"] then
		AnimalFoodCalculator:loadEASXml()
	end
end

function AnimalFoodCalculator:loadEASXml()
	local path = AnimalFoodCalculator.modDir .. "../FS22_EnhancedAnimalSystem/xml/eas_settings.xml"
	local key = "EnhancedAnimalSystem.Settings"
	local xmlFileId = loadXMLFile("EAS_Utils", path)
	
	-- check for actually existing settings file
	if xmlFileId == nil then
		return
	end
	
	-- make sure the installed version actually has those settings
	if getXMLString(xmlFileId, key.."#PigFoodFactor") == nil then
		return
	end
	
	AnimalFoodCalculator.useEas = true
	AnimalFoodCalculator.EASSettings = {}


    AnimalFoodCalculator.EASSettings.PigFoodFactor = AnimalFoodCalculator:sliceByKomma(getXMLString(xmlFileId, key.."#PigFoodFactor"))
	AnimalFoodCalculator.EASSettings.CowFoodFactor = AnimalFoodCalculator:sliceByKomma(getXMLString(xmlFileId, key.."#CowFoodFactor"))
	AnimalFoodCalculator.EASSettings.HorseFoodFactor = AnimalFoodCalculator:sliceByKomma(getXMLString(xmlFileId, key.."#HorseFoodFactor"))
	AnimalFoodCalculator.EASSettings.SheepFoodFactor = AnimalFoodCalculator:sliceByKomma(getXMLString(xmlFileId, key.."#SheepFoodFactor"))
	AnimalFoodCalculator.EASSettings.ChickenFoodFactor = AnimalFoodCalculator:sliceByKomma(getXMLString(xmlFileId, key.."#ChickenFoodFactor"))
end

function AnimalFoodCalculator:sliceByKomma(text)
    local values = {}
    for value in text:gmatch('[^,%s]+') do
        table.insert(values, value)
    end
    return values
end

InGameMenuAnimalsFrame.onListSelectionChanged = Utils.appendedFunction(InGameMenuAnimalsFrame.onListSelectionChanged, AnimalFoodCalculator.onListSelectionChanged)
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, AnimalFoodCalculator.loadedMission)

