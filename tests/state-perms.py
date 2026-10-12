#!/usr/bin/env python3
"""Posse state stays owner-only (directories 0700, files 0600) under any umask.

Creates a throwaway HOME, forces umask 000, and checks the writes in
bin/drops-watch plus the directory and lock created by bin/posse-setup.
A watcher thread fails the run if any posse file is ever group- or
world-accessible, including while a write is in progress.
"""
import importlib.machinery
import importlib.util
import os
import sqlite3
import stat
import subprocess
import sys
import tempfile
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
failures = []


def check(cond, message):
    if not cond:
        failures.append(message)


def mode_of(path):
    return os.lstat(path).st_mode & 0o777


def load_drops(home):
    os.environ["HOME"] = home
    path = os.path.join(ROOT, "bin", "drops-watch")
    # No .py suffix, so spec_from_file_location will not pick a loader on its own.
    loader = importlib.machinery.SourceFileLoader("drops_watch_perms", path)
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def watch(paths, temps, stop, bad):
    """Flag any posse path that is ever group- or world-accessible."""
    while not stop.is_set():
        for root in list(paths) + list(temps):
            if not root or not os.path.exists(root):
                continue
            try:
                st = os.lstat(root)
            except OSError:
                continue
            if not stat.S_ISLNK(st.st_mode) and (st.st_mode & 0o077):
                bad.append("%s is %s" % (root, oct(st.st_mode & 0o777)))
            for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
                for name in dirnames + filenames:
                    path = os.path.join(dirpath, name)
                    try:
                        st = os.lstat(path)
                    except OSError:
                        continue
                    if stat.S_ISLNK(st.st_mode):
                        continue
                    perm = st.st_mode & 0o777
                    if perm & 0o077:
                        bad.append("%s is %s" % (path, oct(perm)))


