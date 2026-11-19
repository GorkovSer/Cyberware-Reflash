module CyberwareReflash
import Codeware.UI.*

public class Bonus extends IScriptable {
 public let kind: gamedataStatType;
 public let stat: String;
 public let label: String;
 public let value: Float;
 public let maximum: Float;
 public let category: String;
}
public class Implant extends IScriptable {
 public let item: ItemID;
 public let label: String;
 public let quality: Float;
 public let icon: TweakDBID;
 public let bonuses: array<ref<Bonus>>;
}
public class Model extends IScriptable {
 public let implants: array<ref<Implant>>;
 public let catalog: array<ref<Bonus>>;
 public let implantIndex: Int32;
 public let bonusIndex: Int32;
 public let statIndex: Int32;
 public let text: String;
 public let message: String;
 public let canApply: Bool;
 public let request: Int32;
 public let normalMaximum: Float;
 public let overclockMaximum: Float;
 public let unit: String;
 public let english: Bool;
 public let quoteReady: Bool;
 public let moneyCost: Int32;
 public let moneyHave: Int32;
 public let componentCost: Int32;
 public let componentHave: Int32;
 public let componentTier: Int32;
 public let componentIcon: TweakDBID;
}
public class Service extends ScriptableService {
 public let model: ref<Model>;
 public let popup: wref<ReflashPopup>;
 public let opened: Bool;
 private cb func OnUninitialize() {
  this.model = null;
  this.popup = null;
  this.opened = false;
 }
 public func Show(controller: ref<inkGameController>) {
  if this.opened || !IsDefined(this.model) { return; }
  let popup = new ReflashPopup();
  popup.state = this.model;
  popup.service = this;
  this.popup = popup;
  this.opened = true;
  popup.Open(controller);
 }
}

// Only public instance-level inventory access is exposed to CET.
public class Bridge extends IScriptable {
 public static func IsEnglish(player: ref<PlayerPuppet>) -> Bool {
  let lang = GameInstance.GetSettingsSystem(player.GetGame()).GetVar(n"/language", n"OnScreen") as ConfigVarListName;
  return IsDefined(lang) && Equals(lang.GetValue(), n"en-us");
 }
 public static func Inventory(player: ref<PlayerPuppet>) -> array<ref<Implant>> {
  let inventory: array<wref<gameItemData>>;
  let result: array<ref<Implant>>;
  let shard: InnerItemData;
  let ts = GameInstance.GetTransactionSystem(player.GetGame());
  ts.GetItemList(player, inventory);
  for data in inventory {
   if EquipmentSystem.GetData(player).IsEquipped(data.GetID()) && data.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") {
    data.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");
    if IsDefined(InnerItemData.GetStaticData(shard)) && Equals(InnerItemData.GetStaticData(shard).ItemType().Type(), gamedataItemType.CyberwareStatsShard) {
     let row = new Implant();
     row.item = data.GetID();
     row.label = GetLocalizedTextByKey(TweakDBInterface.GetItemRecord(ItemID.GetTDBID(row.item)).DisplayName());
     row.icon = TDBID.Create(UIInventoryItemsManager.ResolveItemIconName(ItemID.GetTDBID(row.item), TweakDBInterface.GetItemRecord(ItemID.GetTDBID(row.item)), player));
     row.quality = GameInstance.GetStatsSystem(player.GetGame()).GetStatValue(data.GetStatsObjectID(), gamedataStatType.Quality);
     ArrayPush(result, row);
    }
   }
  }
  return result;
 }
 public static func Value(player: ref<PlayerPuppet>, item: ItemID, stat: gamedataStatType) -> Float {
  let data = GameInstance.GetTransactionSystem(player.GetGame()).GetItemData(player, item);
  if !IsDefined(data) { return 0.0; }
  return GameInstance.GetStatsSystem(player.GetGame()).GetStatValue(data.GetStatsObjectID(), stat);
 }
 public static func Preview(player: ref<PlayerPuppet>, item: ItemID, record: TweakDBID, seed: Uint32) -> ref<gameItemData> {
  let params: ItemModParams;
  params.itemID = ItemID.FromTDBID(ItemID.GetTDBID(item));
  params.quantity = 1;
  ArrayPush(params.customPartsToInstall, ItemID.CreateFromSeedWithOffset(record, seed, 0));
  return Inventory.CreateItemData(params, player);
 }
 public static func Apply(player: ref<PlayerPuppet>, item: ItemID, record: TweakDBID, seed: Uint32, material: TweakDBID, count: Int32, money: Int32, expected: array<ref<Bonus>>) -> Bool {
  let ts = GameInstance.GetTransactionSystem(player.GetGame());
  if count <= 0 || money <= 0 || ts.GetItemQuantity(player, ItemID.FromTDBID(t"Items.money")) < money || !EquipmentSystem.GetData(player).IsEquipped(item) || ts.GetItemQuantity(player, ItemID.FromTDBID(material)) < count { return false; }
  let data = ts.GetItemData(player, item);
  if !IsDefined(data) || !data.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") { return false; }
  let part = ItemID.CreateFromSeedWithOffset(record, seed, 0);
  if !IsDefined(TweakDBInterface.GetItemRecord(record)) { return false; }
  if !ts.GiveItem(player, part, 1) { return false; }
  // Reserve both costs before replacing the shard. Every failure refunds the reservation.
  if !ts.RemoveItemByTDBID(player, t"Items.money", money) {
   ts.RemoveItem(player, part, 1);
   return false;
  }
  if !ts.RemoveItemByTDBID(player, material, count) {
   ts.GiveItemByTDBID(player, t"Items.money", money);
   ts.RemoveItem(player, part, 1);
   return false;
  }
  if !EquipmentSystem.GetData(player).CRFReplacePart(player, item, part, expected) {
   ts.GiveItemByTDBID(player, t"Items.money", money);
   ts.GiveItemByTDBID(player, material, count);
   ts.RemoveItem(player, part, 1);
   return false;
  }
  return true;
 }
}

