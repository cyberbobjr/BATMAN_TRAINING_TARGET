require('luautils');

Events.OnGameStart.Add(function()
    local ISInventoryTransferAction_isvalid_origin = ISInventoryTransferAction.isValid
    local ISInventoryTransferAction_transferItem_origin = ISInventoryTransferAction.transferItem

    function ISInventoryTransferAction:transferItem(item)
        ISInventoryTransferAction_transferItem_origin(self, item)
        ---@type ItemContainer
        local dstContainer = self.destContainer
        local srcContainer = self.srcContainer
        if dstContainer:getType() == "ContainerCan" or srcContainer:getType() == "ContainerCan" then
            ---@type IsoThumpable
            local targetContainer = nil
            if dstContainer:getType() == "ContainerCan" then
                targetContainer = dstContainer:getParent()
            elseif srcContainer:getType() == "ContainerCan" then
                targetContainer = srcContainer:getParent()
            end
            if targetContainer ~= nil then
                TrainingTarget.UpdateTargetCan(targetContainer)
            end
        end
    end

    function ISInventoryTransferAction:isValid()
        local original_result = ISInventoryTransferAction_isvalid_origin(self)
        if original_result == false then
            return false
        end
        ---@type ItemContainer
        local dstContainer = self.destContainer
        if dstContainer:getType() == "ContainerCan" then
            ---@type InventoryItem
            local worldItem = self.item
            local actionQueue = ISTimedActionQueue.getTimedActionQueue(self.character)
            local itemType = worldItem:getType()
            local typeIndex = luautils.indexOf(TrainingTarget.ValidCan, itemType)
            if typeIndex == -1 then
                if actionQueue.current then
                    self.character:Say(getText("ContextMenu_I_cant_put_this"))
                end
                ISBaseTimedAction.stop(self)
                return false
            end
            if dstContainer:getItems():size() >= 12 then
                if actionQueue.current then
                    self.character:Say(getText("ContextMenu_I_cant_put_more_than_12_can"))
                end
                ISBaseTimedAction.stop(self)
                return false
            end
        end
        return original_result
    end
end)