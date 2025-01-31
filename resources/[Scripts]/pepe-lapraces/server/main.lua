Framework = nil
TriggerEvent('Framework:GetObject', function(obj) Framework = obj end)

Races = {}

AvailableRaces = {}

LastRaces = {}
NotFinished = {}

Citizen.CreateThread(function()
    Framework.Functions.ExecuteSql(false, "SELECT * FROM `lapraces`", function(races)
        if races[1] ~= nil then
            for k, v in pairs(races) do
                local Records = {}
                if v.records ~= nil then
                    Records = json.decode(v.records)
                end
                Races[v.raceid] = {
                    RaceName = v.name,
                    Checkpoints = json.decode(v.checkpoints),
                    Records = Records,
                    Creator = v.creator,
                    RaceId = v.raceid,
                    Started = false,
                    Waiting = false,
                    Distance = v.distance,
                    LastLeaderboard = {},
                    Racers = {},
                }
            end
        end
    end)
end)

Framework.Functions.CreateCallback('pepe-lapraces:server:GetRacingLeaderboards', function(source, cb)
    cb(Races)
end)

function SecondsToClock(seconds)
    local seconds = tonumber(seconds)
    local retval = 0
    if seconds <= 0 then
        retval = "00:00:00";
    else
        hours = string.format("%02.f", math.floor(seconds/3600));
        mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
        secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
        retval = hours..":"..mins..":"..secs
    end
    return retval
end