public class ReflashButton extends SimpleButton {
 private let m_icon: ref<inkImage>;
 public func SetVisible(visible: Bool) { this.m_root.SetVisible(visible); }
 public func Layout(width: Float, height: Float, fontSize: Int32) {
  this.m_root.SetSize(width, height);
  this.m_label.SetFontSize(fontSize);
  this.m_label.SetLetterCase(textLetterCase.OriginalCase);
  this.m_label.SetMargin(new inkMargin(16.0, 6.0, 16.0, 6.0));
  this.m_label.SetWrappingAtPosition(width - 32.0);
 }
 public func Icon(id: TweakDBID) {
  if !IsDefined(this.m_icon) {
   this.m_icon = new inkImage();
   this.m_icon.SetSize(100.0, 100.0);
   this.m_icon.SetMargin(new inkMargin(16.0, 20.0, 0.0, 0.0));
   this.m_icon.Reparent(this.m_root);
  }
  let record = TweakDBInterface.GetUIIconRecord(id);
  this.m_icon.SetVisible(IsDefined(record));
  if IsDefined(record) {
   this.m_icon.SetAtlasResource(record.AtlasResourcePath());
   this.m_icon.SetTexturePart(record.AtlasPartName());
   this.m_label.SetMargin(new inkMargin(132.0, 6.0, 16.0, 6.0));
   this.m_label.SetWrappingAtPosition(this.m_root.GetWidth() - 148.0);
  } else {
   this.m_label.SetMargin(new inkMargin(16.0, 6.0, 16.0, 6.0));
  }
 }
 public static func Make() -> ref<ReflashButton> {
  let button = new ReflashButton();
  button.CreateInstance();
  return button;
 }
}

