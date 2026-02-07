local QBCore = exports['qb-core']:GetCoreObject()

-- Handle payment request
RegisterNetEvent('royal_constraction:requestPayment', function(baseReward, isOnQuest)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end

    local reward = baseReward

    -- Apply quest bonus if active
    if isOnQuest then
        local bonus = math.floor(baseReward * Config.Quest.bonusPercent)
        reward = baseReward + bonus
    end

    -- Give cash to player
    Player.Functions.AddMoney('cash', reward, 'Construction Work Payment')
    
    -- Notify player
    local message = '$' .. reward
    if isOnQuest then
        message = message .. ' (+10% quest bonus)'
    end
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = message
    })
end)

-- Get quest progress callback
lib.callback.register('royal_constraction:getQuestProgress', function(source)
    -- Could be expanded to store progress in database
    return 0
end)

print('^2[Royal Construction] Resource loaded successfully^7')
