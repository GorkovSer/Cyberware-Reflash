-- Personal Cyberware Reflash. Native UI and per-implant immutable stat shards.
-- No original vendor/implant records are edited.
local S = {ready=false, elapsed=0, controller=nil, vendor=nil, visible=false,
  custom=false, entry=nil, quote=nil, service=nil, profiles={}, catalog={}, map={}, serial=0, readyRecords={}}
local HUB_ID = 1907111901
local config = {overclock=1.20, operationFee=5, eddiesPerComponent=180, componentDivisor=10, tierPrices={15,30,60,90,120},
  plusPrice=1.15, plusPlusPrice=1.35, range=3.2}
local function L(ru,en) return S.english and en or ru end
local function log(s) print('[CyberwareReflash] '..tostring(s)) end
local function loadJSON(path, fallback)
  local f=io.open(path,'rb'); if not f then return fallback end
  local raw=f:read('*a');f:close()
  local ok,v=pcall(json.decode,raw); if not ok then error(L('Повреждён файл ', 'Corrupted file: ')..path) end
  return v
end
local function persist()
  local f,err=io.open('profiles.json.new','wb'); if not f then return false,err end
  local ok,raw=pcall(json.encode,{version=1,profiles=S.profiles})
  if not ok then f:close();return false,raw end
  local written,why=f:write(raw);f:flush();f:close();if not written then return false,why end
  os.remove('profiles.json.bak')
  local exists=io.open('profiles.json','rb')
  if exists then exists:close();local moved,e=os.rename('profiles.json','profiles.json.bak');if not moved then return false,e end end
  local moved,e=os.rename('profiles.json.new','profiles.json')
  if not moved then os.rename('profiles.json.bak','profiles.json');return false,e end
  return true