public class ReflashPriceCard extends inkCustomController {
 private let m_root: ref<inkCanvas>;
 private let m_icon: ref<inkImage>;
 private let m_text: ref<inkText>;
 protected cb func OnCreate() {
  this.m_root = new inkCanvas();
  this.m_root.SetSize(635.0, 90.0);
  this.SetRootWidget(this.m_root);
  let background = new inkRectangle();
  background.SetSize(635.0, 90.0);
  background.SetTintColor(new HDRColor(0.08, 0.035, 0.06, 0.92));
  background.Reparent(this.m_root);
  this.m_icon = new inkImage();
  this.m_icon.SetSize(72.0, 72.0);
  this.m_icon.SetMargin(new inkMargin(10.0, 9.0, 0.0, 0.0));
  this.m_icon.Reparent(this.m_root);
  this.m_text = new inkText();
  this.m_text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  this.m_text.SetFontStyle(n"Medium");
  this.m_text.SetFontSize(27);
  this.m_text.SetSize(535.0, 84.0);
  this.m_text.SetWrappingAtPosition(535.0);
  this.m_text.SetMargin(new inkMargin(94.0, 6.0, 0.0, 0.0));
  this.m_text.Reparent(this.m_root);
 }
 public func Update(icon: TweakDBID, title: String, required: Int32, available: Int32, ready: Bool, english: Bool) {
  let record = TweakDBInterface.GetUIIconRecord(icon);
  this.m_icon.SetVisible(IsDefined(record));
  if IsDefined(record) {
   this.m_icon.SetAtlasResource(record.AtlasResourcePath());
   this.m_icon.SetTexturePart(record.AtlasPartName());
  }
  let color = ready && available < required ? new HDRColor(1.0, 0.26, 0.25, 1.0) : new HDRColor(0.30, 0.93, 0.97, 1.0);
  this.m_text.SetTintColor(color);
  this.m_icon.SetTintColor(color);
  let amount = ready ? IntToString(required) : "—";
  let balance = english ? "Available: " : "В наличии: ";
  this.m_text.SetText(title + ": " + amount + "\n" + balance + IntToString(available));
 }
 public static func Make() -> ref<ReflashPriceCard> {
  let self = new ReflashPriceCard();
  self.CreateInstance();
  return self;
 }
}

public class ReflashPopup extends InGamePopup {
 public let state: ref<Model>;
 public let service: wref<Service>;
 private let m_step: Int32;
 private let m_itemPage: Int32;
 private let m_statPage: Int32;
 private let m_category: Int32;
 private let m_categories: array<String>;
 private let m_indices: array<Int32>;
 private let m_pages: array<ref<inkVerticalPanel>>;
 private let m_items: array<ref<ReflashButton>>;
 private let m_bonuses: array<ref<ReflashButton>>;
 private let m_stats: array<ref<ReflashButton>>;
 private let m_steps: ref<inkText>;
 private let m_summary: ref<inkText>;
 private let m_itemCounter: ref<inkText>;
 private let m_statCounter: ref<inkText>;
 private let m_target: ref<inkText>;
 private let m_current: ref<inkText>;
 private let m_normal: ref<inkText>;
 private let m_overclock: ref<inkText>;
 private let m_message: ref<inkText>;
 private let m_money: ref<ReflashPriceCard>;
 private let m_components: ref<ReflashPriceCard>;
 private let m_input: ref<HubTextInput>;
 private let m_search: ref<HubTextInput>;
 private let m_apply: ref<ReflashButton>;
 private let m_back: ref<ReflashButton>;
 private let m_ignoreInput: Bool;