RegisterServerEvent('pepe-lapraces:server:FinishPlayer')
AddEventHandler('pepe-lapraces:server:FinishPlayer', function(RaceData, TotalTime, TotalLaps, BestLap)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local PlayersFinished = 0
    local AmountOfRacers = 0
    for k, v in pairs(Races[RaceData.RaceId].Racers) do
        if v.Finished then
            PlayersFinished = PlayersFinished + 1
        end
        AmountOfRacers = AmountOfRacers + 1
    end
    local BLap = 0
    if TotalLaps < 2 then
        BLap = TotalTime
    else
        BLap = BestLap
    end
    if LastRaces[RaceData.RaceId] ~= nil then
        table.insert(LastRaces[RaceData.RaceId], {
            TotalTime = TotalTime,
            BestLap = BLap,
            Holder = {
                [1] = Player.PlayerData.charinfo.firstname,
                [2] = Player.PlayerData.charinfo.lastname
            }
        })
    else
        LastRaces[RaceData.RaceId] = {}
        table.insert(LastRaces[RaceData.RaceId], {
            TotalTime = TotalTime,
            BestLap = BLap,
            Holder = {
                [1] = Player.PlayerData.charinfo.firstname,
                [2] = Player.PlayerData.charinfo.lastname
            }
        })
    end
    if Races[RaceData.RaceId].Records ~= nil and next(Races[RaceData.RaceId].Records) ~= nil then
        if BLap < Races[RaceData.RaceId].Records.Time then
            Races[RaceData.RaceId].Records = {
                Time = BLap,
                Holder = {
                    [1] = Player.PlayerData.charinfo.firstname, 
                    [2] = Player.PlayerData.charinfo.lastname,
                }
            }
            Framework.Functions.ExecuteSql(false, "UPDATE `lapraces` SET `records` = '"..json.encode(Races[RaceData.RaceId].Records).."' WHERE `raceid` = '"..RaceData.RaceId.."'")
            TriggerClientEvent('pepe-phone:client:RaceNotify', src, 'Bạn đã phá vỡ kỷ lục về lòng '..RaceData.RaceName..' với thời gian: '..SecondsToClock(BLap)..'!')
        end
    else
        Races[RaceData.RaceId].Records = {
            Time = BLap,
            Holder = {
                [1] = Player.PlayerData.charinfo.firstname,
                [2] = Player.PlayerData.charinfo.lastname,
            }
        }
        Framework.Functions.ExecuteSql(false, "UPDATE `lapraces` SET `records` = '"..json.encode(Races[RaceData.RaceId].Records).."' WHERE `raceid` = '"..RaceData.RaceId.."'")
        TriggerClientEvent('pepe-phone:client:RaceNotify', src, 'Bạn đã đặt bản ghi LAP trên '..RaceData.RaceName..' với thời gian: '..SecondsToClock(BLap)..'!')
    end
    AvailableRaces[AvailableKey].RaceData = Races[RaceData.RaceId]
    TriggerClientEvent('pepe-lapraces:client:PlayerFinishs', -1, RaceData.RaceId, PlayersFinished, Player)
    if PlayersFinished == AmountOfRacers then
        if NotFinished ~= nil and next(NotFinished) ~= nil and NotFinished[RaceData.RaceId] ~= nil and next(NotFinished[RaceData.RaceId]) ~= nil then
            for k, v in pairs(NotFinished[RaceData.RaceId]) do
                table.insert(LastRaces[RaceData.RaceId], {
                    TotalTime = v.TotalTime,
                    BestLap = v.BestLap,
                    Holder = {
                        [1] = v.Holder[1],
                        [2] = v.Holder[2]
                    }
                })
            end
        end
        Races[RaceData.RaceId].LastLeaderboard = LastRaces[RaceData.RaceId]
        Races[RaceData.RaceId].Racers = {}
        Races[RaceData.RaceId].Started = false
        Races[RaceData.RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        LastRaces[RaceData.RaceId] = nil
        NotFinished[RaceData.RaceId] = nil
    end
    TriggerClientEvent('pepe-phone:client:UpdateLapraces', -1)
end)

function IsWhitelisted(CitizenId)
    local retval = false
    for _, cid in pairs(Config.WhitelistedCreators) do
        if cid == CitizenId then
            retval = true
            break
        end
    end
    local Player = Framework.Functions.GetPlayerByCitizenId(CitizenId)
    local Perms = Framework.Functions.GetPermission(Player.PlayerData.source)
    if Perms == "user" or Perms == "user" then
        retval = true
    end
    return retval
end

function IsNameAvailable(RaceName)
    local retval = true
    for RaceId,_ in pairs(Races) do
        if Races[RaceId].RaceName == RaceName then
            retval = false
            break
        end
    end
    return retval
end

RegisterServerEvent('pepe-lapraces:server:CreateLapRace')
AddEventHandler('pepe-lapraces:server:CreateLapRace', function(RaceName)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    
    if IsWhitelisted(Player.PlayerData.citizenid) then
        if IsNameAvailable(RaceName) then
            TriggerClientEvent('pepe-lapraces:client:StartRaceEditor', source, RaceName)
        else
            TriggerClientEvent('Framework:Notify', source, 'Đã có một cuộc đua với tên đó.', 'error')
        end
    else
        TriggerClientEvent('Framework:Notify', source, 'Bạn không có quyền tạo ra một cuộc đua.', 'error')
    end
end)

Framework.Functions.CreateCallback('pepe-lapraces:server:GetRaces', function(source, cb)
    cb(AvailableRaces)
end)

Framework.Functions.CreateCallback('pepe-lapraces:server:GetListedRaces', function(source, cb)
    cb(Races)
end)

Framework.Functions.CreateCallback('pepe-lapraces:server:GetRacingData', function(source, cb, RaceId)
    cb(Races[RaceId])
end)

Framework.Functions.CreateCallback('pepe-lapraces:server:HasCreatedRace', function(source, cb)
    cb(HasOpenedRace(Framework.Functions.GetPlayer(source).PlayerData.citizenid))
end)

Framework.Functions.CreateCallback('pepe-lapraces:server:IsAuthorizedToCreateRaces', function(source, cb, TrackName)
    cb(IsWhitelisted(Framework.Functions.GetPlayer(source).PlayerData.citizenid), IsNameAvailable(TrackName))
end)

function HasOpenedRace(CitizenId)
    local retval = false
    for k, v in pairs(AvailableRaces) do
        if v.SetupCitizenId == CitizenId then
            retval = true
        end
    end
    return retval
end

Framework.Functions.CreateCallback('pepe-lapraces:server:GetTrackData', function(source, cb, RaceId)
    Framework.Functions.ExecuteSql(false, "SELECT * FROM `characters_metadata` WHERE `citizenid` = '"..Races[RaceId].Creator.."'", function(result)
        if result[1] ~= nil then
            result[1].charinfo = json.decode(result[1].charinfo)
            cb(Races[RaceId], result[1])
        else
            cb(Races[RaceId], {
                charinfo = {
                    firstname = "Unknown",
                    lastname = "Unknown",
                }
            })
        end
    end)
end)

function GetOpenedRaceKey(RaceId)
    local retval = nil
    for k, v in pairs(AvailableRaces) do
        if v.RaceId == RaceId then
            retval = k
            break
        end
    end
    return retval
end

function GetCurrentRace(MyCitizenId)
    local retval = nil
    for RaceId,_ in pairs(Races) do
        for cid,_ in pairs(Races[RaceId].Racers) do
            if cid == MyCitizenId then
                retval = RaceId
                break
            end
        end
    end
    return retval
end

RegisterServerEvent('pepe-lapraces:server:JoinRace')
AddEventHandler('pepe-lapraces:server:JoinRace', function(RaceData)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    local RaceName = RaceData.RaceData.RaceName
    local RaceId = GetRaceId(RaceName)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local CurrentRace = GetCurrentRace(Player.PlayerData.citizenid)
    if CurrentRace ~= nil then
        local AmountOfRacers = 0
        PreviousRaceKey = GetOpenedRaceKey(CurrentRace)
        for k, v in pairs(Races[CurrentRace].Racers) do
            AmountOfRacers = AmountOfRacers + 1
        end
        Races[CurrentRace].Racers[Player.PlayerData.citizenid] = nil
        if (AmountOfRacers - 1) == 0 then
            Races[CurrentRace].Racers = {}
            Races[CurrentRace].Started = false
            Races[CurrentRace].Waiting = false
            table.remove(AvailableRaces, PreviousRaceKey)
            TriggerClientEvent('Framework:Notify', src, 'Bạn là người duy nhất trong cuộc đua, cuộc đua sẽ kết thúc.', 'error')
            TriggerClientEvent('pepe-lapraces:client:LeaveRace', src, Races[CurrentRace])
        else
            AvailableRaces[PreviousRaceKey].RaceData = Races[CurrentRace]
            TriggerClientEvent('pepe-lapraces:client:LeaveRace', src, Races[CurrentRace])
        end
        TriggerClientEvent('pepe-phone:client:UpdateLapraces', -1)
    end
    Races[RaceId].Waiting = true
    Races[RaceId].Racers[Player.PlayerData.citizenid] = {
        Checkpoint = 0,
        Lap = 1,
        Finished = false,
    }
    AvailableRaces[AvailableKey].RaceData = Races[RaceId]
    TriggerClientEvent('pepe-lapraces:client:JoinRace', src, Races[RaceId], RaceData.Laps)
    TriggerClientEvent('pepe-phone:client:UpdateLapraces', -1)
    local creatorsource = Framework.Functions.GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId).PlayerData.source
    if creatorsource ~= Player.PlayerData.source then
        TriggerClientEvent('pepe-phone:client:RaceNotify', creatorsource, string.sub(Player.PlayerData.charinfo.firstname, 1, 1)..'. '..Player.PlayerData.charinfo.lastname..' Joined the race!')
    end
end)

