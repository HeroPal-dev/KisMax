-- Locale.lua: English text is the key; Russian is used on a ruRU client (or with /km lang ru).
-- On a non-Russian client Naowh's font may have no Cyrillic letters, so "auto" follows the client.
local _, NPP = ...

local RU = {
    ["  /km debug - debug output on/off"] = "  /km debug - отладочный вывод вкл/выкл",
    ["  /km minprofit <gold>|off, /km minroi <percent>|off, /km hideunknown"] =
        "  /km minprofit <золото>|off, /km minroi <процент>|off, /km hideunknown",
    ["  /km profit - profit breakdown of the selected recipe"] = "  /km profit - разбор прибыли выбранного рецепта",
    ["  /km sort none|profit|roi, /km order (high/low first), /km flat"] =
        "  /km sort none|profit|roi, /km order (по убыванию/возрастанию), /km flat",
    ["  /km source tsm|naowh|tsmmarket|tsmmin, /km tsmprice <TSM price>"] =
        "  /km source tsm|naowh|tsmmarket|tsmmin, /km tsmprice <цена TSM>",
    ["  /km column, /km lang auto|ru|en, /km reset"] = "  /km column, /km lang auto|ru|en, /km reset",
    ["  TSM price chain: %s -> Linen Cloth %s"] = "  Цепочка цен TSM: %s -> Linen Cloth %s",
    ["TSM price chain: %s. Example: /km tsmprice first(DBMarket, DBHistorical)"] =
        "Цепочка цен TSM: %s. Пример: /km tsmprice first(DBMarket, DBHistorical)",
    ["TSM price chain: %s."] = "Цепочка цен TSM: %s.",
    ["TSM (price chain)"] = "TSM (цепочка цен)",
    ["  /km status - what was found, prices, settings"] = "  /km status - что найдено, цены, настройки",
    ["  Item: %s each (%s), yield %s, after 5%% cut: %s"] = "  Предмет: %s за шт. (%s), выход %s, после 5%% комиссии: %s",
    ["  Naowh profession window: %s"] = "  Окно профессий Naowh: %s",
    ["  Naowh scan: %s ago, %d items priced."] = "  Скан Naowh: %s назад, цен: %d.",
    ["  Naowh scan: NaowhForever_QoL is not loaded (no ns.AuctionPrice)."] =
        "  Скан Naowh: NaowhForever_QoL не загружен (нет ns.AuctionPrice).",
    ["  Naowh scan: no scan for this realm and faction yet (Scan Prices at the AH)."] =
        "  Скан Naowh: для этого мира и фракции скана ещё нет (кнопка Scan Prices на аукционе).",
    ["  Profit: %s, ROI: %s"] = "  Прибыль: %s, ROI: %s",
    ["  Reagents: %s%s"] = "  Реагенты: %s%s",
    ["  Source in use: %s%s."] = "  Используется: %s%s.",
    ["  TSM: loaded. Test (Linen Cloth): DBMarket %s, DBMinBuyout %s."] =
        "  TSM: загружен. Проверка (Linen Cloth): DBMarket %s, DBMinBuyout %s.",
    ["  TSM: not loaded (TSM_API missing)."] = "  TSM: не загружен (нет TSM_API).",
    [" (TSM missing, Naowh scan used)"] = " (TSM нет, берётся скан Naowh)",
    ["'%s' is off: Naowh has changed (missing: %s). Send me /km status."] =
        "'%s' выключено: Naowh изменился (нет: %s). Пришли вывод /km status.",
    ["/km - commands"] = "/km - команды",
    ["Above zero (any profit)"] = "Больше нуля (любая прибыль)",
    ["Debug output %s."] = "Отладочный вывод: %s.",
    ["Error in '%s' (details in BugSack). The Naowh window keeps working."] =
        "Ошибка в '%s' (подробности в BugSack). Окно Naowh продолжает работать.",
    ["Example: /km minprofit 2.5 (gold) or /km minprofit off"] = "Пример: /km minprofit 2.5 (золото) или /km minprofit off",
    ["Example: /km minroi 30 or /km minroi off"] = "Пример: /km minroi 30 или /km minroi off",
    ["Filters: min profit %s, min ROI %s, hide unknown %s"] = "Фильтры: мин. прибыль %s, мин. ROI %s, скрывать без цены %s",
    ["Hide recipes without a price %s."] = "Скрывать рецепты без цены: %s.",
    ["Hide recipes without a price"] = "Скрывать рецепты без цены",
    ["Highest first"] = "Сначала большие",
    ["Language: %s."] = "Язык: %s.",
    ["Last sort: %d recipes, %d without value."] = "Последняя сортировка: рецептов %d, без значения %d.",
    ["Min ROI: "] = "Мин. ROI: ",
    ["Min ROI: %s."] = "Мин. ROI: %s.",
    ["Min profit: "] = "Мин. прибыль: ",
    ["Min profit: %s."] = "Мин. прибыль: %s.",
    ["KisMax"] = "KisMax",
    ["Naowh order"] = "Как у Naowh",
    ["Naowh parts:"] = "Части Naowh:",
    ["Naowh scan: %s ago."] = "Скан Naowh: %s назад.",
    ["NaowhForever_Professions was not found: the addon does nothing."] =
        "NaowhForever_Professions не найден: аддон ничего не делает.",
    ["No Naowh scan yet."] = "Скана Naowh ещё нет.",
    ["No price data yet: press Scan Prices at the auction house."] = "Цен пока нет: нажми Scan Prices на аукционе.",
    ["Off"] = "Выкл.",
    ["One list without categories %s."] = "Один список без категорий: %s.",
    ["One list without categories"] = "Один список без категорий",
    ["Open a profession and select a recipe first."] = "Сначала открой профессию и выбери рецепт.",
    ["Order: %s."] = "Порядок: %s.",
    ["Price source: "] = "Источник цен: ",
    ["Price source: %s."] = "Источник цен: %s.",
    ["Prices:"] = "Цены:",
    ["Profit calculation is off (see /km status)."] = "Расчёт прибыли выключен (см. /km status).",
    ["Profit filters are paused: no price data (scan the auction house first)."] =
        "Фильтры по прибыли не применяются: нет цен (сначала просканируй аукцион).",
    ["Profit filters"] = "Фильтры по прибыли",
    ["Profit"] = "Прибыль",
    ["ROI"] = "ROI",
    ["Reagents"] = "Реагенты",
    ["Reset profit filters"] = "Сбросить фильтры по прибыли",
    ["Sale after 5% cut"] = "Продажа минус 5%",
    ["Sale price from: "] = "Цена продажи из: ",
    ["Settings reset."] = "Настройки сброшены.",
    ["Settings: sort %s, %s, flat %s, unlearned %s, column %s"] =
        "Настройки: сортировка %s, %s, без категорий %s, неизученные %s, колонка %s",
    ["Shift: reagent breakdown"] = "Shift: разбивка по реагентам",
    ["Show value in the list"] = "Показывать значение в списке",
    ["Sort unlearned recipes too"] = "Сортировать и неизученные",
    ["Sort"] = "Сорт.",
    ["Sort: %s."] = "Сортировка: %s.",
    ["Sorting and profit filters for this list."] = "Сортировка и фильтры по прибыли для этого списка.",
    ["TradeSkillMaster is not loaded."] = "TradeSkillMaster не загружен.",
    ["TradeSkillMaster is not loaded: the Naowh scan is used."] = "TradeSkillMaster не загружен: берётся скан Naowh.",
    ["Value in the list %s."] = "Значение в списке: %s.",
    ["free"] = "даром",
    ["high first"] = "по убыванию",
    ["low first"] = "по возрастанию",
    ["no data"] = "нет данных",
    ["no price"] = "нет цены",
    ["off"] = "выкл.",
    ["own (free)"] = "свой (бесплатно)",
    ["own"] = "свой",
    ["v%s, NaowhForever_Professions v%s, debug %s"] = "v%s, NaowhForever_Professions v%s, отладка %s",
    ["v%s. Commands:"] = "v%s. Команды:",
    -- v0.2: quantities, Master Chef, sell channel, plans
    ["  %d crafts, ~%s items. Cost %s, sale %s, profit %s. Stops at: %s."] =
        "  %d крафтов, ~%s шт. Затраты %s, продажа %s, прибыль %s. Упор: %s.",
    ["  (on the AH)"] = "  (на аукционе)",
    ["  (to a merchant)"] = "  (торговцу)",
    ["  /km channel best|ah|vendor - where the result is sold"] = "  /km channel best|ah|vendor - куда продавать результат",
    ["  /km chef auto|0-5, /km overprod (count Master Chef extras), /km perks [text], /km chefnode <id>|auto"] =
        "  /km chef auto|0-5, /km overprod (учитывать перепроизводство Master Chef), /km perks [текст], /km chefnode <id>|auto",
    ["  /km depth <percent>, /km demand on|off|<days>, /km planmax <crafts>"] =
        "  /km depth <процент>, /km demand on|off|<дней>, /km planmax <крафтов>",
    ["  /km plan [add] - buy plan of the selected recipe (add: to Naowh's shopping list)"] =
        "  /km plan [add] - план закупки выбранного рецепта (add: в список покупок Naowh)",
    ["  /km sort none|profit|roi|total|hour, /km order (high/low first), /km flat"] =
        "  /km sort none|profit|roi|total|hour, /km order (по убыванию/возрастанию), /km flat",
    ["  /km source auto|depth|tsm|tsmmarket|tsmmin|naowh, /km tsmprice <TSM price>"] =
        "  /km source auto|depth|tsm|tsmmarket|tsmmin|naowh, /km tsmprice <цена TSM>",
    ["  AH: %s each (%s), after 5%% cut: %s"] = "  Аукцион: %s за шт. (%s), после 5%% комиссии: %s",
    ["  Merchant: %s each, total %s"] = "  Торговец: %s за шт., всего %s",
    ["  Our scan (quantities): %s ago, %d items."] = "  Наш скан (с количеством): %s назад, предметов %d.",
    ["  Our scan (quantities): none yet. Press Scan Prices at the AH; it is read at the same time."] =
        "  Наш скан (с количеством): пока нет. Нажми Scan Prices на аукционе, он читается одновременно.",
    ["  Sold to: %s"] = "  Продажа: %s",
    ["  Some reagents have no quantities: their price counts as unlimited."] =
        "  У части реагентов нет количества: их цена считается неограниченной.",
    ["  Source: %s -> order: %s."] = "  Источник: %s -> порядок: %s.",
    ["  TSM region sells ~%s per day."] = "  TSM: в регионе продаётся ~%s в день.",
    ["  The next craft would make %s."] = "  Следующий крафт дал бы %s.",
    ["  Yield: %s (base %s, Master Chef +%s, %d ranks)"] = "  Выход: %s (база %s, Master Chef +%s, рангов %d)",
    ["AH %d up to %s"] = "аук. %d до %s",
    ["Add the plan of the selected recipe to Naowh's shopping list"] = "Добавить план выбранного рецепта в список покупок Naowh",
    ["Auction house"] = "Аукцион",
    ["Auction listings saved with quantities: %d items."] = "Лоты аукциона сохранены с количеством: предметов %d.",
    ["Auction: no more than TSM sells per day"] = "Аукцион: не больше, чем продаётся в день (TSM)",
    ["Auto"] = "Авто",
    ["Auto (from the Legacy tree)"] = "Авто (из Legacy-дерева)",
    ["C_Traits is not available here: use /km chef 0-5."] = "C_Traits недоступен: задай вручную /km chef 0-5.",
    ["Count overproduction (extra results)"] = "Учитывать перепроизводство (доп. результат)",
    ["CHEF_HELP"] = "Каждый ранг: +10% шанс, что кулинарный крафт даст на 1 штуку больше (рецепт на 2 даст 3). "
        .. "Вкл.: выход и прибыль считаются по среднему с учётом этой лишней штуки. Выкл.: только базовый результат.",
    ["DEMAND_HELP"] = "Продажи в день по региону из TSM (все миры Forever региона), умноженные на дни из /km demand. "
        .. "Продажа торговцу не ограничена.",
    ["DEPTH_HELP"] = "Цена нашего скана: та, ниже которой лежит эта доля всех выставленных штук. "
        .. "Несколько дешёвых штук больше не задают цену.",
    ["Demand limit %s, %s days."] = "Ограничение спросом: %s, дней: %s.",
    ["Master Chef %d: +%s items per craft on average"] = "Master Chef %d: в среднем +%s шт. за крафт",
    ["Master Chef (cooking)"] = "Master Chef (кулинария)",
    ["Master Chef extra results counted %s."] = "Перепроизводство Master Chef учитывается: %s.",
    ["Master Chef pinned: tree %d node %d, ranks %s."] = "Master Chef закреплён: дерево %d, узел %d, рангов %s.",
    ["Master Chef: %d ranks (%s)%s, overproduction counted %s, sell to %s"] =
        "Master Chef: рангов %d (%s)%s, перепроизводство %s, продажа: %s",
    ["Master Chef: %d ranks (%s)."] = "Master Chef: рангов %d (%s).",
    ["Master Chef: searched for by name again."] = "Master Chef: снова ищется по названию.",
    ["Merchant"] = "Торговец",
    ["Merchants do not buy the crafted item."] = "Торговцы не покупают результат крафта.",
    ["Naowh did not add it (no materials needed?)."] = "Naowh не добавил (рецепту не нужны материалы?).",
    ["Naowh scan (min buyout)"] = "Скан Naowh (мин. выкуп)",
    ["Naowh's shopping list is not available."] = "Список покупок Naowh недоступен.",
    ["No price for the crafted item."] = "Нет цены на результат крафта.",
    ["No scan of ours yet."] = "Нашего скана ещё нет.",
    ["Node %d was not found in your Legacy trees (see /km perks)."] = "Узел %d не найден в твоих Legacy-деревьях (см. /km perks).",
    ["Nodes listed: %d. Pin Master Chef with /km chefnode <node>."] =
        "Показано узлов: %d. Закрепи Master Chef командой /km chefnode <узел>.",
    ["Only learned recipes can go on the shopping list."] = "В список покупок можно добавить только изученный рецепт.",
    ["Our scan (by quantity)"] = "Наш скан (по количеству)",
    ["Our scan: %s ago."] = "Наш скан: %s назад.",
    ["Plan"] = "План",
    ["Plan for %s (sell to %s, yield %s per craft):"] = "План для %s (продажа: %s, выход %s за крафт):",
    ["Plan looks at up to %d crafts."] = "План смотрит до %d крафтов.",
    ["Plan: %d crafts, ~%s items"] = "План: %d крафтов, ~%s шт.",
    ["Plan: up to %d crafts, demand limit %s (%s days), depth %s%%"] =
        "План: до %d крафтов, ограничение спросом %s (дней: %s), глубина %s%%",
    ["Price per craft:"] = "Цена за один крафт:",
    ["Profit of the whole plan"] = "Прибыль всего плана",
    ["Profit per craft"] = "Прибыль за крафт",
    ["Quantities from our scan, %s ago."] = "Количество из нашего скана, %s назад.",
    ["Quantity depth"] = "Глубина по количеству",
    ["Quantity depth: %d%%"] = "Глубина по количеству: %d%%",
    ["Quantity depth: %s%%."] = "Глубина по количеству: %s%%.",
    ["Ranks: "] = "Ранги: ",
    ["Reading listings stopped: the auction house closed."] = "Чтение лотов прервано: аукцион закрыт.",
    ["Sale on the AH, after 5% cut"] = "Продажа на аукционе минус 5%",
    ["Sale to a merchant"] = "Продажа торговцу",
    ["Select a learned recipe first."] = "Сначала выбери изученный рецепт.",
    ["Sell to: "] = "Продавать: ",
    ["Sell to: %s."] = "Продавать: %s.",
    ["Shift: reagents and what to buy"] = "Shift: реагенты и что купить",
    ["Some reagents have no quantities: their price counts as unlimited."] =
        "У части реагентов нет количества: их цена считается неограниченной.",
    ["Sorting, profit filters and buy plans for this list."] = "Сортировка, фильтры по прибыли и планы закупки для этого списка.",
    ["Stops at: %s"] = "Упор: %s",
    ["TSM region sells ~%s per day"] = "TSM: в регионе продаётся ~%s в день",
    ["The plan for this recipe has no profitable crafts."] = "В плане этого рецепта нет выгодных крафтов.",
    ["Where it pays more"] = "Где выгоднее",
    ["auto: %d"] = "авто: %d",
    ["auto: not found"] = "авто: не найден",
    ["bags"] = "сумки",
    ["buy from a merchant %d for %s"] = "купить у торговца %d за %s",
    ["buy on the AH %d for %s (up to %s each)"] = "купить на аукционе %d за %s (до %s за шт.)",
    ["demand (TSM sold per day)"] = "спрос (продажи в день TSM)",
    ["next craft would not pay"] = "следующий крафт невыгоден",
    ["no prices"] = "нет цен",
    ["no profitable craft (%s)"] = "нет выгодного крафта (%s)",
    ["plan limit (/km planmax)"] = "лимит плана (/km planmax)",
    ["reagents on sale run out"] = "закончились реагенты в продаже",
    -- v0.3: live lots and the buy plan panel
    ["  /km lots - at the AH: refresh lots of the selected recipe; /km panel - plan panel on/off"] =
        "  /km lots - на аукционе: обновить лоты выбранного рецепта; /km panel - панель плана вкл/выкл",
    [" (Master Chef %d)"] = " (Master Chef %d)",
    [" (next craft: %s)"] = " (следующий крафт: %s)",
    [" - cost %s, sale %s"] = " - затраты %s, продажа %s",
    [" - open the AH and press Refresh lots"] = " - открой аукцион и нажми «Обновить лоты»",
    ["%d on the AH"] = "на аукционе %d",
    [", TSM ~%s sold per day"] = ", TSM: ~%s продаж в день",
    ["At the auction house: searches this recipe's reagents and result and reads every lot with its quantity."] =
        "На аукционе: ищет реагенты и результат этого рецепта и читает все лоты с количеством.",
    ["Buy plan panel %s."] = "Панель плана закупки: %s.",
    ["Buy plan panel under the window"] = "Панель плана закупки под окном",
    ["Buy plan: "] = "План закупки: ",
    ["Live lots are off (see /km status)."] = "Живые лоты выключены (см. /km status).",
    ["Lots are being refreshed already."] = "Лоты уже обновляются.",
    ["Lots refreshed: %d of %d items answered."] = "Лоты обновлены: ответ по %d из %d предметов.",
    ["Lots: "] = "Лоты: ",
    ["No craft pays at today's prices."] = "При текущих ценах ни один крафт не выгоден.",
    ["Open the auction house first: lots can be read only there."] = "Сначала открой аукцион: лоты читаются только там.",
    ["Pays: %d crafts (~%s items), profit %s"] = "Выгодно: %d крафтов (~%s шт.), прибыль %s",
    ["Refresh lots"] = "Обновить лоты",
    ["Refreshing lots of %d items..."] = "Обновляю лоты по %d предметам...",
    ["Refreshing lots stopped: the auction house closed."] = "Обновление лотов прервано: аукцион закрыт.",
    ["Sale %s: %s each, x%s per craft"] = "Продажа %s: %s за шт., x%s за крафт",
    ["To shopping list"] = "В список покупок",
    ["bags %d"] = "в сумках %d",
    ["buy on the AH %d up to %s each (%s)"] = "купить на аукционе %d шт. до %s за шт. (%s)",
    ["full scan %s ago"] = "полный скан %s назад",
    ["merchant %d (%s)"] = "у торговца %d (%s)",
    ["on the AH (after 5% cut)"] = "на аукционе (минус 5%)",
    ["only part of the lots is loaded (refresh lots again)"] = "загружена только часть лотов (обнови лоты ещё раз)",
    ["search %s ago"] = "поиск %s назад",
    ["some without quantities"] = "у части нет количества",
    ["to a merchant"] = "торговцу",
    -- price sources
    ["Naowh scan"] = "Скан Naowh",
    ["merchant"] = "торговец",
    -- reasons
    ["No reagent list for this recipe."] = "Нет списка реагентов для рецепта.",
    ["The recipe makes no item (enchant?): nothing to sell."] = "Рецепт не создаёт предмет (чары?): продавать нечего.",
    ["No auction price for the crafted item."] = "Нет цены аукциона на результат крафта.",
    ["No price for %d reagent(s)."] = "Нет цены у реагентов: %d.",
    ["No recipe."] = "Нет рецепта.",
    -- v0.4: money budget
    ["  /km budget auto|off|<gold> - money a plan may spend"] =
        "  /km budget auto|off|<золото> - сколько денег план может потратить",
    ["  Money: pay %s of %s."] = "  Деньги: к оплате %s из %s.",
    ["  With more money: %d crafts, profit %s, pay %s."] = "  Будь денег больше: %d крафтов, прибыль %s, к оплате %s.",
    ["BUDGET_HELP"] = "План не тратит больше этой суммы на покупки на аукционе и у торговца "
        .. "(реагенты в сумках денег не стоят). «Золото на персонаже» следит за твоими деньгами.",
    ["Money for purchases: "] = "Деньги на закупку: ",
    ["Money for purchases: %s (%s)"] = "Деньги на закупку: %s (%s)",
    ["Money: pay %s, "] = "Деньги: к оплате %s, ",
    ["With more money: %d crafts, profit %s, pay %s"] = "Будь денег больше: %d крафтов, прибыль %s, к оплате %s",
    ["budget %s"] = "бюджет %s",
    ["gold on the character"] = "золото на персонаже",
    ["no limit"] = "без ограничения",
    ["not enough money"] = "не хватает денег",
    ["you have %s"] = "у тебя %s",
    -- v0.4: craft time
    ["%d s"] = "%d с",
    ["%d min"] = "%d мин",
    ["%d h %d min"] = "%d ч %d мин",
    ["Time: %s%s (%s s per craft), ~%s per hour"] = "Время: %s%s (%s с на крафт), ~%s в час",
    [" (cast time unknown, 3 s assumed)"] = " (время каста неизвестно, взято 3 с)",
    ["  Time: %s (%s s per craft%s), ~%s per hour."] = "  Время: %s (%s с на крафт%s), ~%s в час.",
    [", guessed"] = ", наугад",
    ["Per hour"] = "В час",
    -- v0.4: sell list
    ["  /km sell - at a merchant: sell the sell list; /km sell list|clear|add <item>|remove <item>"] =
        "  /km sell - у торговца: продать список продажи; /km sell list|clear|add <предмет>|remove <предмет>",
    ["Nothing from the sell list is in your bags."] = "В сумках нет ничего из списка продажи.",
    ["Only items on the sell list are sold. Add or remove one with the button on the Buy plan panel or /km sell list."] =
        "Продаётся только то, что в списке продажи. Добавить или убрать предмет: кнопкой на панели плана закупки, список: /km sell list.",
    ["Sell crafts"] = "Продать крафт",
    ["Sell crafts: %d (%s)"] = "Продать крафт: %d шт. (%s)",
    ["Sell crafts: none"] = "Продать крафт: нечего",
    ["Sell list"] = "Список продажи",
    ["Sell list cleared."] = "Список продажи очищен.",
    ["Sell list: added %s."] = "Список продажи: добавлено «%s».",
    ["Sell list: removed %s."] = "Список продажи: убрано «%s».",
    ["Sell to merchants: no"] = "Сдавать торговцу: нет",
    ["Sell to merchants: yes"] = "Сдавать торговцу: да",
    ["SELL_HELP"] = "Да: результат этого рецепта попадает в список продажи. У торговца под его окном появится "
        .. "кнопка «Продать крафт», которая одним нажатием продаст все такие предметы из сумок. Остальное не трогается.",
    ["Selling is off (see /km status)."] = "Продажа выключена (см. /km status).",
    ["Selling stopped: the merchant window closed or combat started."] = "Продажа прервана: окно торговца закрыто или начался бой.",
    ["Selling..."] = "Продаю...",
    ["Sold %d items (%d stacks) for %s."] = "Продано %d шт. (%d стаков) за %s.",
    ["Talk to a merchant first (and not in combat)."] = "Сначала открой торговца (и не в бою).",
    ["The merchant can buy back only the last %d stacks."] = "Выкупить обратно у торговца можно только последние %d стаков.",
    ["The sell list is empty: add items on the Buy plan panel."] = "Список продажи пуст: добавь предметы на панели плана закупки.",
    ["This recipe makes no item to sell."] = "Этот рецепт не создаёт предмет для продажи.",
    ["Total"] = "Итого",
    -- v0.4: profession overview
    ["Profession overview"] = "Обзор профессий",
    -- v0.5: our shopping list
    ["KM shopping list"] = "Список покупок KM",
    -- v0.7: session plan
    ["Session plan"] = "План сессии",
    -- v0.9: KisMax window
    ["Profit, plans and trading for your professions"] = "Прибыль, планы и торговля для твоих профессий",
    ["Tools"] = "Инструменты",
    ["Settings"] = "Настройки",
    ["Every profession's recipes by profit per hour."] = "Рецепты всех профессий по прибыли в час.",
    ["The cheapest way to your target skill."] = "Самый дешёвый путь до нужного навыка.",
    ["Several profitable recipes with your money and bags."] = "Несколько выгодных рецептов на твои деньги и сумки.",
    ["What to buy, with the plans' price limits."] = "Что купить, с лимитами цен из планов.",
    ["What you spent and earned crafting."] = "Сколько потрачено и заработано на крафте.",
    ["Prices and selling"] = "Цены и продажа",
    ["Buy plans"] = "Планы закупки",
    ["Interface"] = "Интерфейс",
    ["Price source"] = "Источник цен",
    ["Money for purchases"] = "Деньги на закупку",
    ["Ranks"] = "Ранги",
    ["Lines on the recipe tooltip"] = "Строки в подсказке рецепта",
    ["Minimap button"] = "Кнопка у миникарты",
    ["Language"] = "Язык",
    ["Game language"] = "Как в игре",
    ["Russian"] = "Русский",
    ["English"] = "Английский",
    ["On"] = "Вкл",
    ["Left click: next value, right click: previous."] = "ЛКМ: следующее значение, ПКМ: предыдущее.",
    ["Reset settings"] = "Сбросить настройки",
    ["/km - commands. Sorting and profit filters stay on the Sort button of the profession window."] =
        "/km - команды. Сортировка и фильтры по прибыли остались на кнопке сортировки в окне профессии.",
    ["Left click: the KisMax window"] = "ЛКМ: окно KisMax",
    ["Right click: tools"] = "ПКМ: инструменты",
    ["Drag: move the button"] = "Перетащить: сдвинуть кнопку",
    ["tools and settings..."] = "инструменты и настройки...",
    -- v0.8: levelling plan
    ["Levelling plan"] = "План прокачки",
    ["Sales"] = "Продажи",
    ["7 days: spent %s, sales %s, result %s, crafts %d"] = "7 дней: потрачено %s, продажи %s, итог %s, крафтов %d",
    ["30 days: spent %s, sales %s, result %s, crafts %d"] = "30 дней: потрачено %s, продажи %s, итог %s, крафтов %d",
    ["per hour of crafting: %s (%s of crafting)"] = "в час крафта: %s (крафт занял %s)",
    ["Auction sales come from Naowh's The Market ledger (its mail records)."] =
        "Продажи на аукционе берутся из Ledger Naowh (The Market, по почте).",
    ["Auction sales (mail)"] = "Продажи на аукционе (почта)",
    ["  Auction sales (mail): %s"] = "  Продажи на аукционе (почта): %s",
    ["cheap now"] = "сейчас дёшево",
    ["usually %s, %d%% less"] = "обычно %s, на %d%% дешевле",
    ["lots %s ago"] = "лоты %s назад",
    ["%s: %d of %d at or under the limit (%s)"] = "%s: %d из %d по цене до лимита (%s)",
    ["Shopping list: can be bought now for about %s:"] = "Список покупок: сейчас можно купить примерно на %s:",
    ["Shopping list: everything is dearer than its limit right now."] = "Список покупок: сейчас всё дороже лимитов.",
    ["\"Cheap now\" on reagent tooltips"] = "«Сейчас дёшево» в подсказке реагентов",
    ["Cheap means under the usual price by"] = "«Дёшево» — это дешевле обычного на",
    ["At the AH: check the shopping list by itself"] = "У аукциона: проверять список покупок самому",
    ["cost per item"] = "себестоимость за шт.",
    ["on the AH not below"] = "на аукционе не дешевле",
    ["(a merchant / disenchanting pays more below it)"] = "(дешевле выгоднее сдать торговцу / распылить)",
    ["(after the 5% cut)"] = "(с учётом 5% комиссии)",
    ["Cost and lowest AH price on crafted items' tooltips"] = "Себестоимость и мин. цена аукциона в подсказке крафта",
    -- self-test
    ["  /km selftest - check everything KisMax relies on (send me a screenshot of it)"] =
        "  /km selftest - проверить всё, на что опирается KisMax (пришли скриншот)",
    ["KisMax %s self-test:"] = "Самопроверка KisMax %s:",
    ["Naowh Forever %s, Professions %s"] = "Naowh Forever %s, Professions %s",
    ["Naowh parts we use: %d of %d%s"] = "Части Naowh, которые мы используем: %d из %d%s",
    ["missing"] = "нет",
    ["Feature %s"] = "Функция %s",
    ["Modules started: %d of %d%s"] = "Модулей запущено: %d из %d%s",
    ["TradeSkillMaster prices available"] = "Цены TradeSkillMaster доступны",
    ["TradeSkillMaster not loaded: no TSM prices or sales per day"] = "TradeSkillMaster не загружен: нет цен TSM и продаж в день",
    ["Price of Linen Cloth: %s (%s)"] = "Цена льняной ткани: %s (%s)",
    ["Our full scan: %s ago, %d items"] = "Наш полный скан: %s назад, предметов %d",
    ["No full scan of ours yet"] = "Нашего полного скана ещё нет",
    ["Naowh's scan: %s ago"] = "Скан Naowh: %s назад",
    ["No Naowh scan yet"] = "Скана Naowh ещё нет",
    ["Professions: %s"] = "Профессии: %s",
    ["Recipes Naowh remembers for this character: %d%s"] = "Рецептов, которые Naowh помнит для персонажа: %d%s",
    ["open each profession once"] = "открой каждую профессию разок",
    ["Enchanting %d, Master Chef ranks %s"] = "Наложение чар %d, ранги Master Chef %s",
    ["Records: %d days of history, %d items on the shopping list, %d on the sell list"] =
        "Записи: дней истории %d, в списке покупок %d, в списке продажи %d",
    ["Errors since loading: %d%s"] = "Ошибок с загрузки: %d%s",
    ["details in BugSack"] = "подробности в BugSack",
    ["Self-test: %d OK, %d to look at, %d failed."] = "Самопроверка: в порядке %d, посмотреть %d, сломано %d.",
    ["(grey from the game)"] = "(серый из игры)",
    ["Routes tried: %d (the cheapest is shown)."] = "Маршрутов проверено: %d (показан самый дешёвый).",
    ["Sell: "] = "Продажа: ",
    ["AH, after the 5% cut"] = "аукцион, после 5% комиссии",
    ["to a merchant"] = "торговцу",
    ["+ %d without a price"] = "+ %d без цены",
    ["Our numbers in Buy for / Sell for / Profit by the Create button"] = "Наши цифры в «Купить для / Продать за / Прибыль»",
    ["often"] = "часто",
    ["sometimes"] = "иногда",
    ["rarely"] = "редко",
    [" each"] = "/шт",
    ["needs Enchanting %d (you: %d)"] = "нужно наложение чар %d (у тебя: %d)",
    ["%s d"] = "%s дн.",
    ["AH demand: "] = "Спрос на аук.: ",
    ["%s+/day"] = "от %s/день",
    ["any"] = "любой",
    ["AH demand"] = "Спрос на аукционе",
    ["EXPLORE_CHANNEL_HELP"] = "Куда этот обзор продаёт результат: где выгоднее, только аукцион или сразу "
        .. "(торговец или распыление, что дороже). Не зависит от фильтров окна профессии.",
    ["DEMAND_FILTER_HELP"] = "Прячет рецепты, которые продаются на аукционе реже, чем столько штук в день по TSM "
        .. "(это весь регион, на твоём сервере меньше). Рецепты, которые идут торговцу или в распыление, "
        .. "не прячутся: торговец берёт всё. Дорогим вещам хватает и 0.5 в день, дешёвым партиям нужно больше.",
    ["At that rate: 5 sell in ~%s, 20 in ~%s (whole region; yours will be slower)."] =
        "С такой скоростью: 5 шт. уйдут за ~%s, 20 шт. — за ~%s (весь регион; у тебя медленнее).",
    ["Merchant / disenchant"] = "Торговец / распыление",
    ["skill %d"] = "навык %d",
    ["level %d"] = "уровень %d",
    ["needs"] = "нужен",
    ["Click: type the target skill"] = "Клик: ввести цель вручную",
    ["Naowh's scan gave up early; its prices were taken from ours (%d items)."] =
        "Скан Naowh сдался раньше времени; его цены взяты из нашего скана (предметов: %d).",
    ["Give our full scan to Naowh when its scan gives up"] = "Отдавать наш скан в цены Naowh, если его скан сорвался",
    ["FEED_HELP"] = "Полный скан Naowh ждёт ответа аукциона 60 секунд, а медленный сервер шлёт лоты дольше. "
        .. "KisMax дочитывает их и, если Naowh не сохранил этот скан, записывает в его цены минимальную цену "
        .. "за штуку по каждому предмету. Файлы Naowh не меняются, только его сохранённые цены.",
    ["Choose a profession above."] = "Выбери профессию сверху.",
    ["Other: %s"] = "Другая: %s",
    ["Other profession..."] = "Другая профессия...",
    ["Rank up to %d"] = "Ранг до %d",
    ["Rank"] = "Ранг",
    ["quest"] = "задание",
    ["Learned recipes as Naowh remembers them (open the profession once to update)."] =
        "Выученные рецепты — как их помнит Naowh (открой профессию разок, чтобы обновить).",
    ["You do not have this profession: every recipe counts as not learned."] =
        "Этой профессии у тебя нет: все рецепты считаются невыученными.",
    ["Open this profession's window first: the crafting queue crafts there."] =
        "Сначала открой окно этой профессии: очередь крафтит там.",
    ["Costs about %s"] = "Обойдётся примерно в %s",
    ["Pays you about %s"] = "Принесёт примерно %s",
    ["skill %d -> %d, %d crafts, %s"] = "навык %d -> %d, крафтов %d, %s",
    ["To buy %s, recipes %s, back %s (merchant %s, disenchant %s, AH %s)."] =
        "Купить на %s, рецепты %s, вернётся %s (торговец %s, распыление %s, аукцион %s).",
    ["From your bags: reagents worth %s (counted in the steps, not in the cost above)."] =
        "Из сумок: реагентов на %s (учтены в шагах, но не в сумме выше).",
    ["Expected values: a craft gives a point with its colour's chance. Reagents from your bags first, then the cheapest lots. Recipes with a cooldown (transmutes) are left out."] =
        "Ожидаемые значения: крафт даёт очко с шансом своего цвета. Реагенты сначала из сумок, потом самые дешёвые лоты. Рецепты с перезарядкой (трансмутации) не берутся.",
    ["Where to learn:"] = "Где изучить:",
    ["gear"] = "вещь",
    ["From: %d"] = "От: %d",
    ["Click: type the skill to start from"] = "Клик: ввести навык, с которого начать",
    ["Right-click: the character's real skill"] = "Правый клик: настоящий навык персонажа",
    ["Your other characters"] = "Другие персонажи",
    ["(log in with each character once to see it here)"] = "(зайди каждым персонажем один раз, чтобы он тут появился)",
    ["Professions you do not have"] = "Профессии, которых у тебя нет",
    ["This is %s's plan: queue the crafts on that character (buy here and send by mail)."] =
        "Это план для %s: очередь крафта ставь на том персонаже (здесь купи и отправь почтой).",
    ["%s's profession as saved when that character last logged in; learned recipes as Naowh remembers them. Buy here, send by mail."] =
        "Профессия %s — как запомнилась при последнем входе этим персонажем; изученные рецепты — как их помнит Naowh. Купи здесь, отправь почтой.",
    ["Start typed by hand: %d (the real skill is %d)."] = "Начало введено вручную: %d (настоящий навык %d).",
    ["Enchants are cast by hand on your own gear (the item slot under the recipe, then Create): %s."] =
        "Чары накладывай сам на свою вещь (слот вещи под рецептом, затем «Создать»): %s.",
    ["Enchants go on your own gear: you pay only the reagents, nothing comes back."] =
        "Чары накладываются на свои вещи: платишь только за реагенты, назад ничего не возвращается.",
    ["weapon"] = "оружие",
    ["two-handed weapon"] = "двуручное оружие",
    ["shield"] = "щит",
    ["no %s"] = "нет: %s",
    ["Enchant your own gear: %s. The point comes from the cast, nothing comes back."] =
        "Накладывается на свою вещь: %s. Очко даёт само наложение, назад ничего не возвращается.",
    ["You have no such item: buy any cheap one from a merchant (any quality will do)."] =
        "У тебя нет такой вещи: купи любую дешёвую у торговца (качество не важно).",
    ["auction house"] = "аукцион",
    ["Click: put a waypoint there"] = "Клик: поставить путевую точку",
    ["* To learn (click: waypoint):"] = "* Изучить (клик — путевая точка):",
    ["Recipes from the AH"] = "Рецепты с аукциона",
    ["by demand"] = "по спросу",
    ["nowhere"] = "никуда",
    ["Levelling plan..."] = "План прокачки...",
    ["  /km level [target] - levelling plan: the cheapest way to the target skill"] =
        "  /km level [цель] - план прокачки: самый дешёвый путь до нужного навыка",
    ["The levelling plan is off (see /km status)."] = "План прокачки выключен (см. /km status).",
    ["Open your own profession first: the plan uses its recipes and your skill."] =
        "Сначала открой свою профессию: план берёт её рецепты и твой навык.",
    ["Open your own profession and press Recount."] = "Открой свою профессию и нажми «Пересчитать».",
    ["Already at the target skill (%d)."] = "Навык уже на цели (%d).",
    ["Skill %d -> %d: about %d crafts, %s."] = "Навык %d -> %d: примерно %d крафтов, %s.",
    ["Reagents %s, recipes %s, back %s (merchant %s, disenchant %s, AH %s). Result: %s."] =
        "Реагенты %s, рецепты %s, возврат %s (торговец %s, распыление %s, аукцион %s). Итог: %s.",
    ["* to learn: %s"] = "* изучить: %s",
    ["No recipe gives points from %d with known prices: open the AH or check the overview."] =
        "С навыка %d нет рецепта, дающего очки, с известными ценами: открой аукцион или посмотри обзор.",
    ["(%d more steps not shown)"] = "(ещё шагов не показано: %d)",
    ["Expected values: a craft gives a point with its colour's chance. One price per reagent."] =
        "Ожидаемые значения: крафт даёт очко с шансом своего цвета. Одна цена на реагент.",
    ["Colours: yellow %d, green %d, grey %d"] = "Цвета: жёлтый с %d, зелёный с %d, серый с %d",
    ["Reagents per craft"] = "Реагенты за крафт",
    ["Merchant pays per craft"] = "Торговец за крафт",
    ["Disenchanted per craft"] = "Распыление за крафт",
    ["AH per craft (after cut)"] = "Аукцион за крафт (минус 5%)",
    ["Results go: %s"] = "Результат: %s",
    ["Not learned: %s, %s"] = "Не изучен: %s, %s",
    ["Learn first: %s (%s, %s)."] = "Сначала изучи: %s (%s, %s).",
    ["Not queued yet (not learned or not all in your bags): %s."] =
        "Пока не в очереди (не изучено или не всё в сумках): %s.",
    ["Target: %d"] = "Цель: %d",
    ["AH: by demand"] = "Аукцион: по спросу",
    ["AH: off"] = "Аукцион: нет",
    ["Cost"] = "Затраты",
    ["Back"] = "Возврат",
    ["disenchant"] = "распыление",
    ["Count disenchanting (if your Enchanting can)"] = "Учитывать распыление (если хватает наложения чар)",
    ["Disenchant value on item tooltips"] = "Стоимость распыления в подсказке предмета",
    ["trainer"] = "тренер",
    -- v0.8: disenchant
    ["Disenchant"] = "Распыление",
    ["KM disenchant"] = "KM распыление",
    ["  needs Enchanting %d (you: %d)"] = "  нужно наложение чар %d (у тебя: %d)",
    ["Disenchanted (materials on the AH)"] = "Распылить (материалы на аукцион)",
    ["disenchanted"] = "распылить",
    ["  /km channel best|ah|vendor|de - where the result is sold (de: disenchant it)"] =
        "  /km channel best|ah|vendor|de - куда девать результат (de: распылить)",
    ["Shrink text that does not fit the buttons"] = "Уменьшать текст, который не влезает в кнопки",
    ["FIT_HELP"] = "Кнопки и вкладки Naowh рассчитаны на английский. Если надпись не влезает, её шрифт уменьшается "
        .. "(не меньше 70%), пока она не поместится. Файлы Naowh не меняются. Полностью вступает в силу после /reload.",
    ["List plans follow bags only at the AH"] = "Планы в списке — по сумкам только у аукциона",
    ["ATAH_HELP"] = "Вкл.: сортировка «В час»/«План» и колонка пересчитываются по сумкам и деньгам, только когда "
        .. "открыт аукцион или торговец; в остальное время берутся последние значения (меньше нагрузки). "
        .. "Панель выбранного рецепта считается всегда. Новые цены и настройки пересчитывают всё сразу.",
    ["Crafting queue now: %s. In the queue window: Start Queue, then Craft Next for each batch."] =
        "В очереди создания теперь: %s. В окне очереди: «Запустить очередь», потом «Создать следующее» для каждой партии.",
    ["Not all is in your bags yet (%s): buy the rest from the shopping list, then press To craft queue again."] =
        "В сумках есть ещё не всё (%s): докупи по списку покупок и нажми «В очередь крафта» ещё раз.",
    ["Session plan..."] = "План сессии...",
    ["SESSION_HELP"] = "Считает, что крафтить на твои деньги и место в сумках сразу по нескольким выгодным рецептам "
        .. "(например, 100 одной еды и 100 другой), с общими лотами реагентов. Потом: в список покупок и в очередь крафта.",
    ["  /km session - session plan: several profitable recipes with your money and bag space"] =
        "  /km session - план сессии: несколько выгодных рецептов на твои деньги и место в сумках",
    ["The session plan is off (see /km status)."] = "План сессии выключен (см. /km status).",
    ["Open a profession first: the session uses its learned recipes."] =
        "Сначала открой профессию: план сессии берёт её выученные рецепты.",
    ["This is someone else's profession: open your own."] = "Это чужая профессия: открой свою.",
    ["Naowh's crafting queue is not available."] = "Очередь создания Naowh недоступна.",
    ["The session has no crafts."] = "В плане сессии нет крафтов.",
    ["Crafting queue: added %s. In the queue window: Start Queue, then Craft Next for each batch."] =
        "Очередь создания: добавлено %s. В окне очереди: «Начать», потом «Создать следующее» для каждой партии.",
    ["session"] = "план сессии",
    ["Profit"] = "Прибыль",
    ["Time"] = "Время",
    ["Sale"] = "Продажа",
    ["Pay"] = "К оплате",
    ["Last craft makes"] = "Последний крафт даёт",
    ["To craft queue"] = "В очередь крафта",
    ["What the whole session buys, with the price limits, goes to the KM shopping list. Buy it first."] =
        "Всё, что покупает сессия, с лимитами цен — в список покупок KM. Сначала купи это.",
    ["QUEUE_HELP"] = "Добавляет крафты сессии в очередь создания Naowh: там одна кнопка крафтит партию за клик, "
        .. "а промежуточные крафты (например, обработку шкур) Naowh добавит сам. В очередь идёт только то, "
        .. "на что уже хватает материалов в сумках; повторное нажатие выставляет число заново, а не добавляет.",
    ["Press Recount."] = "Нажми «Пересчитать».",
    ["Counting... %d crafts so far."] = "Считаю... крафтов пока: %d.",
    ["Nothing pays with your money and bag space at today's prices."] =
        "При текущих ценах на твои деньги и место в сумках ничего не выгодно.",
    [" (recipes counted: %d)"] = " (рецептов посчитано: %d)",
    ["Total: %d crafts, profit %s, pay %s, time %s, %s per hour."] =
        "Итого: %d крафтов, прибыль %s, к оплате %s, время %s, %s в час.",
    ["money %s of %s"] = "деньги %s из %s",
    ["bags %d of %d slots"] = "сумки %d из %d ячеек",
    ["Recipes counted: %d (the most profitable per hour). Hover a row for why it stops."] =
        "Рецептов посчитано: %d (самые выгодные в час). Наведи на строку — там, почему рецепт остановился.",
    ["need / at or under the limit now"] = "нужно / сейчас до лимита",
    ["Not sold: %d stacks (the merchant did not take them)."] = "Не продано: %d стаков (торговец их не взял).",
    ["%dx %s (merchant)"] = "%dx %s (у торговца)",
    ["Auction: %d, limit %s each"] = "Аукцион: %d, лимит %s за шт.",
    ["Given to Naowh: %d"] = "Передано в Naowh: %d",
    ["Fresh lots of every auction item on the list: how many are listed at or under the plan's limit."] =
        "Свежие лоты по всем предметам списка: сколько штук лежит не дороже лимита плана.",
    ["HAND_HELP"] = "Передаёт в список покупок Naowh ровно столько штук, сколько сейчас лежит не дороже лимита. "
        .. "Аукцион продаёт с самых дешёвых, поэтому Naowh купит именно их. Дальше в окне Naowh: «Проверить цены» и «Купить».",
    ["All, no limit"] = "Всё, без лимита",
    [" (Naowh %d)"] = " (в Naowh %d)",
    [" - not a trade good"] = " - не товар",
    [" - all %d"] = " - все %d",
    [" - only %d"] = " - только %d",
    [" - none (from %s)"] = " - нет (от %s)",
    ["Searching lots..."] = "Ищу лоты...",
    ["Press Search: how many units are listed at or under each limit right now."] =
        "Нажми «Искать»: сколько штук сейчас лежит не дороже каждого лимита.",
    ["At or under the limits now: %d items, about %s. Give them to Naowh and buy them there."] =
        "Сейчас до лимитов: %d предм., примерно %s. Передай в Naowh и купи там.",
    ["Nothing at or under the limits right now: search again later."] = "Сейчас ничего нет до лимитов: поищи позже.",
    ["To Naowh: %d items"] = "В Naowh: %d предм.",
    ["Given to Naowh's shopping list: %s (about %s). In Naowh's list: Check prices, then Buy."] =
        "Передано в список покупок Naowh: %s (примерно %s). В окне Naowh: «Проверить цены», потом «Купить».",
    ["The lots changed before the price came: searched again, press Buy again."] =
        "Лоты изменились, пока шёл запрос цены: поискал заново, нажми «Купить» ещё раз.",
    ["The auction house did not answer the price request in %d s."] = "Аукцион не ответил на запрос цены за %d с.",
    ["Turn on /km debug, try again and send me the KM debug lines."] =
        "Включи /km debug, попробуй ещё раз и пришли строки «KM debug» из чата.",
    ["The auction house says these units are not for sale any more."] = "Аукцион говорит, что этих штук больше нет в продаже.",
    ["The auction house is busy (request limit): press again in a second."] =
        "Аукцион занят (лимит запросов): нажми ещё раз через секунду.",
    ["Passed to Naowh's shopping list: %s. Naowh does not know the price limits."] =
        "Передано в список покупок Naowh: %s. Лимиты цен Naowh не знает.",
    ["To Naowh"] = "В Naowh",
    ["Adds this list to Naowh's shopping list, to buy with Naowh's buttons. Naowh does not check the price limits."] =
        "Добавляет этот список в список покупок Naowh, чтобы купить его кнопками. Лимиты цен Naowh не проверяет.",
    ["KM shopping list..."] = "Список покупок KM...",
    ["  /km shop [clear|naowh|km] - our shopping list (naowh/km: where To shopping list goes)"] =
        "  /km shop [clear|naowh|km] - наш список покупок (naowh/km: куда кладёт «В список покупок»)",
    ["The shopping list is off (see /km status)."] = "Список покупок выключен (см. /km status).",
    ["Shopping list cleared."] = "Список покупок очищен.",
    ["To shopping list now goes to: %s."] = "«В список покупок» теперь кладёт в: %s.",
    ["merchant %d"] = "у торговца %d",
    ["%d up to %s"] = "%d до %s",
    ["Searching lots of %s..."] = "Ищу лоты: %s...",
    ["%s: %d units at or under %s, about %s."] = "%s: %d шт. по цене до %s, примерно %s.",
    ["Buy %d"] = "Купить %d",
    ["Asking the price..."] = "Узнаю цену...",
    ["Price: %s for %d %s (plan expected %s)."] = "Цена: %s за %d %s (план ждал %s).",
    ["Confirm %s"] = "Подтвердить %s",
    ["Buying..."] = "Покупаю...",
    ["Dearer than the plan: %s instead of about %s (lots were bought up). Not bought."] =
        "Дороже плана: %s вместо ~%s (лоты успели выкупить). Не куплено.",
    ["Search again"] = "Искать снова",
    ["%s: no lots at or under %s (cheapest %s)."] = "%s: нет лотов по цене до %s (самый дешёвый %s).",
    ["Next item"] = "Следующий",
    ["%s is not a trade good: buy it by hand."] = "%s — не товар (не стакается): купи вручную.",
    ["The auction house gave no price."] = "Аукцион не назвал цену.",
    ["The purchase failed."] = "Покупка не прошла.",
    ["No answer about the purchase: check your bags."] = "Нет ответа о покупке: проверь сумки.",
    ["Not enough money for this purchase."] = "Не хватает денег на эту покупку.",
    ["Auction part done. Merchant items left: %d."] = "С аукциона всё куплено. Осталось у торговца: %d шт.",
    ["Nothing left to buy on the auction house."] = "На аукционе больше покупать нечего.",
    ["Press Search: fresh lots of the next item, then buy it step by step."] =
        "Нажми «Искать»: свежие лоты следующего предмета, дальше покупка по шагам.",
    ["Search"] = "Искать",
    ["Skip item"] = "Пропустить",
    ["Clear"] = "Очистить",
    ["Item"] = "Предмет",
    ["AH (up to, each) / merchant"] = "Аукцион (до, за шт.) / торговец",
    ["Right-click: remove from the list"] = "Правый клик: убрать из списка",
    ["Empty: press To shopping list on the Buy plan panel."] = "Пусто: нажми «В список покупок» на панели плана.",
    ["Bought %d x %s for %s."] = "Куплено %d x %s за %s.",
    ["This merchant sells nothing from the list."] = "Этот торговец не продаёт ничего из списка.",
    ["Bought from the merchant for about %s."] = "Куплено у торговца примерно на %s.",
    ["Buy from list: %d (%s)"] = "Купить по списку: %d шт. (%s)",
    ["Buy from list: nothing here"] = "Купить по списку: здесь нечего",
    ["Buy from list"] = "Купить по списку",
    -- v0.5: history
    ["History by day"] = "История по дням",
    ["History by day..."] = "История по дням...",
    ["  /km history [reset] - what you spent and earned by day (reset: clear it)"] =
        "  /km history [reset] - сколько потрачено и заработано по дням (reset: очистить)",
    ["History cleared: counting from now."] = "История очищена: считаю с этого момента.",
    ["The history is off (see /km status)."] = "История выключена (см. /km status).",
    ["Day"] = "День",
    ["Spent"] = "Потрачено",
    ["Merchants paid"] = "От торговцев",
    ["Result"] = "Итог",
    ["Crafts"] = "Крафты",
    ["Best recipe"] = "Лучший рецепт",
    ["today"] = "сегодня",
    ["yesterday"] = "вчера",
    ["No days recorded yet."] = "Дней ещё не записано.",
    ["7 days: spent %s, merchants paid %s, result %s, crafts %d"] =
        "7 дней: потрачено %s, торговцы заплатили %s, итог %s, крафтов %d",
    ["30 days: spent %s, merchants paid %s, result %s, crafts %d"] =
        "30 дней: потрачено %s, торговцы заплатили %s, итог %s, крафтов %d",
    ["Auction sales (by mail) are not counted yet."] = "Продажи на аукционе (через почту) пока не учитываются.",
    ["Merchants (bought)"] = "Торговцы (покупки)",
    ["%s: %d crafts"] = "%s: %d крафтов",
    [" (no price: %d)"] = " (без цены: %d)",
    ["At a loss: %d"] = "В минус: %d",
    ["No price: %d"] = "Без цены: %d",
    ["Turn off \"Only profitable\" to see them; hover a recipe for the reason."] =
        "Выключи «Только выгодные», чтобы их увидеть; причина в подсказке рецепта.",
    ["Profession overview..."] = "Обзор профессий...",
    ["  /km explore - profession overview: every profession's recipes by profit per hour"] =
        "  /km explore - обзор профессий: рецепты всех профессий по прибыли в час",
    ["The overview is off (see /km status)."] = "Обзор выключен (см. /km status).",
    ["Naowh's recipe data was not found."] = "База рецептов Naowh не найдена.",
    ["Recount"] = "Пересчитать",
    ["Recipe"] = "Рецепт",
    ["Skill"] = "Навык",
    ["Learn"] = "Изучение",
    ["Per craft"] = "За крафт",
    ["Sold/day"] = "Прод./день",
    ["Sell"] = "Куда",
    ["AH"] = "Аук",
    ["Trainer"] = "Тренер",
    ["Drop"] = "Добыча",
    ["Quest"] = "Задание",
    ["Makes no item"] = "Не создаёт предмет",
    ["Makes: %s x%s"] = "Создаёт: %s x%s",
    ["Skill %d (yellow %s, grey %s)"] = "Навык %d (жёлтый %s, серый %s)",
    ["Time per craft"] = "Время крафта",
    ["TSM region sells per day"] = "TSM: продаж в день по региону",
    ["Learn: "] = "Изучение: ",
    ["Recipe item on the AH: %s"] = "Рецепт на аукционе: %s",
    ["Shift-click: link the item in chat"] = "Shift+клик: ссылка на предмет в чат",
    ["Best per hour: %s (skill %d), %s"] = "Лучший в час: %s (навык %d), %s",
    ["Profitable recipes: %d of %d"] = "Выгодных рецептов: %d из %d",
    ["up to %s/h"] = "до %s/ч",
    ["(%d profitable)"] = "(выгодных %d)",
    ["counting..."] = "считаю...",
    ["nothing profitable"] = "ничего выгодного",
    ["Only profitable: "] = "Только выгодные: ",
    ["Only selling (1+/day): "] = "Только продаваемые (1+/день): ",
    ["yes"] = "да",
    ["no"] = "нет",
    ["Shown %d-%d of %d"] = "Показано %d-%d из %d",
    ["Counting %d of %d... "] = "Считаю %d из %d... ",
    ["%sg"] = "%sз",
    ["%ds"] = "%dс",
    ["%dc"] = "%dм",
    -- v0.4: bag space
    ["not enough bag space"] = "не хватает места в сумках",
    ["Bags: needs %d slots (purchases %d, results %d), %d free"] = "Сумки: нужно %d ячеек (покупки %d, результат %d), свободно %d",
    ["With more bag space: %d crafts, profit %s, needs %d slots"] = "Будь места больше: %d крафтов, прибыль %s, нужно ячеек %d",
    ["Fit in free bag slots"] = "Учитывать место в сумках",
    ["BAGS_HELP"] = "План не берёт больше, чем помещается в свободные ячейки обычных сумок: новые стопки покупок и стопки "
        .. "результата (сапоги и т. п. не складываются: 1 штука = 1 ячейка). Сумки профессий и сумка реагентов не считаются.",
    ["  /km bags - plan fits in free bag slots on/off"] = "  /km bags - учитывать свободное место в сумках вкл/выкл",
    ["Bag space limit %s (%s free slots)."] = "Учёт места в сумках: %s (свободно ячеек: %s).",
    ["Nothing to buy: everything is in your bags or crafted."] = "Покупать нечего: всё есть в сумках или крафтится.",
    ["Shopping list: added %s."] = "Список покупок: добавлено %s.",
    ["craft is cheaper, but buying gives more gold per hour"] = "крафт дешевле, но покупка даёт больше золота в час",
    ["buying is cheaper"] = "покупать дешевле",
    ["yourself: %s each + %s s (%s)"] = "самому: %s за шт. + %s с (%s)",
    -- v0.4: intermediate reagents
    ["your craft"] = "свой крафт",
    ["craft %d yourself (%d crafts)"] = "скрафтить самому %d шт. (%d крафтов)",
    ["craft %d"] = "крафт %d",
    [", buying: %s each"] = ", покупка: %s за шт.",
    ["Of the time, crafting intermediates: %s"] = "Из этого времени крафт промежуточных: %s",
    ["  /km inter hour|cheap|off - craft intermediate reagents yourself"] =
        "  /km inter hour|cheap|off - крафтить промежуточные реагенты самому",
    ["Intermediate reagents: %s."] = "Промежуточные реагенты: %s.",
    ["Intermediate reagents"] = "Промежуточные реагенты",
    ["Craft if it raises gold per hour"] = "Крафтить, если растёт золото в час",
    ["Craft if it is cheaper"] = "Крафтить, если дешевле",
    ["Always buy"] = "Всегда покупать",
    ["craft if it raises gold per hour"] = "крафтить, если растёт золото в час",
    ["craft if it is cheaper"] = "крафтить, если дешевле",
    ["always buy"] = "всегда покупать",
    ["INTER_HELP"] = "Промежуточный реагент: тот, что ты можешь сделать сам этой профессией (например, обработанная шкура). "
        .. "«Золото в час»: крафтить, только если сэкономленные деньги за секунду его крафта больше, чем основной крафт "
        .. "приносит в секунду при покупке всего. Сначала покупаются дешёвые лоты, крафт начинается, когда лоты дорожают. "
        .. "«Дешевле»: крафтить всегда, когда реагенты дешевле. Учитывается один уровень.",
    -- v0.4: ledger
    ["  /km ledger [reset] - what you really spent and earned (reset: start counting again)"] =
        "  /km ledger [reset] - сколько реально потрачено и заработано (reset: начать счёт заново)",
    ["The ledger is off (see /km status)."] = "Учёт выключен (см. /km status).",
    ["Ledger reset: counting from now."] = "Учёт сброшен: считаю с этого момента.",
    ["Ledger since %s (%s ago):"] = "Учёт с %s (%s назад):",
    ["  Spent: auction %s, merchant %s. Merchants paid %s. Money: %s"] =
        "  Потрачено: аукцион %s, торговцы %s. Торговцы заплатили %s. Итог по деньгам: %s",
    ["  %s: crafted %d, sold %d for %s, reagents %s%s, result %s"] =
        "  %s: скрафчено %d, продано %d шт. за %s, реагенты %s%s, итог %s",
    ["  No crafts recorded yet."] = "  Крафтов пока не записано.",
    ["  Not counted: auction sales (mail), deposits, repairs. ~ = some reagents at market price (none bought)."] =
        "  Не учитываются: продажи на аукционе (почта), депозиты, ремонт. ~ = часть реагентов по рыночной цене (их не покупали).",
    ["Real: crafted %d, sold %d for %s, reagents %s%s, result "] =
        "Факт: скрафчено %d, продано %d шт. за %s, реагенты %s%s, итог ",
    ["Profit per hour of crafting"] = "Прибыль в час крафта",
    ["HOUR_HELP"] = "Прибыль плана, делённая на время его крафта (каст + 0,3 с между крафтами). "
        .. "Невыгодные рецепты внизу. Беготня и покупка не учитываются.",
    ["Time: %s"] = "Время: %s",
    ["%s per hour"] = "%s в час",
}

