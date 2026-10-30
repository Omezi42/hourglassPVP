class_name AnnouncementText
extends RefCounted
## #お知らせ の文面(Discordの書き方)を `RichTextLabel` のBBCodeへ変える(GameDesign.md 33章)。
## `**見出し**` だけの行は見出し、`- ` で始まる行は行頭の点、`-# ` の行(リンクの1行)は落とす。

const HEADING_MARK := "**"
const ITEM_PREFIX := "- "
const SMALL_PREFIX := "-# "
const BULLET := "・"


static func to_bbcode(body: String, heading_size: int, heading_color: Color) -> String:
	var lines: Array[String] = []
	for raw in body.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with(SMALL_PREFIX):
			continue
		if _is_heading(line):
			if not lines.is_empty():
				lines.append("")
			lines.append(
				(
					"[font_size=%d][color=#%s]%s[/color][/font_size]"
					% [heading_size, heading_color.to_html(false), _escape(_inner(line))]
				)
			)
		elif line.begins_with(ITEM_PREFIX):
			lines.append(
				"[indent]%s%s[/indent]" % [BULLET, _escape(line.substr(ITEM_PREFIX.length()))]
			)
		elif not line.is_empty():
			lines.append(_escape(line))
	return "\n".join(lines).strip_edges()


static func _is_heading(line: String) -> bool:
	return (
		line.length() > HEADING_MARK.length() * 2
		and line.begins_with(HEADING_MARK)
		and line.ends_with(HEADING_MARK)
	)


static func _inner(line: String) -> String:
	return line.substr(HEADING_MARK.length(), line.length() - HEADING_MARK.length() * 2)


## 本文中の `[` がBBCodeのタグとして読まれないようにし、太字の印は外す。
static func _escape(text: String) -> String:
	return text.replace("[", "[lb]").replace(HEADING_MARK, "")