RegisterServerEvent('pepe-lapraces:server:LeaveRace')
AddEventHandler('pepe-lapraces:server:LeaveRace', function(RaceData)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    local RaceName
    if RaceData.RaceData ~= nil then
        RaceName = RaceData.RaceData.RaceName
    else
        RaceName = RaceData.RaceName
    end
    local RaceId = GetRaceId(RaceName)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local creatorsource = Framework.Functions.GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId).PlayerData.source
    if creatorsource ~= Player.PlayerData.source then
        TriggerClientEvent('pepe-phone:client:RaceNotify', creatorsource, string.sub(Player.PlayerData.charinfo.firstname, 1, 1)..'. '..Player.PlayerData.charinfo.lastname..' Left the race!')
    end
    local AmountOfRacers = 0
    for k, v in pairs(Races[RaceData.RaceId].Racers) do
        AmountOfRacers = AmountOfRacers + 1
    end
    if NotFinished[RaceData.RaceId] ~= nil then
        table.insert(NotFinished[RaceData.RaceId], {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = {
                [1] = Player.PlayerData.charinfo.firstname,
                [2] = Player.PlayerData.charinfo.lastname
            }
        })
    else
        NotFinished[RaceData.RaceId] = {}
        table.insert(NotFinished[RaceData.RaceId], {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = {
                [1] = Player.PlayerData.charinfo.firstname,
                [2] = Player.PlayerData.charinfo.lastname
            }
        })
    end
    Races[RaceId].Racers[Player.PlayerData.citizenid] = nil
    if (AmountOfRacers - 1) == 0 then
        if NotFinished ~= nil and next(NotFinished) ~= nil and NotFinished[RaceId] ~= nil and next(NotFinished[RaceId]) ~= nil then
            for k, v in pairs(NotFinished[RaceId]) do
                if LastRaces[RaceId] ~= nil then
                    table.insert(LastRaces[RaceId], {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = {
                            [1] = v.Holder[1],
                            [2] = v.Holder[2]
                        }
                    })
                else
                    LastRaces[RaceId] = {}
                    table.insert(LastRaces[RaceId], {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = {
                            [1] = v.Holder[1],
                            [2] = v.Holder[2]
                        }
                    })
                end
            end
        end
        Races[RaceId].LastLeaderboard = LastRaces[RaceId]
        Races[RaceId].Racers = {}
        Races[RaceId].Started = false
        Races[RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        TriggerClientEvent('Framework:Notify', src, 'Bạn là người duy nhất trong cuộc đua, cuộc đua sẽ kết thúc.', 'error')
        TriggerClientEvent('pepe-lapraces:client:LeaveRace', src, Races[RaceId])
        LastRaces[RaceId] = nil
        NotFinished[RaceId] = nil
    else
        AvailableRaces[AvailableKey].RaceData = Races[RaceId]
        TriggerClientEvent('pepe-lapraces:client:LeaveRace', src, Races[RaceId])
    end
    TriggerClientEvent('pepe-phone:client:UpdateLapraces', -1)
end)