 protected cb func OnCreate() {
  super.OnCreate();
  this.m_container.SetSize(1650.0, 1060.0);
  this.m_container.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
  let header = InGamePopupHeader.Create();
  header.SetTitle(this.Text("ПЕРЕПРОШИВКА ИМПЛАНТОВ", "CYBERWARE REFLASH"));
  header.SetFluffRight(this.Text("НАСТРОЙКА БОНУСОВ", "BONUS CUSTOMIZATION"));
  header.Reparent(this);
  let root = this.Column(this.m_container);
  root.SetMargin(new inkMargin(80.0, 110.0, 0.0, 0.0));
  this.m_steps = this.Label(root, "", 26, 36.0);
  this.m_summary = this.Label(root, this.Text("Выбери установленный имплант", "Choose equipped cyberware"), 34, 50.0);
  let body = new inkCanvas();
  body.SetSize(1450.0, 650.0);
  body.Reparent(root);
  let i = 0;
  while i < 4 {
   let page = this.Column(body);
   page.SetAffectsLayoutWhenHidden(false);
   ArrayPush(this.m_pages, page);
   i += 1;
  }
  this.CreateImplants(this.m_pages[0]);
  this.CreateBonuses(this.m_pages[1]);
  this.CreateValue(this.m_pages[2]);
  this.CreateCatalog(this.m_pages[3]);
  let footer = this.Row(root);
  this.m_back = this.Button(footer, n"back", this.Text("< Назад", "< Back"), 300.0, 68.0, 28);
  this.Button(footer, n"close", this.Text("Закрыть", "Close"), 300.0, 68.0, 28);
  this.Refresh();
 }
 private func CreateImplants(parent: ref<inkCompoundWidget>) {
  this.Label(parent, this.Text("Нажми на карточку импланта", "Select a cyberware card"), 28, 42.0);
  let i = 0;
  while i < 2 {
   let row = this.Row(parent);
   let j = 0;
   while j < 2 {
    ArrayPush(this.m_items, this.Button(row, StringToName(s"item\(i * 2 + j)"), "", 705.0, 140.0, 32));
    j += 1;
   }
   i += 1;
  }
  let nav = this.Row(parent);
  this.Button(nav, n"itemPrev", "<", 100.0, 54.0, 30);
  this.m_itemCounter = this.Label(nav, "", 28, 54.0);
  this.m_itemCounter.SetWidth(320.0);
  this.Button(nav, n"itemNext", ">", 100.0, 54.0, 30);
  this.Label(parent, this.Text("Показываются установленные импланты с дополнительными бонусами.", "Equipped cyberware with secondary bonuses is shown here."), 26, 70.0);
 }
 private func CreateBonuses(parent: ref<inkCompoundWidget>) {
  this.Label(parent, this.Text("Какой бонус улучшить?", "Which bonus would you like to improve?"), 34, 58.0);
  let i = 0;
  while i < 3 {
   ArrayPush(this.m_bonuses, this.Button(parent, StringToName(s"bonus\(i)"), "", 1430.0, 100.0, 32));
   i += 1;
  }
  this.Label(parent, this.Text("По умолчанию усиливается выбранная характеристика.\nЗаменить её на другую можно на следующем шаге.", "The selected stat is improved by default.\nYou can replace it with another stat on the next step."), 28, 90.0);
 }
 private func CreateValue(parent: ref<inkCompoundWidget>) {
  parent.SetChildMargin(new inkMargin(0.0, 0.0, 0.0, 6.0));
  this.m_target = this.Label(parent, "", 30, 46.0);
  let modes = this.Row(parent);
  this.Button(modes, n"keep", this.Text("Усилить текущий бонус", "Improve current bonus"), 560.0, 48.0, 26);
  this.Button(modes, n"replace", this.Text("Выбрать другую характеристику", "Choose another stat"), 730.0, 48.0, 26);
  this.m_current = this.Label(parent, "", 27, 34.0);
  this.m_normal = this.Label(parent, "", 27, 34.0);
  this.m_overclock = this.Label(parent, "", 27, 34.0);
  this.m_overclock.SetTintColor(new HDRColor(1.0, 0.67, 0.18, 1.0));
  this.Label(parent, this.Text("Новое значение", "New value"), 26, 24.0);
  let values = this.Row(parent);
  this.Button(values, n"minus", "−", 100.0, 80.0, 34);
  this.m_input = HubTextInput.Create();
  this.m_input.SetWidth(350.0);
  this.m_input.SetMaxLength(12);
  this.m_input.Reparent(values);
  this.m_input.RegisterToCallback(n"OnInput", this, n"OnValueInput");
  this.Button(values, n"plus", "+", 100.0, 80.0, 34);
  let presets = this.Row(parent);
  this.Button(presets, n"normal", this.Text("Обычный максимум", "Normal maximum"), 620.0, 48.0, 26);
  this.Button(presets, n"overclock", this.Text("Разгон до +20%", "Overclock up to +20%"), 620.0, 48.0, 26);
  let prices = this.Row(parent);
  this.m_money = ReflashPriceCard.Make();
  this.m_money.Reparent(prices);
  this.m_components = ReflashPriceCard.Make();
  this.m_components.Reparent(prices);
  this.m_message = this.Label(parent, "", 25, 48.0);
  this.m_apply = this.Button(parent, n"apply", this.Text("Подтвердить перепрошивку", "Confirm reflash"), 1280.0, 58.0, 28);
 }
 private func CreateCatalog(parent: ref<inkCompoundWidget>) {
  this.Label(parent, this.Text("Найти характеристику", "Find a stat"), 28, 36.0);
  this.m_search = HubTextInput.Create();
  this.m_search.SetWidth(1420.0);
  this.m_search.Reparent(parent);
  this.m_search.RegisterToCallback(n"OnInput", this, n"OnSearchInput");
  let categories = this.Row(parent);
  this.Button(categories, n"cat0", this.Text("Все", "All"), 245.0, 52.0, 26);
  this.Button(categories, n"cat1", this.Text("Урон", "Damage"), 245.0, 52.0, 26);
  this.Button(categories, n"cat2", this.Text("Защита", "Defense"), 245.0, 52.0, 26);
  this.Button(categories, n"cat3", this.Text("Восстановление", "Recovery"), 315.0, 52.0, 26);
  this.Button(categories, n"cat4", this.Text("Удобство", "Utility"), 245.0, 52.0, 26);
  ArrayPush(this.m_categories, "all");
  ArrayPush(this.m_categories, "damage");
  ArrayPush(this.m_categories, "defense");
  ArrayPush(this.m_categories, "recovery");
  ArrayPush(this.m_categories, "utility");
  let i = 0;
  while i < 3 {
   let row = this.Row(parent);
   let j = 0;
   while j < 2 {
    ArrayPush(this.m_stats, this.Button(row, StringToName(s"stat\(i * 2 + j)"), "", 705.0, 88.0, 29));
    j += 1;
   }
   i += 1;
  }
  let nav = this.Row(parent);
  this.Button(nav, n"statPrev", "<", 100.0, 52.0, 30);
  this.m_statCounter = this.Label(nav, "", 28, 52.0);
  this.m_statCounter.SetWidth(500.0);
  this.Button(nav, n"statNext", ">", 100.0, 52.0, 30);
 }
 private func Text(ru: String, en: String) -> String { return this.state.english ? en : ru; }
 private func Column(parent: ref<inkCompoundWidget>) -> ref<inkVerticalPanel> {
  let panel = new inkVerticalPanel();
  panel.SetFitToContent(true);
  panel.SetChildMargin(new inkMargin(0.0, 0.0, 0.0, 8.0));
  panel.Reparent(parent);
  return panel;
 }
 private func Row(parent: ref<inkCompoundWidget>) -> ref<inkHorizontalPanel> {
  let row = new inkHorizontalPanel();
  row.SetFitToContent(true);
  row.SetChildMargin(new inkMargin(0.0, 0.0, 14.0, 0.0));
  row.Reparent(parent);
  return row;
 }
 private func Label(parent: ref<inkCompoundWidget>, text: String, size: Int32, height: Float) -> ref<inkText> {
  let label = new inkText();
  label.SetText(text);
  label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  label.SetFontStyle(n"Medium");
  label.SetFontSize(size);
  label.SetSize(1430.0, height);
  label.SetWrappingAtPosition(1430.0);
  label.SetTintColor(new HDRColor(0.30, 0.93, 0.97, 1.0));
  label.Reparent(parent);
  return label;
 }
 private func Button(parent: ref<inkCompoundWidget>, name: CName, text: String, width: Float, height: Float, size: Int32) -> ref<ReflashButton> {
  let button = ReflashButton.Make();
  button.SetName(name);
  button.SetText(text);
  button.Layout(width, height, size);
  button.ToggleSounds(true);
  button.Reparent(parent);
  button.RegisterToCallback(n"OnBtnClick", this, n"OnClick");
  return button;
 }
 private func OldBonus() -> ref<Bonus> {
  if this.state.implantIndex >= ArraySize(this.state.implants) { return null; }
  let bonuses = this.state.implants[this.state.implantIndex].bonuses;
  if this.state.bonusIndex >= ArraySize(bonuses) { return null; }
  return bonuses[this.state.bonusIndex];
 }
 private func KeepCurrent() {
  let old = this.OldBonus();
  if !IsDefined(old) { return; }
  let i = 0;
  while i < ArraySize(this.state.catalog) {
   if Equals(this.state.catalog[i].stat, old.stat) {
    this.state.statIndex = i;
    break;
   }
   i += 1;
  }
  this.state.text = FloatToStringPrec(old.value, 2);
  this.state.normalMaximum = 0.0;
  this.state.overclockMaximum = 0.0;
  this.state.canApply = false;
  this.state.request = 4;
  this.m_step = 2;
 }
 private func BuildIndices() {
  ArrayClear(this.m_indices);
  let search = StrLower(this.m_search.GetText());
  let i = 0;
  while i < ArraySize(this.state.catalog) {
   let entry = this.state.catalog[i];
   let categoryMatches = this.m_category == 0 || Equals(entry.category, this.m_categories[this.m_category]);
   if categoryMatches && (StrLen(search) == 0 || StrContains(StrLower(entry.label), search)) { ArrayPush(this.m_indices, i); }
   i += 1;
  }
 }
 private func Duplicate(index: Int32) -> Bool {
  if this.state.implantIndex >= ArraySize(this.state.implants) { return false; }
  let bonuses = this.state.implants[this.state.implantIndex].bonuses;
  let i = 0;
  while i < ArraySize(bonuses) {
   if i != this.state.bonusIndex && Equals(bonuses[i].stat, this.state.catalog[index].stat) { return true; }
   i += 1;
  }
  return false;
 }
 public func Refresh() {
  if !IsDefined(this.m_input) { return; }
  let i = 0;
  while i < ArraySize(this.m_pages) { this.m_pages[i].SetVisible(i == this.m_step); i += 1; }
  this.m_back.SetDisabled(this.m_step == 0);
  switch this.m_step {
   case 0: this.m_steps.SetText(this.Text("1. ИМПЛАНТ   >   2. БОНУС   >   3. ЗНАЧЕНИЕ И ЦЕНА", "1. CYBERWARE   >   2. BONUS   >   3. VALUE AND COST")); break;
   case 1: this.m_steps.SetText(this.Text("1. ИМПЛАНТ   >   [2. БОНУС]   >   3. ЗНАЧЕНИЕ И ЦЕНА", "1. CYBERWARE   >   [2. BONUS]   >   3. VALUE AND COST")); break;
   default: this.m_steps.SetText(this.Text("1. ИМПЛАНТ   >   2. БОНУС   >   [3. ЗНАЧЕНИЕ И ЦЕНА]", "1. CYBERWARE   >   2. BONUS   >   [3. VALUE AND COST]"));
  }
  if this.state.implantIndex < ArraySize(this.state.implants) {
   this.m_summary.SetText(this.state.implants[this.state.implantIndex].label);
  }
  i = 0;
  while i < ArraySize(this.m_items) {
   let index = this.m_itemPage * 4 + i;
   let valid = index < ArraySize(this.state.implants);
   this.m_items[i].SetVisible(valid);
   this.m_items[i].SetDisabled(!valid);
   if valid {
    let row = this.state.implants[index];
    this.m_items[i].SetText(row.label);
    this.m_items[i].Icon(row.icon);
   }
   i += 1;
  }
  this.m_itemCounter.SetText(s"\(this.m_itemPage + 1) / \(Max(1, (ArraySize(this.state.implants) + 3) / 4))");
  let bonuses: array<ref<Bonus>>;
  if this.state.implantIndex < ArraySize(this.state.implants) { bonuses = this.state.implants[this.state.implantIndex].bonuses; }
  i = 0;
  while i < ArraySize(this.m_bonuses) {
   let valid = i < ArraySize(bonuses);
   this.m_bonuses[i].SetVisible(valid);
   this.m_bonuses[i].SetDisabled(!valid);
   if valid { this.m_bonuses[i].SetText(bonuses[i].label + s"  +\(FloatToStringPrec(bonuses[i].value, 2))"); }
   i += 1;
  }
  this.BuildIndices();
  i = 0;
  while i < ArraySize(this.m_stats) {
   let place = this.m_statPage * 6 + i;
   let valid = place < ArraySize(this.m_indices);
   this.m_stats[i].SetVisible(valid);
   this.m_stats[i].SetDisabled(!valid);
   if valid {
    let index = this.m_indices[place];
    let entry = this.state.catalog[index];
    let duplicate = this.Duplicate(index);
    this.m_stats[i].SetDisabled(duplicate);
    let detail = entry.maximum > 0.0 ? this.Text(s"\nОбычный максимум: \(FloatToStringPrec(entry.maximum, 2))", s"\nNormal maximum: \(FloatToStringPrec(entry.maximum, 2))") : this.Text("\nПредел ещё не рассчитан", "\nLimit not calculated yet");
    this.m_stats[i].SetText(entry.label + (duplicate ? this.Text("\nУже установлен", "\nAlready installed") : detail));
   }
   i += 1;
  }
  this.m_statCounter.SetText(this.Text(s"\(this.m_statPage + 1) / \(Max(1, (ArraySize(this.m_indices) + 5) / 6))    Найдено: \(ArraySize(this.m_indices))", s"\(this.m_statPage + 1) / \(Max(1, (ArraySize(this.m_indices) + 5) / 6))    Found: \(ArraySize(this.m_indices))"));
  let old = this.OldBonus();
  if IsDefined(old) && this.state.statIndex < ArraySize(this.state.catalog) {
   let entry = this.state.catalog[this.state.statIndex];
   let same = Equals(old.stat, entry.stat);
   this.m_target.SetText((same ? this.Text("Усиление: ", "Improve: ") : this.Text("Замена на: ", "Replace with: ")) + entry.label);
   this.m_current.SetText(this.Text("Сейчас: ", "Current: ") + old.label + s"  +\(FloatToStringPrec(old.value, 2))");
   if this.state.normalMaximum > 0.0 {
    this.m_normal.SetText(this.Text(s"Обычный максимум: \(FloatToStringPrec(this.state.normalMaximum, 2)) \(this.state.unit)", s"Normal maximum: \(FloatToStringPrec(this.state.normalMaximum, 2)) \(this.state.unit)"));
    this.m_overclock.SetText(this.Text(s"Предел разгона: \(FloatToStringPrec(this.state.overclockMaximum, 2)) \(this.state.unit) — повышенная цена", s"Overclock limit: \(FloatToStringPrec(this.state.overclockMaximum, 2)) \(this.state.unit) — premium cost"));
   } else {
    this.m_normal.SetText(this.Text("Рассчитываю предел качества...", "Calculating tier limit..."));
    this.m_overclock.SetText("");
   }
  }
  this.m_ignoreInput = true;
  if NotEquals(this.m_input.GetText(), this.state.text) { this.m_input.SetText(this.state.text); }
  this.m_ignoreInput = false;
  this.m_message.SetText(this.state.message);
  let ready = this.state.quoteReady && this.state.request == 0;
  this.m_money.Update(t"UIIcon.LootingShadow_Cash", this.Text("Эдди (€$)", "Eddies (€$)"), this.state.moneyCost, this.state.moneyHave, ready, this.state.english);
  let title = this.Text("Компоненты T", "Components T") + IntToString(this.state.componentTier);
  this.m_components.Update(this.state.componentIcon, title, this.state.componentCost, this.state.componentHave, ready, this.state.english);
  this.m_apply.SetDisabled(!this.state.canApply || this.state.request != 0);
 }
 protected cb func OnSearchInput(widget: wref<inkWidget>) -> Bool {
  this.m_statPage = 0;
  this.Refresh();
 }
 protected cb func OnValueInput(widget: wref<inkWidget>) -> Bool {
  if this.m_ignoreInput { return false; }
  this.state.text = this.m_input.GetText();
  this.state.canApply = false;
  if this.m_step == 2 && this.state.normalMaximum > 0.0 { this.state.request = 2; }
  this.m_apply.SetDisabled(true);
 }
 private func SetValue(value: Float) {
  let clamped = ClampF(value, 0.01, this.state.overclockMaximum);
  this.state.text = FloatToStringPrec(clamped, 2);
  this.state.canApply = false;
  this.state.request = 2;
 }
 protected cb func OnClick(widget: wref<inkWidget>) -> Bool {
  let name = widget.GetName();
  if Equals(name, n"close") { this.Close(); return true; }
  if this.state.request == 3 { return true; }
  if Equals(name, n"back") { this.m_step = this.m_step == 3 ? 2 : Max(0, this.m_step - 1); }
  if Equals(name, n"itemPrev") { this.m_itemPage = Max(0, this.m_itemPage - 1); }
  if Equals(name, n"itemNext") && (this.m_itemPage + 1) * 4 < ArraySize(this.state.implants) { this.m_itemPage += 1; }
  if Equals(name, n"statPrev") { this.m_statPage = Max(0, this.m_statPage - 1); }
  if Equals(name, n"statNext") && (this.m_statPage + 1) * 6 < ArraySize(this.m_indices) { this.m_statPage += 1; }
  if Equals(name, n"keep") { this.KeepCurrent(); }
  if Equals(name, n"replace") { this.m_step = 3; this.m_statPage = 0; }
  let i = 0;
  while i < 6 {
   if i < 4 && Equals(name, StringToName(s"item\(i)")) {
    this.state.implantIndex = this.m_itemPage * 4 + i;
    this.state.bonusIndex = 0;
    this.state.canApply = false;
    this.m_step = 1;
   }
   if i < 3 && Equals(name, StringToName(s"bonus\(i)")) { this.state.bonusIndex = i; this.KeepCurrent(); }
   if i < 5 && Equals(name, StringToName(s"cat\(i)")) { this.m_category = i; this.m_statPage = 0; }
   if Equals(name, StringToName(s"stat\(i)")) {
    let place = this.m_statPage * 6 + i;
    if place < ArraySize(this.m_indices) {
     this.state.statIndex = this.m_indices[place];
     this.state.text = "";
     this.state.normalMaximum = 0.0;
     this.state.overclockMaximum = 0.0;
     this.state.canApply = false;
     this.state.request = 4;
     this.m_step = 2;
    }
   }
   i += 1;
  }
  if this.state.overclockMaximum > 0.0 {
   let step = this.state.normalMaximum < 1.0 ? 0.01 : 0.1;
   if Equals(name, n"minus") { this.SetValue(StringToFloat(StrReplace(this.state.text, ",", ".")) - step); }
   if Equals(name, n"plus") { this.SetValue(StringToFloat(StrReplace(this.state.text, ",", ".")) + step); }
   if Equals(name, n"normal") { this.SetValue(this.state.normalMaximum); }
   if Equals(name, n"overclock") { this.SetValue(this.state.overclockMaximum); }
  }
  if Equals(name, n"apply") && this.state.canApply && this.state.request == 0 {
   this.state.text = this.m_input.GetText();
   this.state.request = 3;
  }
  this.Refresh();
  return true;
 }
 protected cb func OnDetach() {
  super.OnDetach();
  this.service.opened = false;
  this.service.popup = null;
 }
 public func UseCursor() -> Bool { return true; }
}