def test_drops(home):
    mod = load_drops(home)
    state = mod.STATE_DIR
    loose = os.path.join(state, "avatars")
    os.makedirs(loose, mode=0o777)
    os.chmod(os.path.dirname(state), 0o755)
    os.chmod(state, 0o755)
    os.chmod(loose, 0o755)
    ident = os.path.join(state, "identity.json")
    with open(ident, "w") as handle:
        handle.write('{"muse": {"name": "Secret", "avatar": ""}}\n')
    os.chmod(ident, 0o644)
    pic = os.path.join(loose, "old.png")
    with open(pic, "wb") as handle:
        handle.write(b"png")
    os.chmod(pic, 0o644)
    lock = os.path.join(state, "setup.lock")
    with open(lock, "w") as handle:
        handle.write("")
    os.chmod(lock, 0o644)
    leftover = os.path.join(loose, ".posse-crash.part")
    with open(leftover, "wb") as handle:
        handle.write(b"partial")
    os.chmod(leftover, 0o644)

    mod.tighten_state()
    check(mode_of(leftover) == 0o600, "leftover .part %s" % oct(mode_of(leftover)))
    check(mode_of(state) == 0o700, "tighten: state dir %s" % oct(mode_of(state)))
    check(mode_of(loose) == 0o700, "tighten: avatars dir %s" % oct(mode_of(loose)))
    check(mode_of(ident) == 0o600, "tighten: identity.json %s" % oct(mode_of(ident)))
    check(mode_of(pic) == 0o600, "tighten: old avatar %s" % oct(mode_of(pic)))
    check(mode_of(lock) == 0o600, "tighten: setup.lock %s" % oct(mode_of(lock)))
    with open(ident) as handle:
        check("Secret" in handle.read(), "tighten rewrote identity.json")

    stop = threading.Event()
    bad = []
    temps = []
    thread = threading.Thread(target=watch, args=({state}, temps, stop, bad))
    thread.start()
    try:
        mod.identity["muse"]["name"] = "Felipe"
        mod.identity["muse"]["avatar"] = os.path.join(loose, "muse-persona.png")
        for _ in range(30):
            mod.save_identity()
            mod.atomic_write(os.path.join(loose, "v1.png"), lambda handle: handle.write(b"\x89PNG"))
        check(mode_of(mod.IDENTITY) == 0o600, "identity.json %s" % oct(mode_of(mod.IDENTITY)))
        check(mode_of(os.path.join(loose, "v1.png")) == 0o600, "avatar write %s" % oct(mode_of(os.path.join(loose, "v1.png"))))
        with open(mod.IDENTITY) as handle:
            check("Felipe" in handle.read(), "identity.json lost the name")

        blob = os.path.join(home, "avatars.blob")
        with open(blob, "w") as handle:
            handle.write('{"value":{"entries":[{"id":"bot1","version":"ver1",'
                         '"dataUrl":"data:image/png;base64,aGVsbG8="}]}}')
        mod._avatars = (None, {})
        got = mod.avatars({"roster.agent-avatars": (blob, 1)})
        dest = got.get("bot1")
        check(bool(dest) and os.path.isfile(dest), "avatars() did not write a picture")
        if dest:
            check(mode_of(dest) == 0o600, "decoded avatar %s" % oct(mode_of(dest)))
            check(mode_of(mod.CACHE) == 0o700, "cache dir %s" % oct(mode_of(mod.CACHE)))

        prof = os.path.join(home, ".config", "BraveSoftware", "Brave-Browser", "Default")
        os.makedirs(prof, mode=0o755)
        hist = os.path.join(prof, "History")
        con = sqlite3.connect(hist)
        con.execute("PRAGMA journal_mode=WAL")
        con.execute("create table urls (url text, title text, last_visit_time integer)")
        con.execute("insert into urls values ('https://muse.ai/thread/abc', 'Chat — Felipe', 50)")
        con.commit()
        con.execute("PRAGMA wal_checkpoint(FULL)")
        fav = os.path.join(prof, "Favicons")
        favcon = sqlite3.connect(fav)
        favcon.execute("create table icon_mapping (page_url text, icon_id integer)")
        favcon.execute("create table favicons (id integer, url text)")
        favcon.execute("create table favicon_bitmaps (icon_id integer, image_data blob, last_updated integer, width integer)")
        favcon.execute("insert into favicons values (1, 'data:image/png;base64,abc')")
        favcon.execute("insert into icon_mapping values ('https://muse.ai/thread/abc', 1)")
        favcon.execute("insert into favicon_bitmaps values (1, ?, 9, 32)", (b"\x89PNG-persona",))
        favcon.commit()
        os.chmod(hist, 0o644)
        os.chmod(fav, 0o644)
        for name in os.listdir(prof):
            os.chmod(os.path.join(prof, name), 0o644)

        seen = {}
        real_copy = mod.copy_private
        real_mkdtemp = mod.tempfile.mkdtemp
        real_rmtree = mod.shutil.rmtree

        def spy_copy(src, dst):
            real_copy(src, dst)
            seen[os.path.basename(dst)] = mode_of(dst)

        def spy_mkdtemp(*args, **kwargs):
            path = real_mkdtemp(*args, **kwargs)
            temps.append(path)
            seen["tmpdir"] = mode_of(path)
            return path

        def spy_rmtree(path, **kwargs):
            if os.path.isdir(path):
                for dirpath, dirnames, filenames in os.walk(path):
                    check(mode_of(dirpath) == 0o700, "temp subdir %s %s" % (dirpath, oct(mode_of(dirpath))))
                    for name in filenames:
                        file_mode = mode_of(os.path.join(dirpath, name))
                        seen["rmtree:" + name] = file_mode
                        check(file_mode == 0o600, "temp file %s is %s" % (name, oct(file_mode)))
            real_rmtree(path, **kwargs)

        mod.copy_private = spy_copy
        mod.tempfile.mkdtemp = spy_mkdtemp
        mod.shutil.rmtree = spy_rmtree
        try:
            found = mod.from_browser()
        finally:
            favcon.close()
            con.close()
        check(seen.get("tmpdir") == 0o700, "temp dir %s" % oct(seen.get("tmpdir") or 0))
        check(seen.get("h") == 0o600, "History copy %s" % oct(seen.get("h") or 0))
        check(seen.get("f") == 0o600, "Favicons copy %s" % oct(seen.get("f") or 0))
        check(found.get("muse", ("", ""))[0] == "Felipe", "browser name %r" % (found.get("muse"),))
        persona = os.path.join(mod.CACHE, "muse-persona.png")
        check(os.path.isfile(persona), "persona picture was not saved")
        if os.path.isfile(persona):
            check(mode_of(persona) == 0o600, "persona picture %s" % oct(mode_of(persona)))
            with open(persona, "rb") as handle:
                check(handle.read() == b"\x89PNG-persona", "persona picture bytes changed")
        check(temps and all(not os.path.exists(path) for path in temps), "temp dir was left behind")
    finally:
        stop.set()
        thread.join()
    check(not bad, "world-accessible during write: %s" % "; ".join(bad[:8]))


