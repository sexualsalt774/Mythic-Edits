AddEventHandler('Pickpocketing:Shared:DependencyUpdate', RetrieveComponents)
function RetrieveComponents()
    Targeting = exports['mythic-base']:FetchComponent('Targeting')
    Progress = exports['mythic-base']:FetchComponent('Progress')
    Minigame = exports['mythic-base']:FetchComponent('Minigame')
    Callbacks = exports['mythic-base']:FetchComponent('Callbacks')
end

AddEventHandler('Core:Shared:Ready', function()
    exports['mythic-base']:RequestDependencies('Pickpocketing', {
        'Targeting',
        'Progress',
        'Minigame',
        'Callbacks',
    }, function(error)
        if #error > 0 then return end
        RetrieveComponents()
        SetupPickpocketing()
    end)
end)

function SetupPickpocketing()
    Targeting:AddGlobalPed({
        {
            icon = 'hand-point-up',
            text = 'Pickpocket',
            event = 'Pickpocketing:Client:TryPickpocket',
            isEnabled = function(_, entity)
                local ped = entity.entity
                local entState = Entity(ped).state
                return entState.pickPocketed and not IsPedDeadOrDying(ped, false)
            end,
            minDist = 3.0,
        },
    })
end

function SkillCheck()
    local p = promise.new()
    Minigame.Play:RoundSkillbar(1.0, 5, {
        onSuccess = function()
            p:resolve(true)
        end,
        onFail = function()
            p:resolve(false)
        end,
    }, {
        animation = false,
    })

    return Citizen.Await(p)
end

AddEventHandler('Pickpocketing:Client:TryPickpocket', function(entity, data)
    local ped = entity.entity
    local entState = Entity(ped).state
    local weapons = {
        `WEAPON_KNIFE`,
        `WEAPON_PISTOL`,
        -- Add more weapons if you want:
        -- `WEAPON_COMBATPISTOL`,
        -- `WEAPON_BAT`,
    }

    Progress:Progress({
        name = 'pickpocketing_npc',
        duration = 2500,
        label = 'Pickpocketing.',
        useWhileDead = false,
        canCancel = false,
        ignoreModifier = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            animDict = "random@mugging3",
            anim = "pickup_low",
        },
    }, function(cancelled)
        if not cancelled then
            local skillCheck = SkillCheck()
            if skillCheck then
                Callbacks:ServerCallback('Pickpocketing:Server:PickPocketed', nil, function() end)
            else
                local weaponHash = weapons[math.random(#weapons)]
                GiveWeaponToPed(ped, weaponHash, 1, false, true)
                SetPedAsEnemy(ped, true)
                SetPedCanSwitchWeapon(ped, true)
                TaskCombatPed(ped, LocalPlayer.state.ped, 0, 16)
            end
        end
    end)
end)