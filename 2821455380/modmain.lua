--自动钓鱼
local _G = GLOBAL
local key = GetModConfigData("KEY")
local highspeed_mode = GetModConfigData("highspeed_mode")

local function DebugPrint(debug_string)
    if not TUNING.DEBUG_MODE then return end
    print('[DEBUG]'..debug_string)
end

local function gzlazy_get_backpack()
    local gzlazy_backpack = GLOBAL.ThePlayer.replica.inventory:GetEquippedItem("back") or GLOBAL.ThePlayer.replica.inventory:GetEquippedItem("body")
    if not gzlazy_backpack then
        return nil
    end
    if not gzlazy_backpack:HasTag("backpack") then
        return nil
    end
    return gzlazy_backpack
end

local function GetItemFromPlayerInvAndBack(prefab)
    local invitems = _G.ThePlayer.replica.inventory:GetItems()
    local backpack = gzlazy_get_backpack()
    local packitems = backpack and backpack.replica.container and
                          backpack.replica.container:GetItems() or nil
    local itemlist = {}
    if invitems then
        for k, v in pairs(invitems) do
            if v.prefab == prefab then table.insert(itemlist, v) end
        end
    end
    if packitems then
        for k, v in pairs(packitems) do
            if v.prefab == prefab then table.insert(itemlist, v) end
        end
    end
    return itemlist
end

local function RepairAct(item, fuel)

    if item == nil or fuel == nil then return end

    if not _G.ACTIONS.REPAIRCOMMON then
        DebugPrint("检测不到 _G.ACTIONS.REPAIRCOMMON")
        return false
    end

    local playercontroller = _G.ThePlayer.components.playercontroller
    local act = _G.BufferedAction(_G.ThePlayer, item, _G.ACTIONS.REPAIRCOMMON, fuel)
    local function cb()
        _G.SendRPCToServer(_G.RPC.ControllerUseItemOnItemFromInvTile, act.action.code, item, fuel, act.action.mod_name)
    end
    if _G.ThePlayer.components.locomotor then
        act.preview_cb = cb
    else
        cb()
    end
    playercontroller:DoAction(act)
    return true
end

local function TakeLure(pond)
    local actions = _G.ACTIONS.CHANGE_TACKLE

    local pond_loot = {
        pond={--池塘
            "oceanfishinglure_spinner_red",
            "oceanfishinglure_spoon_red",
        },
        pond_mos={--沼泽池塘
            "oceanfishinglure_spinner_green",
            "oceanfishinglure_spoon_green",
        },
        pond_cave={--洞穴池塘
            "oceanfishinglure_spinner_blue",
            "oceanfishinglure_spoon_blue",
        },
        lava_pond={--岩浆池
            "oceanfishinglure_hermit_heavy",
        },
        medal_seapond={--船上钓鱼池
            --季节鱼饵
            "oceanfishinglure_hermit_rain",
            "oceanfishinglure_hermit_snow",
            "oceanfishinglure_hermit_drowsy",
            "oceanfishinglure_hermit_heavy",
            --旋转亮片
            "oceanfishinglure_spinner_red",
            "oceanfishinglure_spinner_green",
            "oceanfishinglure_spinner_blue",
            --匙形鱼饵
            "oceanfishinglure_spoon_red",
            "oceanfishinglure_spoon_green",
            "oceanfishinglure_spoon_blue",
        },
        oasislake={--湖泊
            --弯曲的叉子
            "trinket_17",
            --季节鱼饵
            "oceanfishinglure_hermit_rain",
            "oceanfishinglure_hermit_snow",
            "oceanfishinglure_hermit_drowsy",
            "oceanfishinglure_hermit_heavy",
            --旋转亮片
            "oceanfishinglure_spinner_red",
            "oceanfishinglure_spinner_green",
            "oceanfishinglure_spinner_blue",
            --匙形鱼饵
            "oceanfishinglure_spoon_red",
            "oceanfishinglure_spoon_green",
            "oceanfishinglure_spoon_blue",
        },
    }

    local gzlazy_fishingrod = GLOBAL.ThePlayer.replica.inventory:GetEquippedItem("hands")
    if not gzlazy_fishingrod and gzlazy_fishingrod.prefab ~= "medal_fishingrod" then return end
    local equiping_lure = gzlazy_fishingrod.replica.container:GetItemInSlot(1)

    local lure
    -- 查找身上符合条件的鱼饵
    local pond_allow_lure = pond_loot[pond.prefab]

    for i = 1, #pond_allow_lure do 
        -- 判断当前装备的鱼饵是否已经是符合条件的鱼饵，如果是则不进行任何操作
        if equiping_lure and equiping_lure.prefab == pond_allow_lure[i] then return end
        lure = GetItemFromPlayerInvAndBack(pond_allow_lure[i])
        if _G.next(lure) then
            break
        end
    end
    if not _G.next(lure) then
        return
    end
    -- 装备鱼饵
    _G.SendRPCToServer(_G.RPC.UseItemFromInvTile, _G.ACTIONS.CHANGE_TACKLE.code, lure[1])
