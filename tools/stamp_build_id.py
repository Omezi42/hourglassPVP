"""project.godot の config/build_id と config/version を書き出し時刻で上書きする。

バージョンが違う相手とマッチングしないための「ビルドID」と、人が読む日付方式の
バージョン(GameDesign.md 11章・Architecture.md 6.4節)。`tools/export_web.sh` が
書き出しの直前に1度だけ呼ぶ。手で更新する値を増やさないための自動化であり、
**書き込んだ値はそのままコミットする**(直近のビルドがどれかを追えるようにするため)。

**バージョンも自動で書く。**以前は `config/version` だけが手で更新する値として
残っており、実際に書き出しを重ねても日付が古いままで、Discordの募集通知に
何日も同じ数字が出ていた。同じ日に2回以上書き出した場合は `-2` `-3` と後ろへ足す
(GameDesign.md 11章の日付方式)。
"""

import io
import re
import sys

BUILD_ID = re.compile(r'^config/build_id=".*"$', re.M)
VERSION = re.compile(r'^config/version="(.*)"$', re.M)


def next_version(current: str, date: str) -> str:
    """同じ日に書き出し直した場合だけ連番を進める。"""
    if current == date:
        return date + "-2"
    if current.startswith(date + "-"):
        suffix = current[len(date) + 1 :]
        if suffix.isdigit():
            return "%s-%d" % (date, int(suffix) + 1)
    return date


def main() -> int:
    path, build_id = sys.argv[1], sys.argv[2]
    text = io.open(path, encoding="utf-8").read()

    text, count = BUILD_ID.subn('config/build_id="%s"' % build_id, text, count=1)
    if count != 1:
        sys.stderr.write("project.godot に config/build_id が見つからない\n")
        return 1

    found = VERSION.search(text)
    if found is None:
        sys.stderr.write("project.godot に config/version が見つからない\n")
        return 1
    # ビルドIDは "YYYYMMDD-HHMMSS"。日付だけを取り出して "YYYY.MM.DD" にする。
    day = build_id.split("-")[0]
    date = "%s.%s.%s" % (day[0:4], day[4:6], day[6:8])
    version = next_version(found.group(1), date)
    text = VERSION.sub('config/version="%s"' % version, text, count=1)

    io.open(path, "w", encoding="utf-8", newline="").write(text)
    sys.stdout.write("version = %s\n" % version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