RegisterServerEvent('pepe-lapraces:server:SetupRace')
AddEventHandler('pepe-lapraces:server:SetupRace', function(RaceId, Laps)
    local Player = Framework.Functions.GetPlayer(source)
    if Races[RaceId] ~= nil then
        if not Races[RaceId].Waiting then
            if not Races[RaceId].Started then
                Races[RaceId].Waiting = true
                table.insert(AvailableRaces, {
                    RaceData = Races[RaceId],
                    Laps = Laps,
                    RaceId = RaceId,
                    SetupCitizenId = Player.PlayerData.citizenid,
                })
                TriggerClientEvent('pepe-phone:client:UpdateLapraces', -1)
                SetTimeout(5 * 60 * 1000, function()
                    if Races[RaceId].Waiting then
                        local AvailableKey = GetOpenedRaceKey(RaceId)
                        for cid,_ in pairs(Races[RaceId].Racers) do
                            local RacerData = Framework.Functions.GetPlayerByCitizenId(cid)
                            if RacerData ~= nil then
                                TriggerClientEvent('pepe-lapraces:client:LeaveRace', RacerData.PlayerData.source, Races[RaceId])
                            end
                        end
                        table.remove(AvailableRaces, AvailableKey)
                        Races[RaceId].LastLeaderboard = {}
                        Races[RaceId].Racers = {}
                        Races[RaceId].Started = false
                        Races[RaceId].Waiting = false
                        LastRaces[RaceId] = nil
                        TriggerClientEvent('pepe-phone:client:UpdateLapraces', -1)
                    end
                end)
            else
                Framework.Functions.Notify('Cuộc đua đã hoạt động', 'error', 5000)
            end
        else
            TriggerClientEvent('Framework:Notify', source, 'Cuộc đua đã hoạt động..', 'error')
        end
    else
        TriggerClientEvent('Framework:Notify', source, 'Cuộc đua này không có EXSIST :(', 'error')
    end
end)

RegisterServerEvent('pepe-lapraces:server:UpdateRaceState')
AddEventHandler('pepe-lapraces:server:UpdateRaceState', function(RaceId, Started, Waiting)
    Races[RaceId].Waiting = Waiting
    Races[RaceId].Started = Started
end)

RegisterServerEvent('pepe-lapraces:server:UpdateRacerData')
AddEventHandler('pepe-lapraces:server:UpdateRacerData', function(RaceId, Checkpoint, Lap, Finished)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    local CitizenId = Player.PlayerData.citizenid

    Races[RaceId].Racers[CitizenId].Checkpoint = Checkpoint
    Races[RaceId].Racers[CitizenId].Lap = Lap
    Races[RaceId].Racers[CitizenId].Finished = Finished

    TriggerClientEvent('pepe-lapraces:client:UpdateRaceRacerData', -1, RaceId, Races[RaceId])
end)

RegisterServerEvent('pepe-lapraces:server:StartRace')
AddEventHandler('pepe-lapraces:server:StartRace', function(RaceId)
    local src = source
    local MyPlayer = Framework.Functions.GetPlayer(src)
    local AvailableKey = GetOpenedRaceKey(RaceId)
    
    if RaceId ~= nil then
        if AvailableRaces[AvailableKey].SetupCitizenId == MyPlayer.PlayerData.citizenid then
            AvailableRaces[AvailableKey].RaceData.Started = true
            AvailableRaces[AvailableKey].RaceData.Waiting = false
            for CitizenId,_ in pairs(Races[RaceId].Racers) do
                local Player = Framework.Functions.GetPlayerByCitizenId(CitizenId)
                if Player ~= nil then
                    TriggerClientEvent('pepe-lapraces:client:RaceCountdown', Player.PlayerData.source)
                end
            end
            TriggerClientEvent('pepe-phone:client:UpdateLapraces', -1)
        else
            TriggerClientEvent('Framework:Notify', src, 'Bạn không phải là người tạo ra cuộc đua..', 'error')
        end
    else
        TriggerClientEvent('Framework:Notify', src, 'Bạn không ở trong một cuộc đua..', 'error')
    end
end)