end

AddClassPostConstruct("widgets/controls", function(self)
    self.inst:DoTaskInTime(0, function()
        ---------------------------------------------------------------------------
        GLOBAL.TheInput:AddKeyDownHandler(_G[key], function()
            if GLOBAL.ThePlayer == nil then
                return
            end

            if GLOBAL.ThePlayer.gzlevel_fishing_thread then
                GLOBAL.ThePlayer.gzlevel_fishing_thread:SetList(nil)
                GLOBAL.ThePlayer.gzlevel_fishing_thread = nil
                --提示开启或关闭
                if _G.ThePlayer.components.talker then
                    _G.ThePlayer.components.talker:Say("自动钓鱼-关闭")
                end
                return
            end
            GLOBAL.ThePlayer.gzlazy_start_position = GLOBAL.ThePlayer:GetPosition()

            -- 自动搓鱼竿
            local rpc_id = nil
            for k,v in pairs(GLOBAL.AllRecipes) do
                if v.name == "fishingrod" then
                    rpc_id = v.rpc_id
                end
            end
            -- 提示开启或关闭
            if _G.ThePlayer.components.talker then
                _G.ThePlayer.components.talker:Say("自动钓鱼-开启")
            end
            local gzlazy_start_position = GLOBAL.ThePlayer.gzlazy_start_position
            local gzlazy_controller = GLOBAL.ThePlayer.components.playercontroller
            local gzlazy_fishingrod = GLOBAL.ThePlayer.replica.inventory:GetEquippedItem("hands")
            local gzlazy_inventory = GLOBAL.ThePlayer.replica.inventory

            -- 寻找并装备鱼竿
            local function gzlazy_equip_fishingrod()
                local fishingrod = nil
                -- 优先玻璃钓竿
                local medal_fishingrod = GetItemFromPlayerInvAndBack("medal_fishingrod")
                if _G.next(medal_fishingrod) then
                    return medal_fishingrod[1]
                end
                for i = 1, gzlazy_inventory:GetNumSlots() do
                    local item = gzlazy_inventory:GetItemInSlot(i)
                    if item and item:HasTag("fishingrod") then
                        DebugPrint("在身上找到钓竿")
                        fishingrod = item
                        break
                    end
                end
                local backpack = gzlazy_get_backpack()
                if backpack and not fishingrod then
                    for i = 1, backpack.replica.container:GetNumSlots() do
                        local item = backpack.replica.container:GetItemInSlot(i)
                        if item and item:HasTag("fishingrod") then
                            DebugPrint("在背包找到钓竿")
                            fishingrod = item
                            break
                        end
                    end
                end
                return fishingrod
            end

            -- 手持不是鱼竿则尝试装备鱼竿，身上必须先有一根鱼竿才能开始工作
            if not gzlazy_fishingrod or not gzlazy_fishingrod:HasTag("fishingrod") then
                local fishingrod = gzlazy_equip_fishingrod()
                if not fishingrod then
                    DebugPrint("没找到钓竿")
                    return
                end
                DebugPrint("装备钓竿")
                gzlazy_inventory:UseItemFromInvTile(fishingrod)
            end

            GLOBAL.ThePlayer.gzlevel_fishing_thread = GLOBAL.ThePlayer:StartThread(function()
                local gzlazy_fishing = true
                local gzlazy_fishing_ponds = GLOBAL.TheSim:FindEntities(GLOBAL.ThePlayer.gzlazy_start_position.x, 0, GLOBAL.ThePlayer.gzlazy_start_position.z, 20, { "fishable" }, { "locomotor", "INLIMBO" })
                local gzlazy_pond_index = 1
                local gzlazy_reel_count = 0
                local gzlazy_now_time = _G.TheWorld.state.cycles + _G.TheWorld.state.time

                local oasis_pond = GLOBAL.FindEntity(GLOBAL.ThePlayer, 40, function(guy)
                    return guy:HasTag("fishable") and guy:GetDistanceSqToPoint(gzlazy_start_position:Get()) < 14 * 14 and guy.prefab == "oasislake"
                end, nil, {"INLIMBO", "noauradamage"})

                if oasis_pond ~= nil then
                    DebugPrint("找到湖泊")
                    table.insert(gzlazy_fishing_ponds, 1, oasis_pond)
                end

                -- 如果身上没有玻璃钓竿，就去除岩浆池
                if not _G.next(GetItemFromPlayerInvAndBack("medal_fishingrod")) and gzlazy_fishingrod and gzlazy_fishingrod.prefab ~= "medal_fishingrod" then
                    DebugPrint("没有玻璃钓竿，去除岩浆池")
                    local count = 0
                    for i=1, #gzlazy_fishing_ponds do
                        if gzlazy_fishing_ponds[i - count].prefab == "lava_pond" then
                            table.remove(gzlazy_fishing_ponds, i - count)
                            count = count + 1
                        end
                    end
                end

                while gzlazy_fishing do
                    local now_pond = gzlazy_fishing_ponds[gzlazy_pond_index]
                    local gzlazy_inventory = GLOBAL.ThePlayer.replica.inventory

                    if not now_pond then
                        DebugPrint("没有找到池塘")
                        return
                    end

                    -- 钓鱼期间鱼竿用完再做
                    local gzlazy_fishingrod = GLOBAL.ThePlayer.replica.inventory:GetEquippedItem("hands")
                    -- 检查是否正在使用玻璃钓竿
                    if gzlazy_fishingrod and gzlazy_fishingrod.prefab == "medal_fishingrod" then
                        -- 检查玻璃钓竿耐久度
                        if gzlazy_fishingrod.replica and gzlazy_fishingrod.replica._ and gzlazy_fishingrod.replica._.inventoryitem and
                                gzlazy_fishingrod.replica._.inventoryitem.classified and gzlazy_fishingrod.replica._.inventoryitem.classified.percentused:value() <= 0 then
                            -- 使用蜘蛛网给玻璃钓竿增加耐久
                            DebugPrint("执行加耐久操作")
                            local fuel = GetItemFromPlayerInvAndBack("silk")
                            if _G.next(fuel) then
                                DebugPrint("检测到身上的蜘蛛丝")
                                if not RepairAct(gzlazy_fishingrod, fuel[1]) then
                                    DebugPring("无法补充耐久")
                                    return
                                end
                            else
                                if _G.ThePlayer.components.talker then _G.ThePlayer.components.talker:Say("蜘蛛网不足，无法补充耐久") end
                                return
                            end
                            GLOBAL.Sleep(1)
                        end
                        -- 连接鱼饵
                        TakeLure(now_pond)
                    elseif not gzlazy_fishingrod or not gzlazy_fishingrod:HasTag("fishingrod") then
                        local fishingrod = gzlazy_equip_fishingrod()
                        if not fishingrod and GLOBAL.ThePlayer.replica.builder:CanBuild("fishingrod") then
                            if _G.ThePlayer.components.talker then _G.ThePlayer.components.talker:Say("正在做鱼竿") end
                            GLOBAL.SendRPCToServer(GLOBAL.RPC.MakeRecipeFromMenu, rpc_id, nil)
                            GLOBAL.Sleep(2)
                        else
                            if _G.ThePlayer.components.talker then _G.ThePlayer.components.talker:Say("鱼竿材料不足") end
                            return
                        end
                        GLOBAL.Sleep(highspeed_mode and 0.3 or 1)
                        -- 再次装备仍然未装备则退出
                        gzlazy_fishingrod = GLOBAL.ThePlayer.replica.inventory:GetEquippedItem("hands")
                        if not gzlazy_fishingrod or not gzlazy_fishingrod:HasTag("fishingrod") then
                            fishingrod = gzlazy_equip_fishingrod()
                            if not fishingrod then
                                if _G.ThePlayer.components.talker then _G.ThePlayer.components.talker:Say("再次尝试装备鱼竿失败") end
                                return
                            end
                            gzlazy_inventory:UseItemFromInvTile(fishingrod)
                            GLOBAL.Sleep(0.3)
                        end
                    end

                    if gzlazy_fishing_ponds ~= nil and gzlazy_fishing then
                        local now_pond_position = now_pond:GetPosition()
                        local controlmods = gzlazy_controller:EncodeControlMods()
                        local lmb, rmb = GLOBAL.ThePlayer.components.playeractionpicker:DoGetMouseActions(now_pond_position, now_pond)
                        if lmb then
                            local action_string = lmb and lmb:GetActionString() or ""
                            if action_string == GLOBAL.STRINGS.ACTIONS.REEL.REEL then
                                GLOBAL.Sleep(highspeed_mode and 0.1 or 0.5)
                                gzlazy_reel_count = gzlazy_reel_count + 1
                                gzlazy_now_time = _G.TheWorld.state.cycles + _G.TheWorld.state.time
                                if gzlazy_reel_count >= 10 then
                                    gzlazy_reel_count = 0
                                    DebugPrint("切换鱼塘")
                                    gzlazy_pond_index = gzlazy_pond_index + 1
                                    if gzlazy_pond_index > #gzlazy_fishing_ponds then
                                        DebugPrint("回到第一个鱼塘")
                                        gzlazy_pond_index = 1
                                    end
                                end
                            end
                            -- 下钩
                            if action_string ~= GLOBAL.STRINGS.ACTIONS.REEL.CANCEL then
                                gzlazy_controller:DoAction(lmb)
                                GLOBAL.Sleep(highspeed_mode and 0.1 or 0.3)
                                GLOBAL.SendRPCToServer(GLOBAL.RPC.LeftClick, lmb.action.code, now_pond_position.x, now_pond_position.z, now_pond, false, controlmods, false, lmb.action.mod_name)
                            -- 超过半天还没上钩，代表已经没鱼了
                            elseif _G.TheWorld.state.cycles + _G.TheWorld.state.time - gzlazy_now_time >= 0.2 then
                                DebugPrint("鱼塘没鱼")
                                gzlazy_reel_count = gzlazy_reel_count + 1
                                if #gzlazy_fishing_ponds == 1 then
                                    DebugPrint("重新钓鱼")
                                    gzlazy_controller:DoAction(lmb)
                                    GLOBAL.Sleep(highspeed_mode and 0.1 or 0.5)
                                    GLOBAL.SendRPCToServer(GLOBAL.RPC.LeftClick, lmb.action.code, now_pond_position.x, now_pond_position.z, now_pond, false, controlmods, false, lmb.action.mod_name)
                                else
                                    DebugPrint("切换鱼塘")
                                    gzlazy_pond_index = gzlazy_pond_index + 1
                                    if gzlazy_pond_index > #gzlazy_fishing_ponds then
                                        DebugPrint("回到第一个鱼塘")
                                        gzlazy_pond_index = 1
                                    end
                                end
                                gzlazy_now_time = _G.TheWorld.state.cycles + _G.TheWorld.state.time
                                gzlazy_reel_count = 0
                            end
                        end
                    else
                        gzlazy_fishing = false
                        GLOBAL.ThePlayer.gzlevel_fishing_thread:SetList(nil)
                        GLOBAL.ThePlayer.gzlevel_fishing_thread = nil
                        if _G.ThePlayer.components.talker then
                            GLOBAL.Sleep(0.3)
                            _G.ThePlayer.components.talker:Say("自动钓鱼-关闭")
                        end --提示开启或关闭
                    end
                    GLOBAL.Sleep(highspeed_mode and 0.1 or 0.3)
                end
            end)
        end)
        ---------------------------------------------------------------------------
    end)
end)
