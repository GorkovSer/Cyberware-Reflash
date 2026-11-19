from pathlib import Path
from lupa.luajit21 import LuaRuntime
import json
ROOT=Path(__file__).resolve().parents[1]
runtime=LuaRuntime(unpack_returned_tuples=True)
source=(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/CyberwareReflash/init.lua').read_text(encoding='utf8')
runtime.execute('''
Enum={new=function(_,v)return v end}; TweakDBID={new=function(v)return v end}
NewObject=function()return {} end
CName={new=function(v)return v end}
RECORDS={};FLATS={};UPDATES={};CLONES=0;FAIL_FLAT=nil;FAIL_UPDATE=false
TweakDB={}
function TweakDB:GetRecord(id)return RECORDS[id] end
function TweakDB:GetFlat()return 'material_qh_epic' end
function TweakDB:CloneRecord(id,base)if RECORDS[id] then return false end;CLONES=CLONES+1;RECORDS[id]=true;return true end
function TweakDB:CreateRecord(id,kind)if RECORDS[id] then return false end;RECORDS[id]=true;return true end
function TweakDB:SetFlat(id,value)if id==FAIL_FLAT then return false end;FLATS[id]=value;return true end
function TweakDB:Update(id)if FAIL_UPDATE then return false end;UPDATES[id]=(UPDATES[id] or 0)+1;return RECORDS[id]~=nil end
ItemID={GetCombinedHash=function(v)return v end,FromTDBID=function(v)return v end}
EquipmentSystem={GetData=function()return {IsEquipped=function()return true end} end}
local b={}
CAPS={};CURRENT={};QUALITY=4;UPGRADE=8;HAVE=99999;MONEY=9999999
function b:Value(p,item,stat) if stat=='Quality' then return QUALITY elseif stat=='WasItemUpgraded' then return UPGRADE end;return CURRENT[stat] or 0 end
function b:Preview()return {GetStatsObjectID=function()return 77 end} end
GetSingleton=function()return b end
Game={GetStatsSystem=function()return {GetStatValue=function(_,id,stat)return CAPS[stat] or 0 end} end,
GetTransactionSystem=function()return {GetItemQuantity=function(_,player,item)if item=='Items.money' then return MONEY end;return HAVE end} end}
''')
chunk=source[:source.index("registerForEvent('onInit'")]
chunk += "\nnearVendor=function()return true end\nreturn {state=S,quote=quote,limits=prepareLimits,price=price,bonusData=bonusData,recordProfile=recordProfile}"
api=runtime.execute(chunk);g=runtime.globals();state=api['state']
def profile(name):
 return runtime.table_from({'id':name,'values':runtime.table_from([runtime.table_from({'stat':'CritChanceBonusModifierHelper','raw':1})])})
# The mock API intentionally has Update and no UpdateRecord, matching CET 1.38.1.
p=profile('Items.CRF_TestCreate');api['recordProfile'](p)
assert g.UPDATES[p['id']]==1 and g.FLATS[p['id']+'_m1.value']==1
api['recordProfile'](p);assert g.UPDATES[p['id']]==1
# An interrupted write must never be marked ready and must be repairable on retry.
p=profile('Items.CRF_TestRetry');g.FAIL_FLAT=p['id']+'_m1.value'
try:api['recordProfile'](p)
except Exception:pass
else:raise AssertionError('Failed flat write accepted')
assert not state['readyRecords'][p['id']]
g.FAIL_FLAT=None;api['recordProfile'](p);assert state['readyRecords'][p['id']]
p=profile('Items.CRF_TestUpdate');g.FAIL_UPDATE=True
try:api['recordProfile'](p)
except Exception:pass
else:raise AssertionError('Failed record update accepted')
assert not state['readyRecords'][p['id']]
g.FAIL_UPDATE=False;api['recordProfile'](p);assert state['readyRecords'][p['id']]
print('PASS: fresh firmware records, CET Update API, repeat calls, interrupted writes and failed updates retried safely')
entries=json.loads((ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/CyberwareReflash/catalog.json').read_text(encoding='utf8'))
catalog=runtime.table();mapping=runtime.table();models=runtime.table()
for i,e in enumerate(entries,1):
 row=runtime.table_from(e);catalog[i]=row;mapping[e['stat']]=row;models[i]=api['bonusData'](row,0,0);g.CAPS[e['stat']]=e['maximum']
state['catalog']=catalog;state['map']=mapping;state['vendor']=True
index=next(i for i,e in enumerate(entries) if e['stat']=='CritChanceBonusModifierHelper')
stat=entries[index]['stat'];g.CURRENT[stat]=0.5
model=runtime.table_from({'implants':runtime.table_from([runtime.table_from({'item':'test-implant'})]),'catalog':models,'implantIndex':0,'bonusIndex':0,'statIndex':index,'text':'1'})
def quote(text):
 model['text']=text;api['quote'](True,model);return state['quote']
assert quote('1')['cost']==10
assert state['quote']['moneyCost']==17100 and model['moneyCost']==17100 and model['quoteReady']
g.MONEY=17099;quote('1');assert not model['canApply'] and 'Недостаточно эдди' in model['message']
g.MONEY=17100;quote('1');assert model['canApply']
g.MONEY=9999999
assert quote('0,75')['cost']==5 # comma is a decimal separator, never a tonumber base
assert abs(model['normalMaximum']-1)<1e-6 and abs(model['overclockMaximum']-1.2)<1e-6
assert quote('1.2')['cost']==94
g.QUALITY=3;g.UPGRADE=6;g.CURRENT[stat]=0.00001
assert quote('1.2')['cost']==73 and state['quote']['moneyCost']==130500
g.QUALITY=4;g.UPGRADE=8;g.CURRENT[stat]=0.5
for text in ['1.21','-1','0','nan','abc','1,2,3']:
 try:quote(text)
 except Exception:pass
 else:raise AssertionError('Accepted invalid input '+text)
 assert not model['canApply']
quote('0.50');assert not model['canApply'] and state['quote'] is None
g.HAVE=1;quote('1');assert not model['canApply'] and 'Недостаточно' in model['message'];g.HAVE=99999
# Quality 1 means T2; it must not be divided by two or mistaken for a T1 upgrade.
g.QUALITY=1;g.UPGRADE=2
assert quote('1')['cost']==3 and state['quote']['material']=='Items.QuickHackUncommonMaterial1'
g.QUALITY=4;g.UPGRADE=10
assert quote('1')['cost']==13
# Existing different stat blocks duplication; it is not silently replaced.
other=entries[0]['stat'];g.CURRENT[other]=2;model['statIndex']=0
model['bonusIndex']=1 # second row is original crit chance, first is armor
try:quote('3')
except Exception as error:assert 'уже есть' in str(error)
else:raise AssertionError('Duplicate stat accepted')
g.CURRENT[other]=None;model['bonusIndex']=0;model['statIndex']=index
# Limits are available before entering a value; new-type default gets a usable cap.
model['text']='';api['limits'](True,model);assert model['text']=='1.00'
assert len([models[i]['category'] for i in range(1,len(entries)+1)])==36
assert all(model['catalog'][i]['maximum']>0 for i in range(1,len(entries)+1))
assert {models[i]['category'] for i in range(1,len(entries)+1)}=={'damage','defense','recovery','utility'}
# Increasing in parts includes another fee and cannot lower total payment.
g.UPGRADE=8;g.CURRENT[stat]=0.5
direct=quote('1')['cost'];first=quote('0.75')['cost'];g.CURRENT[stat]=0.75;second=quote('1')['cost']
assert first+second>=direct
print('PASS: real LuaJIT quote code: decimal input, caps, overclock, materials/quality, same bonus, duplicate rejection, insufficient resources, categories, split-payment pricing')

state['english']=True
g.CURRENT[stat]=0.5
quote('1');assert 'Payment requires both' in model['message'] and model['canApply']
g.MONEY=0;quote('1');assert 'Not enough eddies' in model['message'] and not model['canApply']
g.MONEY=9999999;g.HAVE=0;quote('1');assert 'Not enough quickhack components' in model['message'] and not model['canApply']
g.HAVE=99999
quote('0.5');assert 'current value' in model['message'] and not model['quoteReady'] and model['moneyHave']==9999999
for i,e in enumerate(entries,1):
 label=api['bonusData'](catalog[i],0,0)['label']
 assert e['labelEN'] in label
 assert not any('А'<=c<='я' or c in 'Ёё' for c in label),label
print('PASS: split pricing (73 components + 130500 eddies sample); both balances required; current balances on unchanged bonus; all 36 English labels and English errors')
