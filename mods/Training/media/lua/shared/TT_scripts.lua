require('luautils');

TrainingTarget = {
    TrainingDummy = {
        tier_1_S = "batman_targets_dummy_training_10",
        tier_2_S = "batman_targets_dummy_training_11",
        tier_3_S = "batman_targets_dummy_training_12",
        tier_1_E = "batman_targets_dummy_training_18",
        tier_2_E = "batman_targets_dummy_training_19",
        tier_3_E = "batman_targets_dummy_training_20",
    },
    TrainingTypes = {
        TARGET = "batman_targets_01",
        MOBILE_TARGET = "cible_mobile_",
        DUMMY_TARGET = "batman_targets_dummy_training",
        CAN_TARGET = "batman_targets_can"
    },
    ValidCan = {
        "TinCanEmpty",
        "PopBottleEmpty",
        "WaterBottleEmpty",
        "WhiskeyEmpty",
        "WineEmpty",
        "WineEmpty2",
        "BeerEmpty",
        "PopEmpty",
        "Pop2Empty",
        "Pop3Empty",
        "BeerCanEmpty",
        "PopEmpty2",
        "PopEmpty2",
        "PopEmpty3",
        "PopEmptyLemon",
        "PopOrangeEmpty",
        "EnergyDrinkEmpty",
        "EnergyDrink2Empty",
        "EnergyDrink3Empty",
        "EnergyDrink4Empty",
        "EnergyDrink5Empty",
        "CannedSoupClassicEmpty",
        "EmptyBeerCan",
        "EmptyBeerCan2",
        "EmptyBeerCan3",
        "EmptyBeerCan4",
        "BeerCanEmpty"
    },
    currentTargetType = nil,
    -- character IsoGameCharacter / handWeapon HandWeapon
    ---@param character IsoGameCharacter
    ---@param handWeapon HandWeapon
    OnWeaponSwingHitPoint = function(character, handWeapon)
        TrainingTarget.currentTargetType = nil -- reset current target
        ---@type IsoGridSquare
        local shootPos = character:getAttackTargetSquare()
        ---@type IsoObject
        local targetObject = TrainingTarget.GetTargetObject(shootPos)
        if targetObject == nil then
            return
        end
        if handWeapon:getSubCategory() == "Firearm" then
            TrainingTarget.ProcessFirearm(character, targetObject, shootPos)
        else
            TrainingTarget.setXPForMelee(character, handWeapon)
            TrainingTarget.AddTier(targetObject, handWeapon)
            targetObject:WeaponHit(character, handWeapon)
        end
    end,
    ---@param character IsoGameCharacter
    setXPForMelee = function(character, handWeapon)
        if not handWeapon:isRanged() then
            local perk = nil
            if handWeapon:getScriptItem():getCategories():contains("Axe") then
                perk = Perks.Axe
            end
            if handWeapon:getScriptItem():getCategories():contains("Blunt") then
                perk = Perks.Blunt
            end
            if handWeapon:getScriptItem():getCategories():contains("Spear") then
                perk = Perks.Spear
            end
            if handWeapon:getScriptItem():getCategories():contains("LongBlade") then
                perk = Perks.LongBlade
            end
            if handWeapon:getScriptItem():getCategories():contains("SmallBlade") then
                perk = Perks.SmallBlade
            end
            if handWeapon:getScriptItem():getCategories():contains("SmallBlunt") then
                perk = Perks.SmallBlunt
            end
            if perk ~= nil then
                local exp = ZombRandFloat(1, 20) / (character:getPerkLevel(perk) + 1)
                character:getXp():AddXP(perk, exp)
                luautils.weaponLowerCondition(handWeapon, character)
            end
        end
    end,
    ---@param targetObject IsoObject|IsoThumpable
    ---@param shootPos IsoGridSquare
    ---@param character IsoGameCharacter
    ProcessFirearm = function(character, targetObject, shootPos)
        local distance = getCell():getGridSquare(character:getX(), character:getY(), character:getZ()):DistTo(shootPos)
        if distance <= 2 then
            character:Say(getText("ContextMenu_This_is_too_close"))
            return
        end
        if isDebugEnabled() then
            print("Found: " .. tostring(TrainingTarget.currentTargetType))
        end
        if not TrainingTarget.IsTargetStateGood(targetObject, TrainingTarget.currentTargetType) then
            if TrainingTarget.currentTargetType == TrainingTarget.TrainingTypes.CAN_TARGET then
                character:Say(getText("ContextMenu_Target_must_be_refilled"))
            else
                character:Say(getText("ContextMenu_Target_is_damaged"))
            end
            return
        end
        local chance = ZombRand(1, ((9 - character:getPerkLevel(Perks.Aiming) * 5 + distance * 2)))
        if chance <= 10 then
            character:Say(getText("ContextMenu_Ive_hit_something"))
            TrainingTarget.SetXPForAimingPerk(character, distance, TrainingTarget.currentTargetType)
            TrainingTarget.ManageTargetState(targetObject, TrainingTarget.currentTargetType)
            TrainingTarget.PlaySoundForTrainingType(character, TrainingTarget.currentTargetType)
        else
            character:Say(getText("ContextMenu_Ive_missed"))
        end
    end,
    PlaySoundForTrainingType = function(character, trainingType)
        local sound = nil
        if trainingType == TrainingTarget.TrainingTypes.MOBILE_TARGET or trainingType == TrainingTarget.TrainingTypes.TARGET then
            sound = "hit"
        elseif trainingType == TrainingTarget.TrainingTypes.CAN_TARGET then
            sound = "can"
        end
        if sound ~= nil then
            getSoundManager():PlayWorldSound(sound, getCell():getGridSquare(character:getX(), character:getY(), character:getZ()), 0, 0, 0, false);
            addSound(character, character:getX(), character:getY(), character:getZ(), 3, 0)
        end
    end,
    ---@param targetObject IsoObject|IsoThumpable
    IsTargetStateGood = function(targetObject, trainingType)
        if trainingType == TrainingTarget.TrainingTypes.DUMMY_TARGET then
            return true
        end
        if trainingType == TrainingTarget.TrainingTypes.CAN_TARGET then
            ---@type ItemContainer
            local target = targetObject:getContainer()
            return target:getItems():size() > 0
        end
        if trainingType == TrainingTarget.TrainingTypes.TARGET then
            return targetObject:getChildSprites() == nil or targetObject:getChildSprites():size() < 10
        end
        if trainingType == TrainingTarget.TrainingTypes.MOBILE_TARGET then
            return targetObject:getChildSprites() == nil or targetObject:getChildSprites():size() < 10
        end
    end,
    SetXPForAimingPerk = function(character, distance, trainingTypes)
        -- Give more XP depends on target type
        local xp = 1
        if trainingTypes == TrainingTarget.TrainingTypes.TARGET then
            xp = xp * 1
        elseif trainingTypes == TrainingTarget.TrainingTypes.MOBILE_TARGET then
            xp = xp * 3 -- @todo must be set with options
        elseif trainingTypes == TrainingTarget.TrainingTypes.CAN_TARGET then
            xp = xp * 5
        end
        character:getXp():AddXP(Perks.Aiming, xp)
    end,
    ---@param trainingTarget IsoObject
    ManageTargetState = function(trainingTarget, trainingType)
        ---@type PropertyContainer
        local targetProperties = trainingTarget:getSprite():getProperties()
        local direction = targetProperties:Val("Facing")
        if trainingType == TrainingTarget.TrainingTypes.TARGET or trainingType == TrainingTarget.TrainingTypes.MOBILE_TARGET then
            TrainingTarget.UpdateTargetHoles(trainingTarget, trainingType, direction)
        elseif trainingType == TrainingTarget.TrainingTypes.CAN_TARGET then
            ---@type ItemContainer
            local container = trainingTarget:getContainer()
            ---@type InventoryItem
            local item = container:getFirstEval(function(item)
                return luautils.indexOf(TrainingTarget.ValidCan, item:getType()) > -1
            end)
            if item ~= nil then
                if isClient() then
                    container:removeItemOnServer(item);
                end
                container:DoRemoveItem(item)
                TrainingTarget.UpdateTargetCan(trainingTarget)
            end
        end
    end,
    ---@param trainingTarget IsoThumpable
    UpdateTargetCan = function(trainingTarget)
        ---@type ItemContainer
        local container = trainingTarget:getContainer()
        local targetProperties = trainingTarget:getSprite():getProperties()
        local direction = targetProperties:Val("Facing")
        if direction ~= nil then
            local attachedCount = container:getItems():size()
            if direction == "S" then
                start = 0
            else
                start = 16
            end
            local spriteName = "batman_targets_can_0_" .. (start + attachedCount)
            ---@type ArrayList
            local childList = trainingTarget:getChildSprites() or ArrayList.new();
            local holeSprite = getSprite(spriteName):newInstance()
            childList:clear()
            childList:add(holeSprite)
            trainingTarget:setChildSprites(childList)
            if isClient() then
                trainingTarget:transmitUpdatedSpriteToServer()
            end
        end
    end,
    UpdateTargetHoles = function(trainingTarget, trainingType, direction)
        local attached = trainingTarget:getChildSprites() or ArrayList.new();
        local attachedCount = attached:size()
        if attachedCount < 10 then
            attachedCount = attachedCount + 1;
            local spriteName = nil
            local spriteDir = nil
            if direction == "S" then
                spriteDir = "north"
            elseif direction == "E" then
                spriteDir = "west"
            end
            if trainingType == TrainingTarget.TrainingTypes.TARGET then
                spriteName = "batman_targets_holes_" .. spriteDir .. "_0" .. attachedCount .. "_2"
            elseif trainingType == TrainingTarget.TrainingTypes.MOBILE_TARGET and (spriteDir ~= nil) then
                spriteName = "cible_mobile_" .. attachedCount + 3
            end
            if spriteName ~= nil then
                local holeSprite = getSprite(spriteName):newInstance()
                attached:add(holeSprite)
                trainingTarget:setChildSprites(attached)
                if isClient() then
                    trainingTarget:transmitUpdatedSpriteToServer()
                end
            end
        end
    end,
    ---@param shootPos IsoGridSquare
    GetTargetObject = function(shootPos)
        ---@type IsoObject
        local targetObject = nil
        if isDebugEnabled() then
            print("Found: " .. tostring(shootPos:getObjects()))
        end
        for i = 1, shootPos:getObjects():size() do
            local thisObject = shootPos:getObjects():get(i - 1)
            if thisObject ~= nil and (TrainingTarget.IsTarget(thisObject) or TrainingTarget.IsCanTarget(thisObject) or TrainingTarget.IsMobileTarget(thisObject) or TrainingTarget.IsDummyTarget(thisObject)) then
                targetObject = thisObject
            end
        end
        return targetObject
    end,
    IsTarget = function(object)
        ---@type IsoSprite
        local sprite = object:getSprite()
        if sprite ~= nil then
            local name = sprite:getName()
            if name ~= nil and luautils.stringStarts(name, TrainingTarget.TrainingTypes.TARGET) then
                TrainingTarget.currentTargetType = TrainingTarget.TrainingTypes.TARGET
                return true
            end
        end
        return false
    end,
    IsDummyTarget = function(object)
        ---@type IsoSprite
        local sprite = object:getSprite()
        if sprite ~= nil then
            local name = sprite:getName()
            if name ~= nil and (luautils.stringStarts(name, TrainingTarget.TrainingTypes.DUMMY_TARGET)) then
                TrainingTarget.currentTargetType = TrainingTarget.TrainingTypes.DUMMY_TARGET
                return true
            end
        end
        return false
    end,
    IsCanTarget = function(object)
        ---@type IsoSprite
        local sprite = object:getSprite()
        if sprite ~= nil then
            local name = sprite:getName()
            if name ~= nil and (luautils.stringStarts(name, TrainingTarget.TrainingTypes.CAN_TARGET)) then
                TrainingTarget.currentTargetType = TrainingTarget.TrainingTypes.CAN_TARGET
                return true
            end
        end
        return false
    end,
    IsMobileTarget = function(object)
        ---@type IsoSprite
        local sprite = object:getSprite()
        if sprite ~= nil then
            local name = sprite:getName()
            if name ~= nil and (luautils.stringStarts(name, TrainingTarget.TrainingTypes.MOBILE_TARGET)) then
                TrainingTarget.currentTargetType = TrainingTarget.TrainingTypes.MOBILE_TARGET
                return true
            end
        end
        return false
    end,
    ---@param targetObject IsoThumpable
    ---@param handWeapon HandWeapon
    AddTier = function(targetObject, handWeapon)
        targetObject:setHealth(targetObject:getHealth() - handWeapon:getMaxDamage())
        local thumpCondition = targetObject:getThumpCondition() * 100;
        local targetProperties = targetObject:getSprite():getProperties()
        local direction = targetProperties:Val("Facing")
        if direction == nil then
            return
        end
        local spriteName = nil
        if thumpCondition < 75 and thumpCondition >= 50 then
            spriteName = TrainingTarget["TrainingDummy"]["tier_1_" .. direction]
        elseif thumpCondition < 50 and thumpCondition >= 25 then
            spriteName = TrainingTarget["TrainingDummy"]["tier_2_" .. direction]
        elseif thumpCondition < 25 then
            spriteName = TrainingTarget["TrainingDummy"]["tier_3_" .. direction]
        end
        if spriteName ~= nil then
            ---@type IsoSprite
            targetObject:setSprite(getSprite(spriteName))
            if isClient() then
                targetObject:transmitUpdatedSpriteToServer()
            end
        end
    end,
    ---@param object IsoObject
    OnObjectAdded = function(object)
        if TrainingTarget.IsDummyTarget(object) then
            if isDebugEnabled() then
                print("Set health for dummy target")
            end
            object:setHealth(900)
            object:setOutlineOnMouseover(true)
            object:setMaxHealth(900)
            object:setIsDoor(true) -- for shaking effect
        end
    end,
    onContextMenu = function(playerIndex, context, worldObjects, test)
        for _, object in ipairs(worldObjects) do
            if instanceof(object, "IsoThumpable") and object:isDoor() and TrainingTarget.IsTarget(object) then
                context:removeOptionByName(getText("ContextMenu_Open_door")) -- for removing "Open Door" option into the context menu
            end
        end
    end
}

Events.OnWeaponSwingHitPoint.Add(TrainingTarget.OnWeaponSwingHitPoint)
Events.OnObjectAdded.Add(TrainingTarget.OnObjectAdded)
Events.OnFillWorldObjectContextMenu.Add(TrainingTarget.onContextMenu);