def test_setup(home):
    state_root = os.path.join(home, "xdg-state")
    state = os.path.join(state_root, "omarchy", "posse")
    os.umask(0)
    os.makedirs(os.path.join(state, "avatars"), mode=0o777)
    os.chmod(state, 0o755)
    os.chmod(os.path.join(state, "avatars"), 0o755)
    ident = os.path.join(state, "identity.json")
    with open(ident, "w") as handle:
        handle.write('{"dots":{"name":"Sam"}}\n')
    os.chmod(ident, 0o644)
    pic = os.path.join(state, "avatars", "a.png")
    with open(pic, "wb") as handle:
        handle.write(b"pic")
    os.chmod(pic, 0o644)
    hidden = os.path.join(state, ".posse-old.part")
    with open(hidden, "wb") as handle:
        handle.write(b"partial")
    os.chmod(hidden, 0o644)

    script = os.path.join(ROOT, "bin", "posse-setup")
    probe = """
set -euo pipefail
umask 000
export HOME=%s
export XDG_STATE_HOME=%s
source %s
prepare_state
open_lock
echo REPAIRED $(stat -c '%%a' "$state") $(stat -c '%%a' "$state/identity.json") $(stat -c '%%a' "$state/avatars") $(stat -c '%%a' "$state/avatars/a.png") $(stat -c '%%a' "$state/.posse-old.part") $(stat -c '%%a' "$state/setup.lock")
echo BODY $(cat "$state/identity.json")
""" % (home, state_root, script)
    out = subprocess.run(["bash", "-c", probe], check=True, capture_output=True, text=True)
    text = out.stdout
    check('{"dots":{"name":"Sam"}}' in text, "posse-setup rewrote identity.json: %r" % text)
    repaired = [line for line in text.splitlines() if line.startswith("REPAIRED ")]
    check(len(repaired) == 1, "missing REPAIRED line: %r" % text)
    if repaired:
        parts = repaired[0].split()
        check(parts[1:] == ["700", "600", "700", "600", "600", "600"], "repaired modes %s" % parts[1:])

    # The loose tree is gone. Watch the fresh directory appear and reject any
    # mode that is group- or world-accessible, then require 0700/0600.
    subprocess.run(["rm", "-rf", state], check=True)
    stop = threading.Event()
    bad = []

    def watch_fresh():
        lock = state + "/setup.lock"
        while not stop.is_set():
            for path, kind in ((state, "dir"), (lock, "lock")):
                try:
                    st = os.lstat(path)
                except OSError:
                    continue
                if stat.S_ISLNK(st.st_mode):
                    continue
                perm = st.st_mode & 0o777
                if perm & 0o077:
                    bad.append("%s %s" % (kind, oct(perm)))

    thread = threading.Thread(target=watch_fresh)
    thread.start()
    fresh = """
set -euo pipefail
umask 000
export HOME=%s
export XDG_STATE_HOME=%s
source %s
prepare_state
open_lock
echo FRESH $(stat -c '%%a' "$state") $(stat -c '%%a' "$state/setup.lock")
""" % (home, state_root, script)
    try:
        out = subprocess.run(["bash", "-c", fresh], check=True, capture_output=True, text=True)
    finally:
        stop.set()
        thread.join()
    fresh_lines = [line for line in out.stdout.splitlines() if line.startswith("FRESH ")]
    check(len(fresh_lines) == 1 and fresh_lines[0].split()[1:] == ["700", "600"],
          "fresh modes %s" % fresh_lines)
    check(not bad, "fresh state was briefly accessible: %s" % "; ".join(bad[:8]))


def test_drop_toggle():
    text = open(os.path.join(ROOT, "bin", "drop-toggle")).read()
    check("identity.json" not in text and "mkdir" not in text and "~/.local/state" not in text,
          "drop-toggle gained a posse state write")


def main():
    old = os.umask(0)
    home = tempfile.mkdtemp(prefix="oposse-perms-home-")
    try:
        test_drops(home)
        test_setup(home)
        test_drop_toggle()
    finally:
        os.umask(old)
        subprocess.run(["chmod", "-R", "u+rwx", home], check=False)
        subprocess.run(["rm", "-rf", home], check=False)
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
