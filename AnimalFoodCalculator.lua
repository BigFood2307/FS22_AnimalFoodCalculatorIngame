
AnimalFoodCalculator = {}
AnimalFoodCalculator.name = g_currentModName
AnimalFoodCalculator.modDir = g_currentModDirectory

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
	
	local firstMonth = AnimalFoodCalculator:calcFoodByAge(food, age)
	local wholeYear = firstMonth
	
	for extraMonth = 1,11 do
		wholeYear = wholeYear + AnimalFoodCalculator:calcFoodByAge(food, age+extraMonth)
	end
	
	return firstMonth*num, wholeYear*num
end

function AnimalFoodCalculator:calcFoodByAge(food, age)
	if age >= food.maxTime then
		return food.keyframes[food.numKeyframes][1]
	end
	
	local idx = 1
	
	while food.keyframes[idx]["time"] <= age do
		idx = idx + 1
	end
	
	local factor = 1-((age - food.keyframes[idx-1]["time"])/(food.keyframes[idx]["time"] - food.keyframes[idx-1]["time"]))
	
	return AnimalFoodCalculator:interpolateFood(food.keyframes[idx-1], food.keyframes[idx], factor, food.interpolatorDegree)
end

function AnimalFoodCalculator:interpolateFood(kf1, kf2, factor, degree)
	return (factor^degree)*kf1[1] + (1-(factor^degree))*kf2[1]
end

function AnimalFoodCalculator:getText(key)
	local result = g_i18n.modEnvironments[AnimalFoodCalculator.name].texts[key]
	if result == nil then
		return g_i18n:getText(key)
	end
	return result
end

InGameMenuAnimalsFrame.onListSelectionChanged = Utils.appendedFunction(InGameMenuAnimalsFrame.onListSelectionChanged, AnimalFoodCalculator.onListSelectionChanged)

