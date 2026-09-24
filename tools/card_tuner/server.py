"""カード調整画面のローカルサーバー。

全カードの数値(コスト・総量・効果の値・条件の総量)と効果文をブラウザで直して
data/cards/{id}.tres と docs/Hourglasses.md の該当行へ書き戻し、
tools/balance/run_v5_card_check.gd を裏で回して勝率を測る。

使い方:
    python tools/card_tuner/server.py        # http://127.0.0.1:8790/ を開く

トリガー・対象・効果の種類・キーワードは表示だけで、書き換えない
(構造を変える調整は CPU の評価や実演のコードにも手が要るため、仕様変更フローで扱う)。
"""

import json
import os
import re
import subprocess
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CARDS_DIR = ROOT / "data" / "cards"
ENUMS_PATH = ROOT / "scripts" / "data" / "card_enums.gd"
HOURGLASSES_PATH = ROOT / "docs" / "Hourglasses.md"
INDEX_PATH = Path(__file__).resolve().parent / "index.html"
GODOT = os.environ.get("GODOT", r"C:\Users\omezi\Documents\Godot_v4.6.2-stable_win64_console.exe")
PORT = int(os.environ.get("PORT", "8790"))
CHECK_SCRIPT = "res://tools/balance/run_v5_card_check.gd"
STALE_WINRATE = "再測定待ち"
# ヘッドレス終了時に毎回出るリーク警告。測定結果とは関係しない
NOISE_RE = re.compile(r"^Godot Engine|leaked at exit|still in use at exit|^\s+at: |^$")

STRING_RE = r'"((?:[^"\\]|\\.)*)"'
EFFECT_INT_FIELDS = {
    "trigger": 0,
    "target": 4,
    "effect_type": 0,
    "value": 0,
    "keyword": -1,
    "condition_scope": 0,
    "condition_total": -1,
}
EDITABLE_EFFECT_FIELDS = ("value", "condition_total")

_jobs: dict = {}
_file_lock = threading.Lock()


# ---------- .tres ----------


def _unescape(text: str) -> str:
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), text)


def _escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"')


def _split_sections(text: str) -> list:
    """[header] ごとに区切る。先頭の [gd_resource] も1区画として残す。"""
    parts = re.split(r"(?m)^(?=\[)", text)
    return [p for p in parts if p]


def _int_field(body: str, key: str, default: int) -> int:
    m = re.search(rf"(?m)^{key} = (-?\d+)\s*$", body)
    return int(m.group(1)) if m else default


def _bool_field(body: str, key: str) -> bool:
    return re.search(rf"(?m)^{key} = true\s*$", body) is not None


def _str_field(body: str, key: str) -> str:
    m = re.search(rf"(?ms)^{key} = {STRING_RE}", body)
    return _unescape(m.group(1)) if m else ""


def _set_int_field(body: str, key: str, value: int) -> str:
    pattern = rf"(?m)^{key} = -?\d+[ \t]*$"
    if re.search(pattern, body):
        return re.sub(pattern, f"{key} = {value}", body, count=1)
    return body.rstrip("\n") + f"\n{key} = {value}\n\n"


def _set_str_field(body: str, key: str, value: str) -> str:
    pattern = rf"(?ms)^{key} = {STRING_RE}"
    replacement = f'{key} = "{_escape(value)}"'
    return re.sub(pattern, lambda _m: replacement, body, count=1)


def _effect_ids(resource_body: str) -> list:
    m = re.search(r"(?m)^effects = .*$", resource_body)
    return re.findall(r'SubResource\("([^"]+)"\)', m.group(0)) if m else []