-- Long help texts are looked up by key; English text for those keys.
local EN = {
    CHEF_HELP = "Each rank: +10% chance that a cooking craft gives one more item (a recipe making 2 gives 3). "
        .. "On: yield and profit use the average with these extra results. Off: only the base result.",
    DEMAND_HELP = "TSM region sold per day (all Forever realms of the region), times the days set with "
        .. "/km demand. Merchant sales have no limit.",
    BUDGET_HELP = "The plan spends no more than this on auction and merchant purchases "
        .. "(reagents in your bags cost no money). \"Gold on the character\" follows your money.",
    SELL_HELP = "Yes: this recipe's result goes on the sell list. Under the merchant window a \"Sell crafts\" "
        .. "button then sells all such items in your bags with one click. Nothing else is touched.",
    INTER_HELP = "An intermediate reagent is one you can make yourself with this profession (e.g. cured hide). "
        .. "\"Gold per hour\": craft it only when the money it saves per second of its crafting beats what the main "
        .. "recipe earns per second when everything is bought. Cheap lots are bought first; crafting starts once lots "
        .. "get dearer. \"Cheaper\": craft whenever its reagents cost less. One level deep.",
    BAGS_HELP = "The plan takes no more than fits in the free slots of your ordinary bags: the new stacks of purchases "
        .. "and the stacks of the result (boots and such do not stack: 1 item = 1 slot). Profession and reagent bags are not counted.",
    ATAH_HELP = "On: the \"Per hour\"/\"Plan\" sort and the column follow bags and money only while the auction "
        .. "house or a merchant is open; otherwise they keep their last values (less load). The selected recipe's "
        .. "panel is always counted. New prices and settings count everything again at once.",
    FIT_HELP = "Naowh's buttons and tabs are sized for English. A label that does not fit gets a smaller font "
        .. "(down to 70%) until it fits. Naowh's files are not changed. Takes full effect after /reload.",
    FEED_HELP = "Naowh's full scan waits 60 seconds for the auction house; a slow server sends the listings longer. "
        .. "KisMax reads them to the end and, if Naowh did not keep this scan, writes the lowest unit price of every "
        .. "item into Naowh's prices. Naowh's files are not changed, only its saved prices.",
    HOUR_HELP = "The plan's profit divided by its crafting time (cast + 0.3 s between crafts). "
        .. "Unprofitable recipes go last. Running around and buying are not counted.",
    DEPTH_HELP = "Our scan's price is the one below which this share of all listed units sits: "
        .. "a few cheap units no longer set the price.",
}

local useRU = false

function NPP.UpdateLanguage()
    local lang = NPP.db and NPP.db.lang or "auto"
    if lang == "auto" then
        useRU = GetLocale() == "ruRU"
    else
        useRU = lang == "ru"
    end
end

function NPP.L(text)
    if useRU and RU[text] then return RU[text] end
    return EN[text] or text
end

NPP.UpdateLanguage()