RegisterServerEvent('pepe-lapraces:server:SaveRace')
AddEventHandler('pepe-lapraces:server:SaveRace', function(RaceData)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    local RaceId = GenerateRaceId()
    local Checkpoints = {}
    for k, v in pairs(RaceData.Checkpoints) do
        Checkpoints[k] = {
            offset = v.offset,
            coords = v.coords,
        }
    end
    Races[RaceId] = {
        RaceName = RaceData.RaceName,
        Checkpoints = Checkpoints,
        Records = {},
        Creator = Player.PlayerData.citizenid,
        RaceId = RaceId,
        Started = false,
        Waiting = false,
        Distance = math.ceil(RaceData.RaceDistance),
        Racers = {},
        LastLeaderboard = {},
    }
    Framework.Functions.ExecuteSql(false, "INSERT INTO `lapraces` (`name`, `checkpoints`, `creator`, `distance`, `raceid`) VALUES ('"..RaceData.RaceName.."', '"..json.encode(Checkpoints).."', '"..Player.PlayerData.citizenid.."', '"..RaceData.RaceDistance.."', '"..GenerateRaceId().."')")
end)

function GetRaceId(name)
    local retval = nil
    for k, v in pairs(Races) do
        if v.RaceName == name then
            retval = k
            break
        end
    end
    return retval
end

function GenerateRaceId()
    local RaceId = "LR-"..math.random(1111, 9999)
    while Races[RaceId] ~= nil do
        RaceId = "LR-"..math.random(1111, 9999)
    end
    return RaceId
end

Framework.Commands.Add("togglesetup", "Bật / tắt thiết lập Racing", {}, false, function(source, args)
    local Player = Framework.Functions.GetPlayer(source)

    if IsWhitelisted(Player.PlayerData.citizenid) then
        Config.RaceSetupAllowed = not Config.RaceSetupAllowed
        if not Config.RaceSetupAllowed then
            TriggerClientEvent('Framework:Notify', source, 'Không thể có thêm một cuộc đua', 'error')
        else
            TriggerClientEvent('Framework:Notify', source, 'Bạn có thể thực hiện cuộc đua một lần nữa!', 'success')
        end
    else
        TriggerClientEvent('Framework:Notify', source, 'Bạn không có quyền để làm điều này.', 'error')
    end
end)

Framework.Commands.Add("cancelrace", "Hủy cuộc đua đang diễn ra..", {}, false, function(source, args)
    local Player = Framework.Functions.GetPlayer(source)

    if IsWhitelisted(Player.PlayerData.citizenid) then
        local RaceName = table.concat(args, " ")
        if RaceName ~= nil then
            local RaceId = GetRaceId(RaceName)
            if Races[RaceId].Started then
                local AvailableKey = GetOpenedRaceKey(RaceId)
                for cid,_ in pairs(Races[RaceId].Racers) do
                    local RacerData = Framework.Functions.GetPlayerByCitizenId(cid)
                    if RacerData ~= nil then
                        TriggerClientEvent('pepe-lapraces:client:LeaveRace', RacerData.PlayerData.source, Races[RaceId])
                    end
                end
                table.remove(AvailableRaces, AvailableKey)
                Races[RaceId].LastLeaderboard = {}
                Races[RaceId].Racers = {}
                Races[RaceId].Started = false
                Races[RaceId].Waiting = false
                LastRaces[RaceId] = nil
                TriggerClientEvent('pepe-phone:client:UpdateLapraces', -1)
            else
                TriggerClientEvent('Framework:Notify', source, 'Cuộc đua này chưa bắt đầu.', 'error')
            end
        end
    else
        TriggerClientEvent('Framework:Notify', source, 'Bạn không có quyền để làm điều này', 'error')
    end
end)

Framework.Functions.CreateCallback('pepe-lapraces:server:CanRaceSetup', function(source, cb)
    cb(Config.RaceSetupAllowed)
end)