end
local function obj(class) return NewObject('CyberwareReflash.'..class) end
local function enum(name) return Enum.new('gamedataStatType',name) end
local function dbid(name) return TweakDBID.new(name) end
local function valid(rec) return rec ~= nil end
local function bridge() return GetSingleton('CyberwareReflash.Bridge') end
local function recordProfile(profile)
  if S.readyRecords[profile.id] then return end
  if not TweakDB:GetRecord(profile.id) then
    assert(TweakDB:CloneRecord(profile.id, 'Items.CyberwareStatsShardStatic'), 'Cannot clone StatsShard')
  end
  local function set(flat,value)
    assert(TweakDB:SetFlat(flat,value), L('Не удалось записать параметр прошивки: ', 'Could not write firmware field: ')..flat)
  end
  local mods={}
  for i=0,3 do mods[#mods+1]=dbid('Items.CyberwareStatsShardStatic_inline'..i) end
  for i,row in ipairs(profile.values) do
    local id=profile.id..'_m'..i
    if not TweakDB:GetRecord(id) then
      assert(TweakDB:CreateRecord(id,'gamedataCombinedStatModifier_Record'), 'Cannot create modifier')
    end
    set(id..'.statType',dbid('BaseStats.'..row.stat))
    set(id..'.modifierType',CName.new('Additive'))
    set(id..'.refObject',CName.new('Self'))
    set(id..'.refStat',dbid('BaseStats.StaticModifierMultiplier'))
    set(id..'.opSymbol',CName.new('*'))
    set(id..'.value',row.raw)
    mods[#mods+1]=dbid(id)
    local extra=({RamOnKillModifierHelper='Modifiers.RamOnKillQualityToggle',
      DamageOverTimePercentBonusModifierHelper='Modifiers.DamageOverTimePercentBonusToggle'})[row.stat]
    if extra and TweakDB:GetRecord(extra) then mods[#mods+1]=dbid(extra) end
  end
  set(profile.id..'.statModifiers',mods)
  set(profile.id..'.statModifierGroups',{
    dbid('ModifierGroups.CyberwareModifierBoosts'),dbid('ModifierGroups.TransferCyberwareModifiersToItem')})
  assert(TweakDB:Update(profile.id), L('Не удалось обновить запись прошивки.', 'Could not update the firmware record.'))
  S.readyRecords[profile.id]=true
  log('Firmware ready: '..profile.id..'; modifiers='..#profile.values)
end
local function newID()
  local id
  repeat S.serial=S.serial+1;id='Items.CRF_'..os.time()..'_'..S.serial until not TweakDB:GetRecord(id)
  return id
end
local function bb()
  local defs=GetAllBlackboardDefs().UIInteractions
  return Game.GetBlackboardSystem():Get(defs),defs
end
local function selection(id,index)
  local b,d=bb();b:SetInt(d.ActiveChoiceHubID,id);b:SetInt(d.SelectedIndex,index)
end
local function hubs()
  local b,d=bb();local value=FromVariant(b:GetVariant(d.DialogChoiceHubs))
  return value and value.choiceHubs or {}
end
local function refreshHub()
  if not S.controller then return end
  local b,d=bb();S.controller:OnDialogsData(b:GetVariant(d.DialogChoiceHubs))
end
local function setVisible(value)
  if S.visible==value then return end
  if not value and S.custom and S.entry then selection(S.entry.id,S.entry.index) end
  S.visible=value;S.custom=false;S.entry=nil
  refreshHub()
end
local function nearVendor(player, vendor)
  if not player or not vendor then return false end
  return Vector4.Distance(player:GetWorldPosition(),vendor:GetWorldPosition())<=config.range
end
local function isScriptVendor(npc)
  if not npc or not npc:IsNPC() or not npc:IsVendor() then return false end
  local typ=npc:GetVendorType()
  if typ~=gamedataVendorType.SkillTrainer and typ~=gamedataVendorType.Tech then return false end
  local vr=TweakDBInterface.GetCharacterRecord(npc:GetRecordID()):VendorID()
  if not vr then return false end
  if typ==gamedataVendorType.SkillTrainer then return true end
  for _,stock in ipairs(vr:ItemStock()) do
    local item=stock:Item()
    if item and item:ItemType() and item:ItemType():Type()==gamedataItemType.Prt_Program then return true end
    local id=item and tostring(item:GetID()) or ''
    if id:find('QuickHack') or id:lower():find('quickhack') then return true end
  end
  local name=tostring(vr:GetID()):lower()
  return name:find('netrunner')~=nil or name:find('quickhack')~=nil
end
local function currentVendor(player)
  local target=Game.GetTargetingSystem():GetLookAtObject(player,true,true)
  if target and nearVendor(player,target) and isScriptVendor(target) then return target end
  return nil
end
local function category(stat)
  if stat:find('Resistance') or stat:find('DamageReduction') or stat:find('Mitigation') or stat=='ItemArmorModifierHelper' or stat=='HealthModifierHelper' then return 'defense' end
  if stat:find('Regen') or stat:find('Healing') or stat:find('HealOn') or stat:find('RamOnKill') then return 'recovery' end
  if stat:find('Damage') or stat:find('Crit') then return 'damage' end
  return 'utility'
end
local function bonusData(entry, value, maximum)
  local b=obj('Bonus');b.stat=entry.stat;b.label=(S.english and entry.labelEN or entry.label)..(entry.unit~='' and (' ('..(S.english and entry.unit=='кг' and 'kg' or entry.unit)..')') or '')
  b.value=value;b.maximum=maximum or 0;b.category=category(entry.stat);return b
end
local function readBonuses(player,item)
  local result={}
  for _,entry in ipairs(S.catalog) do
    local value=bridge():Value(player,item,enum(entry.stat))
    if math.abs(value)>0.000001 then result[#result+1]=bonusData(entry,value*entry.scale) end
  end
  return result
end
local function scan(player,model)
  local items=bridge():Inventory(player)
  for _,row in ipairs(items) do row.bonuses=readBonuses(player,row.item) end
  model.implants=items;model.canApply=false;model.quoteReady=false;S.quote=nil
  if model.implantIndex>=#items then model.implantIndex=0 end
  local current=items[model.implantIndex+1]
  if not current then model.message=L('Нет установленных имплантов с дополнительными бонусами.', 'No equipped cyberware with secondary bonuses found.');return end
  model.message=L('Выбери бонус, который хочешь усилить.', 'Select the bonus you want to improve.');model.normalMaximum=0;model.overclockMaximum=0
  log('Scan: '..#items..' implants; selected '..current.label..'; quality='..current.quality..'; bonuses='..#current.bonuses)
end
local function open()
  local player=Game.GetPlayer()
  if not player or not S.vendor or not nearVendor(player,S.vendor) then return end
  S.english=bridge():IsEnglish(player)
  local model=obj('Model');model.english=S.english;model.text='1.0';model.implantIndex=0;model.bonusIndex=0;model.statIndex=0
  local cat={};for _,entry in ipairs(S.catalog) do cat[#cat+1]=bonusData(entry,0) end
  model.catalog=cat;scan(player,model)
  S.service=Game.GetScriptableServiceContainer():GetService('CyberwareReflash.Service')
  if not S.service then error('Codeware service unavailable') end
  S.service.model=model
  setVisible(false)
  S.service:Show(S.controller)
  log('Native reflash popup requested')
end
local function fingerprint(model, row)
  return tostring(ItemID.GetCombinedHash(row.item))..':'..model.bonusIndex..':'..model.statIndex..':'..model.text
end
local function price(ratio)
  if ratio<=1 then return ratio*ratio end
  if ratio<=1.1 then return math.exp(math.log(3)*(ratio-1)/0.1) end
  return 3*math.exp(math.log(8/3)*(ratio-1.1)/0.1)
end
local function limits(player,model,row,entry)
  local maxima={};for _,e in ipairs(S.catalog) do maxima[#maxima+1]={stat=e.stat,raw=e.maximum} end
  -- The preview inherits the implant's quality and the player's native bonus multipliers.
  recordProfile({id='Items.CRF_CapProbe',values=maxima})
  local preview=bridge():Preview(player,row.item,dbid('Items.CRF_CapProbe'),12345)
  assert(preview,L('Не удалось рассчитать пределы качества.', 'Could not calculate tier limits.'))
  local ss=Game.GetStatsSystem();local caps={};local factors={}
  for _,e in ipairs(S.catalog) do
    local native=ss:GetStatValue(preview:GetStatsObjectID(),enum(e.stat))
    caps[e.stat]=native*e.scale;factors[e.stat]=native/e.maximum
  end
  -- Publish all calculated limits together instead of incrementally updating
  -- elements fetched through the CET-marshaled array.
  local catalog={}
  for _,e in ipairs(S.catalog) do catalog[#catalog+1]=bonusData(e,0,caps[e.stat]) end
  model.catalog=catalog
  model.normalMaximum=caps[entry.stat] or 0
  -- Round down to the same precision the editor can represent.
  model.overclockMaximum=math.floor(model.normalMaximum*config.overclock*100+0.0001)/100
  model.unit=S.english and entry.unit=='кг' and 'kg' or entry.unit
  assert(model.normalMaximum>0.000001,L('Не удалось получить предел бонуса. Изменения заблокированы.', 'Could not determine the bonus limit. Changes are blocked.'))
  return caps,factors
end
local function quote(player,model)
  model.canApply=false;model.quoteReady=false;S.quote=nil
  assert(S.vendor and nearVendor(player,S.vendor), L('Продавец слишком далеко.', 'The vendor is too far away.'))
  local row=model.implants[model.implantIndex+1]
  local entry=S.catalog[model.statIndex+1]
  assert(row and entry,L('Выбери имплант и характеристику.', 'Select cyberware and a stat.'))
  assert(EquipmentSystem.GetData(player):IsEquipped(row.item),L('Имплант больше не установлен.', 'This cyberware is no longer equipped.'))
  local bonuses=readBonuses(player,row.item)
  local old=bonuses[model.bonusIndex+1]
  assert(old and #bonuses<=3,L('Неподдерживаемое число бонусов: операция отменена.', 'Unsupported number of bonuses: operation cancelled.'))
  for i,b in ipairs(bonuses) do assert(i==model.bonusIndex+1 or b.stat~=entry.stat,L('Этот бонус уже есть на импланте.', 'This stat is already present on the cyberware.')) end
  local quality=bridge():Value(player,row.item,enum('Quality'))
  local upgrade=bridge():Value(player,row.item,enum('WasItemUpgraded'))
  local tier=math.min(5,math.max(1,math.floor(quality+0.5)+1))
  local materialTier=math.max(2,tier)
  local material=({'','Items.QuickHackUncommonMaterial1','Items.QuickHackRareMaterial1',
    'Items.QuickHackEpicMaterial1','Items.QuickHackLegendaryMaterial1'})[materialTier]
  local have=Game.GetTransactionSystem():GetItemQuantity(player,ItemID.FromTDBID(dbid(material)))
  local moneyHave=Game.GetTransactionSystem():GetItemQuantity(player,ItemID.FromTDBID(dbid('Items.money')))
  model.moneyHave=moneyHave;model.componentHave=have;model.componentTier=materialTier
  model.componentIcon=dbid('UIIcon.'..TweakDB:GetFlat(material..'.iconPath'))
  local normalized=model.text:gsub(',','.')
  local value=tonumber(normalized)
  assert(value and value==value and value>0 and value<1000000,L('Введи положительное число.', 'Enter a positive number.'))
  local caps,factors=limits(player,model,row,entry)
  local cap=caps[entry.stat]
  assert(cap and cap>0.000001,L('Не удалось получить предел бонуса. Изменения заблокированы.', 'Could not determine the bonus limit. Changes are blocked.'))
  assert(value<=cap*config.overclock+0.0001,string.format(L('Обычный максимум %.2f; с разгоном — %.2f.', 'Normal maximum %.2f; with overclock — %.2f.'),cap,cap*config.overclock))
  local ratio=value/cap
  local previousRatio=old.stat==entry.stat and old.value/cap or 0
  if old.stat==entry.stat and math.abs(old.value-value)<=0.005 then
    model.message=L('Это текущее значение. Увеличь его кнопкой + или выбери максимум.', 'This is the current value. Press + or choose a maximum to improve it.');return
  end
  local plus=upgrade>=10 and config.plusPlusPrice or (upgrade>=9 and config.plusPrice or 1)
  local nominalCost=math.ceil(config.operationFee+config.tierPrices[tier]*plus*math.max(0,price(ratio)-price(previousRatio)))
  local cost=math.ceil(nominalCost/config.componentDivisor)
  local moneyCost=nominalCost*config.eddiesPerComponent
  local values={}
  for i,b in ipairs(bonuses) do
    local stat=i==model.bonusIndex+1 and entry.stat or b.stat
    local amount=i==model.bonusIndex+1 and value or b.value
    local e=S.map[stat];local f=factors[stat]
    assert(e and f and f>0,L('Не удалось сохранить один из существующих бонусов.', 'Could not preserve an existing bonus.'))
    values[#values+1]={stat=stat,raw=amount/e.scale/f}
  end
  model.moneyCost=moneyCost;model.moneyHave=moneyHave
  model.componentCost=cost;model.componentHave=have;model.componentTier=materialTier
  model.quoteReady=true
  model.message=ratio>1 and L('РАЗГОН: повышенная цена.', 'OVERCLOCK: premium cost.') or L('К оплате: деньги и компоненты скриптов.', 'Payment requires both eddies and quickhack components.')
  model.canApply=have>=cost and moneyHave>=moneyCost
  S.quote={key=fingerprint(model,row),item=row.item,cost=cost,moneyCost=moneyCost,material=material,values=values,
    expected=value,stat=entry.stat,previous=bonuses}
  if have<cost then model.message=model.message..L(' Недостаточно компонентов.', ' Not enough quickhack components.') end
  if moneyHave<moneyCost then model.message=model.message..L(' Недостаточно эдди.', ' Not enough eddies.') end
end
local function prepareLimits(player,model)
  model.canApply=false;model.quoteReady=false;S.quote=nil
  local row=model.implants[model.implantIndex+1]
  local entry=S.catalog[model.statIndex+1]
  assert(row and entry,L('Выбери имплант и характеристику.', 'Select cyberware and a stat.'))
  limits(player,model,row,entry)
  if model.text=='' then model.text=string.format('%.2f',math.floor(model.normalMaximum*100)/100) end
  quote(player,model)
end
local function apply(player,model)
  local row=model.implants[model.implantIndex+1];local original=S.quote
  assert(original and row and original.key==fingerprint(model,row),L('Параметры изменены — рассчитай цену заново.', 'Settings changed. Recalculate the cost.'))
  -- Recheck player multipliers, current implant, vendor distance, duplicates and resources.
  quote(player,model)
  local q=S.quote
  assert(q and model.canApply and q.cost==original.cost and q.moneyCost==original.moneyCost,L('Цена изменилась или не хватает компонентов.', 'The price changed or you lack the required resources.'))
  local profile={id=newID(),values=q.values}
  recordProfile(profile)
  local preview=bridge():Preview(player,row.item,dbid(profile.id),12345)
  assert(preview,L('Не удалось проверить новую прошивку.', 'Could not verify the new firmware.'))
  for i,b in ipairs(q.previous) do
    local expected=i==model.bonusIndex+1 and q.expected or b.value
    local stat=i==model.bonusIndex+1 and q.stat or b.stat
    local actual=Game.GetStatsSystem():GetStatValue(preview:GetStatsObjectID(),enum(stat))*S.map[stat].scale
    assert(math.abs(actual-expected)<0.015,L('Проверка прошивки не совпала с расчётом. Ресурсы не списаны.', 'Firmware verification did not match the calculation. No resources were spent.'))
  end
  S.profiles[#S.profiles+1]=profile
  local saved,why=persist();assert(saved,L('Не удалось сохранить прошивку: ', 'Could not save the firmware: ')..tostring(why))
  local expected={}
  for i,b in ipairs(q.previous) do
    local stat=i==model.bonusIndex+1 and q.stat or b.stat
    local amount=i==model.bonusIndex+1 and q.expected or b.value
    local e=obj('Bonus');e.kind=enum(stat);e.value=amount/S.map[stat].scale;expected[#expected+1]=e
  end
  local success=bridge():Apply(player,row.item,dbid(profile.id),math.random(100000,2000000000),dbid(q.material),q.cost,q.moneyCost,expected)
  assert(success,L('Игра отклонила замену. Проверь имплант; компоненты не списаны.', 'The game rejected the replacement. Check your cyberware; reserved resources were refunded.'))
  log('APPLIED '..profile.id..' stat='..q.stat..' value='..q.expected..' cost='..q.cost..' eddies='..q.moneyCost)
  scan(player,model)
  local current=model.implants[model.implantIndex+1]
  for i,b in ipairs(current.bonuses) do if b.stat==q.stat then model.bonusIndex=i-1;break end end
  quote(player,model)
  model.message=L('Перепрошивка завершена. Проверь бонус на карточке импланта.', 'Reflash complete. Check the bonus on your cyberware card.')
end
registerForEvent('onInit',function()
  local ok,err=pcall(function()
    S.catalog=loadJSON('catalog.json',{})
    assert(#S.catalog==36,'Catalog missing')
    for _,e in ipairs(S.catalog) do S.map[e.stat]=e end
    local data=loadJSON('profiles.json',nil) or loadJSON('profiles.json.bak',{profiles={}})
    S.profiles=data.profiles or {}
    for _,p in ipairs(S.profiles) do recordProfile(p) end
    log('Initialized; '..#S.profiles..' persistent per-implant profiles')
    Observe('InteractionUIBase','OnInitialize',function(this) S.controller=this end)
    Observe('InteractionUIBase','OnDialogsData',function(this) S.controller=this end)
    Override('InteractionUIBase','OnDialogsData',function(this,value,wrapped)
      if not S.visible then return wrapped(value) end
      local data=FromVariant(value);local list={}
      for _,h in ipairs(data.choiceHubs) do if h.id~=HUB_ID then list[#list+1]=h end end
      local hub=gameinteractionsvisListChoiceHubData.new()
      hub.id=HUB_ID;hub.title=L('УСЛУГИ НЕТРАННЕРА', 'NETRUNNER SERVICES');hub.hubPriority=-1
      hub.activityState=gameinteractionsvisEVisualizerActivityState.Active
      local choice=gameinteractionsvisListChoiceData.new()
      choice.localizedName=L('Перепрошивка имплантов', 'Cyberware reflash');choice.inputActionName='None'
      local kind=gameinteractionsChoiceTypeWrapper.new();kind:SetType(gameinteractionsChoiceType.QuestImportant);choice.type=kind
      hub.choices={choice};list[#list+1]=hub;data.choiceHubs=list
      wrapped(ToVariant(data))
    end)
    -- One extra hub. Preserve the engine's original cursor when entering/leaving it.
    Override('PlayerPuppet','OnAction',function(this,action,consumer,wrapped)
      if S.visible then
        local pressed=action:GetType(action)==gameinputActionType.BUTTON_PRESSED
        local name=Game.NameToString(action:GetName(action))
        if pressed then
          local b,d=bb();local list=hubs();local id=b:GetInt(d.ActiveChoiceHubID);local index=b:GetInt(d.SelectedIndex)
          if name=='ChoiceApply' and id==HUB_ID then
            consumer:Consume();local ok,e=pcall(open);if not ok then log(e) end;return
          end
          local down=name=='ChoiceScrollDown';local up=name=='ChoiceScrollUp'
          if down or up then
            if id==HUB_ID and S.entry then
              local entry=S.entry;S.custom=false;S.entry=nil;selection(entry.id,entry.index)
              if entry.down~=down then consumer:Consume();return end
            elseif #list>0 then
              local edge=down and list[#list] or list[1]
              local boundary=down and #edge.choices-1 or 0
              if id==edge.id and index==boundary then
                S.entry={id=id,index=index,down=down};S.custom=true
                selection(HUB_ID,0);consumer:Consume();return
              end
            end
          end
        end
      end
      return wrapped(action,consumer)
    end)
    S.ready=true
  end)
  if not ok then log('INIT ERROR: '..tostring(err)) end
end)
registerForEvent('onUpdate',function(dt)
  if not S.ready then return end
  S.elapsed=S.elapsed+dt;if S.elapsed<0.15 then return end;S.elapsed=0
  local ok,err=pcall(function()
    local player=Game.GetPlayer()
    if not player then setVisible(false);S.vendor=nil;S.service=nil;return end
    if S.service and S.service.opened then
      local model=S.service.model
      if model and model.request~=0 then
        local request=model.request;model.request=0
        local done,why=pcall(function()
          if request==1 then scan(player,model) elseif request==2 then quote(player,model) elseif request==3 then apply(player,model) elseif request==4 then prepareLimits(player,model) end
        end)
        if not done then model.canApply=false;model.message=tostring(why):gsub('^.-:%d+: ','');log('Operation: '..tostring(why)) end
        if S.service.popup then S.service.popup:Refresh() end
      end
      return
    end
    S.english=bridge():IsEnglish(player)
    local vendor=currentVendor(player)
    S.vendor=vendor
    local menu=Game.GetBlackboardSystem():Get(GetAllBlackboardDefs().UI_System):GetBool(GetAllBlackboardDefs().UI_System.IsInMenu)
    setVisible(vendor~=nil and not menu)
    if S.visible and #hubs()==0 then selection(HUB_ID,0);S.custom=true end
  end)
  if not ok then
    S.elapsed=-2 -- Avoid flooding the log if another mod changes an API.
    log('Update: '..tostring(err))
  end
end)
registerForEvent('onShutdown',function() if S.visible then pcall(function() setVisible(false) end) end end)
return {version='0.1.0', price=price, state=S}
