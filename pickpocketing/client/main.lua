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
            data = {},
            isEnabled = function(_, entity)
                local ped = entity.entity
                local entState = Entity(ped).state
                if entState.pickPocketed or IsPedDeadOrDying(ped, false) then return false end
                local pedCoords = GetEntityCoords(ped)
                local pedForward = GetEntityForwardVector(ped)
                local toPlayer = LocalPlayer.state.position - pedCoords
                toPlayer = vector3(toPlayer.x, toPlayer.y, toPlayer.z)
                local toPlayerDir = toPlayer / #(toPlayer)
                local dot = pedForward.x * toPlayerDir.x + pedForward.y * toPlayerDir.y + pedForward.z * toPlayerDir.z
                return dot < -0.65
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
    local netId = NetworkGetNetworkIdFromEntity(ped)
    local weapons = {
        `WEAPON_KNIFE`,
        `WEAPON_PISTOL`,
        -- Add more weapons if you want:
        -- `WEAPON_COMBATPISTOL`,
        -- `WEAPON_BAT`,
    }

    TaskFollowToOffsetOfEntity(LocalPlayer.state.ped, ped, 0.0, -0.75, 0.0, 1.0, -1, 1.0, true)

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
        animation = false,
    }, function(cancelled)
        if not cancelled then
            local skillCheck = SkillCheck()
            ClearPedTasks(LocalPlayer.state.ped)
            Callbacks:ServerCallback('Pickpocketing:Server:PickPocketed', {netId = netId, success = skillCheck}, function(success)
                if success then return end

                local weaponHash = weapons[math.random(#weapons)]
                GiveWeaponToPed(ped, weaponHash, 250, false, true) -- Give more ammo

                -- Relationship setup
                SetPedAsEnemy(ped, true)
                SetPedRelationshipGroupHash(ped, `HATES_PLAYER`)
                SetRelationshipBetweenGroups(5, `HATES_PLAYER`, `PLAYER`)
                SetRelationshipBetweenGroups(5, `PLAYER`, `HATES_PLAYER`)

                -- Disable fleeing and keep combat-focused
                SetPedFleeAttributes(ped, 0, false)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedCombatAttributes(ped, 46, true) -- Always fight
                SetPedCombatAttributes(ped, 0, true) -- Use cover
                SetPedCombatAbility(ped, 2) -- 0=poor, 1=average, 2=professional
                SetPedCombatRange(ped, 2) -- 0=near, 1=medium, 2=far
                SetPedAccuracy(ped, 60) -- Optional: make them hit more often
                SetPedAlertness(ped, 3) -- Max alertness

                -- Make them attack the player
                TaskCombatPed(ped, LocalPlayer.state.ped, 0, 16)
            end)
        end
    end)
end)