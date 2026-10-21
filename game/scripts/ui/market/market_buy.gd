class_name MarketBuy
extends Control
## The Buy tab: what to ask the server (name search, market category, sub-type, sort, page) and
## where its answer goes (the category column while a category is chosen, the table; page 1
## replaces the table's rows, a later page is appended as the list scrolls).
## Every change asks market.search again; nothing is filtered or sorted on this side.

signal loaded(res: Dictionary) ## every search response (tests and the lab read it)

var client: MarketClient
var q := ""
var category := "" ## a market category id, "" = all
var sub := "" ## a clade (animal) or an item def id within the category, "" = View All
var sort := "price_asc"
var page := 1
var page_size := 20
var requests := 0 ## market.search calls sent (the offline gate counts none)
var table: MarketTable
var column: MarketCategories
var _m := {}
var _busy := false
var _again := false ## a change arrived while a search was out: ask again with the newest args

func _ready() -> void:
	column = MarketCategories.new()
	column.name = "Categories"
	column.visible = false
	column.picked.connect(func (key: String) -> void:
		sub = key
		page = 1
		reload())
	add_child(column)
	table = MarketTable.new()
	table.name = "Table"
	table.offered = MarketFormat.sorts()
	table.sort_pressed.connect(func (col: StringName) -> void:
		sort = table.next_sort(col)
		page = 1
		reload())
	table.page_requested.connect(func (p: int) -> void:
		page = p
		reload())
	table.chip_removed.connect(func (_key: StringName) -> void: set_query(""))
	add_child(table)
	page_size = mini(20, EconRules.load_default().num("page_size_default")) # small frames (exchange-spec §10)

func start(p_client: MarketClient) -> void:
	client = p_client
	table.account = client.account
	reload()

func set_query(text: String) -> void:
	q = text
	page = 1
	table.set_chips([] if q == "" else [{"key": &"q", "text": MarketFormat.chip_text(q)}])
	reload()

func set_category(id: String) -> void:
	category = id
	sub = ""
	page = 1
	column.visible = category != ""
	if column.visible:
		var entries: Array = []
		if category == "animal":
			for c: Dictionary in MarketFormat.clades():
				entries.append({"key": "clade:" + str(c.clade), "title": c.title})
		else:
			for d: ItemDef in MarketFormat.defs_in(category):
				entries.append({"key": "def:" + str(d.id), "title": d.display_name})
		column.show_entries(MarketFormat.category_title(category), entries, "")
	if not _m.is_empty():
		layout(_m, Rect2(position, size))
	reload()

## A listing the server says is gone (bought here, or sold meanwhile) leaves the list; asking for
## the last loaded page again appends the listing that moved up into it, so nothing is skipped.
func drop(listing_id: String) -> void:
	table.remove_listing(listing_id)
	reload()

## The search the screen is showing, as market.search args (H2 filters only when the server has them).
func args() -> Dictionary:
	var a := {"sort": sort, "page": page, "page_size": page_size}
	if q != "":
		a.q = q
	if category != "" and MarketFormat.has_filter("market_category"):
		a.market_category = category
	if sub.begins_with("clade:"):
		a.clade = sub.substr(6)
	elif sub.begins_with("def:"):
		a.def_id = sub.substr(4)
	return a

func reload() -> void:
	if client == null:
		return
	if _busy:
		_again = true
		return
	_busy = true
	table.sort = sort
	requests += 1
	var res: Dictionary = await client.request("market.search", args())
	_busy = false
	if _again:
		_again = false
		reload()
		return
	if not res.get("ok", false) and page > 1: # a next page that failed keeps what is shown; scrolling asks again
		page = table.page
		table.loading = false
	elif res.get("ok", false):
		table.account = client.account # learned from wallet.get when the transport did not say
		table.empty_text = "No listings in %s yet." % column.title if category != "" else ("Nothing listed matches “%s”." % q if q != "" else "Nothing is listed on this market yet.")
		table.show_page(res.r)
	else:
		table.show_error(MarketFormat.error_text(res))
	loaded.emit(res)

func layout(m: Dictionary, rect: Rect2) -> void:
	_m = m
	position = rect.position
	size = rect.size
	var x := 0.0
	if column.visible:
		column.layout(m, Rect2(0, 0, m.cat_w, size.y))
		x = m.cat_w + m.margin
	table.layout(m, Rect2(x, 0, size.x - x, size.y))