def _read_card(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    sub_bodies = {}
    resource_body = ""
    for section in _split_sections(text):
        header = section.split("\n", 1)[0]
        m = re.match(r'\[sub_resource [^\]]*id="([^"]+)"', header)
        if m:
            sub_bodies[m.group(1)] = section
        elif header.startswith("[resource]"):
            resource_body = section
    effects = []
    for sub_id in _effect_ids(resource_body):
        body = sub_bodies.get(sub_id, "")
        effect = {k: _int_field(body, k, d) for k, d in EFFECT_INT_FIELDS.items()}
        effect["card_id"] = _str_field(body, "card_id")
        effect["sub_id"] = sub_id
        effects.append(effect)
    keywords_m = re.search(r"(?m)^keywords = Array\[int\]\(\[(.*)\]\)", resource_body)
    keywords = [int(v) for v in re.findall(r"-?\d+", keywords_m.group(1))] if keywords_m else []
    return {
        "id": _str_field(resource_body, "id"),
        "display_name": _str_field(resource_body, "display_name"),
        "cost": _int_field(resource_body, "cost", 0),
        "total_sand": _int_field(resource_body, "total_sand", 0),
        "pool_index": _int_field(resource_body, "pool_index", 0),
        "set_id": _str_field(resource_body, "set_id"),
        "keywords": keywords,
        "conditional_keyword": _int_field(resource_body, "conditional_keyword", -1),
        "conditional_keyword_total": _int_field(resource_body, "conditional_keyword_total", -1),
        "rules_text": _str_field(resource_body, "rules_text"),
        "cannot_attack": _bool_field(resource_body, "cannot_attack"),
        "cannot_flip": _bool_field(resource_body, "cannot_flip"),
        "is_token": _bool_field(resource_body, "is_token"),
        "is_spell": _bool_field(resource_body, "is_spell"),
        "effects": effects,
    }


def _write_card(path: Path, changes: dict) -> None:
    text = path.read_text(encoding="utf-8")
    sections = _split_sections(text)
    effect_changes = {e["sub_id"]: e for e in changes.get("effects", [])}
    out = []
    for section in sections:
        header = section.split("\n", 1)[0]
        m = re.match(r'\[sub_resource [^\]]*id="([^"]+)"', header)
        if m and m.group(1) in effect_changes:
            for key in EDITABLE_EFFECT_FIELDS:
                if key in effect_changes[m.group(1)]:
                    section = _set_int_field(section, key, int(effect_changes[m.group(1)][key]))
        elif header.startswith("[resource]"):
            for key in ("cost", "total_sand"):
                if key in changes:
                    section = _set_int_field(section, key, int(changes[key]))
            if "rules_text" in changes:
                section = _set_str_field(section, "rules_text", changes["rules_text"])
        out.append(section)
    path.write_text("".join(out), encoding="utf-8", newline="\n")


def _card_path(card_id: str) -> Path:
    if not re.fullmatch(r"[a-z0-9_]+", card_id):
        raise ValueError("bad card id")
    path = CARDS_DIR / f"{card_id}.tres"
    if not path.exists():
        raise FileNotFoundError(card_id)
    return path


# ---------- CardEnums ----------


def _read_enums() -> dict:
    text = ENUMS_PATH.read_text(encoding="utf-8")
    names = {}
    for func, enum in (("keyword_name", "Keyword"), ("trigger_name", "Trigger")):
        body = re.search(rf"static func {func}\(.*?\n(.*?)\n\n", text, re.S)
        if body:
            names[enum] = dict(re.findall(rf'{enum}\.(\w+):\s*\n\s*return "([^"]*)"', body.group(1)))
    enums = {}
    for m in re.finditer(r"(?ms)^enum (\w+) \{\n(.*?)^\}", text):
        values = []
        comment = []
        for line in m.group(2).splitlines():
            line = line.strip()
            if line.startswith("##"):
                comment.append(line.lstrip("#").strip())
            elif re.fullmatch(r"\w+,?", line):
                ident = line.rstrip(",")
                desc = " ".join(comment)
                short = names.get(m.group(1), {}).get(ident) or re.split(r"[。:(]", desc)[0][:16]
                values.append({"name": ident, "label": short, "desc": desc})
                comment = []
        enums[m.group(1)] = values
    return enums


# ---------- Hourglasses.md ----------


def _cells(line: str) -> list:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def _read_winrates() -> dict:
    rates = {}
    header = []
    for line in HOURGLASSES_PATH.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            header = []
            continue
        cells = _cells(line)
        if "id" in cells and not header:
            header = cells
            continue
        if header and len(cells) == len(header) and "勝率" in header:
            if cells[0] != "---":
                rates.setdefault(cells[header.index("id")], cells[header.index("勝率")])
    return rates


def _update_hourglasses(card_id: str, before: dict, changes: dict, winrate: str | None) -> bool:
    lines = HOURGLASSES_PATH.read_text(encoding="utf-8").split("\n")
    header = []
    touched = False
    numbers_changed = (
        any(changes.get(k, before[k]) != before[k] for k in ("cost", "total_sand"))
        or any(
            e.get(key, orig[key]) != orig[key]
            for e, orig in zip(changes.get("effects", []), before["effects"])
            for key in EDITABLE_EFFECT_FIELDS
        )
    )
    for i, line in enumerate(lines):
        if not line.startswith("|"):
            header = []
            continue
        cells = _cells(line)
        if "id" in cells and not header:
            header = cells
            continue
        if not header or len(cells) != len(header) or cells[header.index("id")] != card_id:
            continue
        for column, key in (("コスト", "cost"), ("総量", "total_sand")):
            if column in header and key in changes:
                cells[header.index(column)] = str(changes[key])
        new_text = changes.get("rules_text")
        if new_text is not None and before["rules_text"]:
            for j, cell in enumerate(cells):
                if "効果" in header[j] and before["rules_text"] in cell:
                    cells[j] = cell.replace(before["rules_text"], new_text)
        if "勝率" in header:
            if winrate is not None:
                cells[header.index("勝率")] = winrate
            elif numbers_changed:
                cells[header.index("勝率")] = STALE_WINRATE
        lines[i] = "| " + " | ".join(cells) + " |"
        touched = True
    if touched:
        HOURGLASSES_PATH.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return touched


def _docs_mentioning(name: str) -> list:
    hits = []
    for path in sorted((ROOT / "docs").rglob("*.md")):
        if path == HOURGLASSES_PATH:
            continue
        if name and name in path.read_text(encoding="utf-8"):
            hits.append(str(path.relative_to(ROOT)).replace("\\", "/"))
    return hits


def _modified_cards() -> list:
    result = subprocess.run(
        ["git", "status", "--porcelain", "--", "data/cards"],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
    )
    return [Path(line[3:]).stem for line in result.stdout.splitlines() if line.endswith(".tres")]


# ---------- 測定 ----------


def _start_measure(card_id: str, params: dict) -> str:
    args = [f"focus={card_id}", f"games={int(params.get('games', 400))}", f"seed={int(params.get('seed', 42))}"]
    for key in ("sweep", "totals", "values"):
        value = str(params.get(key, "")).replace(" ", "")
        if value:
            if not re.fullmatch(r"-?\d+(,-?\d+)*", value):
                raise ValueError(f"{key} は数字をカンマで区切って書く")
            args.append(f"{key}={value}")
    if params.get("values"):
        args.append(f"effect={int(params.get('effect', 0))}")
    job_id = uuid.uuid4().hex[:8]
    job = {"card_id": card_id, "args": args, "lines": [], "done": False, "results": []}
    _jobs[job_id] = job

    def run() -> None:
        proc = subprocess.Popen(
            [GODOT, "--headless", "--path", str(ROOT), "--script", CHECK_SCRIPT, "--", *args],
            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace",
        )
        for line in proc.stdout:
            line = line.rstrip()
            if not NOISE_RE.search(line):
                job["lines"].append(line)
            m = re.search(r"コスト (-?\d+) / 総量 (-?\d+)(?: / 効果(\d+) の値 (-?\d+))? -> 勝率 ([\d.]+)%", line)
            if m:
                job["results"].append({
                    "cost": int(m.group(1)),
                    "total_sand": int(m.group(2)),
                    "effect": int(m.group(3)) if m.group(3) else None,
                    "value": int(m.group(4)) if m.group(4) else None,
                    "winrate": float(m.group(5)),
                })
        proc.wait()
        job["done"] = True
        job["exit_code"] = proc.returncode

    threading.Thread(target=run, daemon=True).start()
    return job_id


# ---------- HTTP ----------


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def _send(self, status: int, body, content_type="application/json; charset=utf-8") -> None:
        data = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        return json.loads(self.rfile.read(length) or b"{}")

    def do_GET(self):
        try:
            if self.path in ("/", "/index.html"):
                self._send(200, INDEX_PATH.read_bytes(), "text/html; charset=utf-8")
            elif self.path == "/api/cards":
                cards = [_read_card(p) for p in sorted(CARDS_DIR.glob("*.tres"))]
                self._send(200, {
                    "cards": cards,
                    "enums": _read_enums(),
                    "winrates": _read_winrates(),
                    "modified": _modified_cards(),
                })
            elif self.path.startswith("/api/jobs/"):
                job = _jobs.get(self.path.rsplit("/", 1)[1])
                self._send(200 if job else 404, job or {"error": "no such job"})
            else:
                self._send(404, {"error": "not found"})
        except Exception as e:  # noqa: BLE001 ローカル専用ツールのため、原因をそのまま画面へ返す
            self._send(500, {"error": str(e)})

    def do_POST(self):
        try:
            m = re.fullmatch(r"/api/(save|measure)/([a-z0-9_]+)", self.path)
            if not m:
                self._send(404, {"error": "not found"})
                return
            action, card_id = m.groups()
            path = _card_path(card_id)
            body = self._body()
            if action == "measure":
                self._send(200, {"job": _start_measure(card_id, body)})
                return
            with _file_lock:
                before = _read_card(path)
                _write_card(path, body)
                in_table = _update_hourglasses(card_id, before, body, body.get("winrate"))
                after = _read_card(path)
            self._send(200, {
                "card": after,
                "hourglasses_updated": in_table,
                "docs_mentioning": _docs_mentioning(after["display_name"]),
            })
        except Exception as e:  # noqa: BLE001
            self._send(400, {"error": str(e)})


def main() -> None:
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"カード調整画面: http://127.0.0.1:{PORT}/")
    server.serve_forever()


if __name__ == "__main__":
    main()
