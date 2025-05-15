local _rewardItems = {
    {
        item = 'goldcoins',
        minAmount = 1,
        maxAmount = 1000,
    },
    {
        item = 'rolex',
        minAmount = 1,
        maxAmount = 1,
    },
    {
        item = 'laptop',
        minAmount = 1,
        maxAmount = 1,
    },
    {
        item = 'petrock',
        minAmount = 1,
        maxAmount = 1,
    },
}
local _dispatchLabels = {
    'Petty Theft',
    'Possible Pickpocketing',
    'Suspect on Foot',
}

AddEventHandler('Pickpocketing:Shared:DependencyUpdate', RetrieveComponents)
function RetrieveComponents()
    Fetch = exports['mythic-base']:FetchComponent('Fetch')
    Callbacks = exports['mythic-base']:FetchComponent('Callbacks')
    Inventory = exports['mythic-base']:FetchComponent('Inventory')
    Robbery = exports['mythic-base']:FetchComponent('Robbery')
end

AddEventHandler('Core:Shared:Ready', function()
    exports['mythic-base']:RequestDependencies('Pickpocketing', {
        'Fetch',
        'Callbacks',
        'Inventory',
        'Robbery',
    }, function(error)
        if #error > 0 then return end
        RetrieveComponents()

        Callbacks:RegisterServerCallback('Pickpocketing:Server:AlertPolice', function(source, data, cb)
            local char = Fetch:Source(source):GetData('Character')
            local src = source
            local coords = data.coords
            Robbery:TriggerPDAlert(src, coords, '10-92', _dispatchLabels[math.random(#_dispatchLabels)], {
                icon = 458,
                size = 0.9,
                color = 5,
                duration = (60 * 5),
            })
        end)

        Callbacks:RegisterServerCallback('Pickpocketing:Server:PickPocketed', function(source, data, cb)
            local src = source
            local char = Fetch:Source(source):GetData('Character')
            local rewardItem = _rewardItems[math.random(#_rewardItems)]
            local rewardChance = math.random(rewardItem.minAmount, rewardItem.maxAmount)
            Inventory:AddItem(char:GetData('SID'), rewardItem.item, rewardChance, {}, 1)
        end)
    end)
end)