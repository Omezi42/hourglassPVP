"""project.godot の config/build_id を書き出し時刻で上書きする。

バージョンが違う相手とマッチングしないための「ビルドID」
(GameDesign.md 11章・Architecture.md 6.4節)。`tools/export_web.sh` が
書き出しの直前に1度だけ呼ぶ。手で更新する値を増やさないための自動化であり、
**書き込んだ値はそのままコミットする**(直近のビルドがどれかを追えるようにするため)。
"""

import io
import re
import sys

SETTING = re.compile(r'^config/build_id=".*"$', re.M)


def main() -> int:
    path, build_id = sys.argv[1], sys.argv[2]
    text = io.open(path, encoding="utf-8").read()
    text, count = SETTING.subn('config/build_id="%s"' % build_id, text, count=1)
    if count != 1:
        sys.stderr.write("project.godot に config/build_id が見つからない\n")
        return 1
    io.open(path, "w", encoding="utf-8", newline="").write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