@addMethod(EquipmentSystemPlayerData)
public final func CRFReplacePart(owner: ref<PlayerPuppet>, item: ItemID, part: ItemID, expected: array<ref<Bonus>>) -> Bool {
 let slot = this.GetSlotIndex(item);
 let ts = GameInstance.GetTransactionSystem(owner.GetGame());
 let data = ts.GetItemData(owner, item);
 let previous: InnerItemData;
 if slot < 0 || !IsDefined(data) || data.HasTag(n"UnequipBlocked") { return false; }
 data.GetItemPart(previous, t"AttachmentSlots.StatsShardSlot");
 let previousID = InnerItemData.GetItemID(previous);
 if !ItemID.IsValid(previousID) { return false; }
 this.UnequipItem(item);
 if this.IsEquipped(item) { return false; }
 let changed = ts.ForcePartInSlot(owner, item, part, t"AttachmentSlots.StatsShardSlot");
 this.EquipItem(item, slot, false);
 if changed {
  let stats = GameInstance.GetStatsSystem(owner.GetGame());
  for bonus in expected {
   if AbsF(stats.GetStatValue(data.GetStatsObjectID(), bonus.kind) - bonus.value) > 0.0001 { changed = false; }
  }
 }
 if !changed || !this.IsEquipped(item) {
  if this.IsEquipped(item) { this.UnequipItem(item); }
  ts.ForcePartInSlot(owner, item, previousID, t"AttachmentSlots.StatsShardSlot");
  this.EquipItem(item, slot, false);
  return false;
 }
 ts.RemoveItem(owner, previousID, 1);
 let event = new UIEquipmentReplacedEvent();
 event.itemID = item;
 GameInstance.GetUISystem(owner.GetGame()).QueueEvent(event);
 return true;
}
