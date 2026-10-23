#!/usr/bin/env python3
"""Sum up a sweep's logs, or compare two sweeps handler by handler.

    python3 report.py runs/fix-main
    python3 report.py runs/fix-main --compare runs/fix-branch

One run: how many stacks imported, ran clean, timed out; the handlers
left out, grouped by the parse error (with the HyperTalk line of a few);
and for a "run" sweep the errors while running, and the handlers no
object had. Error numbers are named from engine/src/parseerrors.h and
executionerrors.h of this checkout.

--compare: the handlers each stack left out in the first run and in the
second, by name. "Newly left out" must be zero for a change to rules
that only add forms; every one is listed by stack and handler.
"""

import argparse
import base64
import collections
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.normpath(os.path.join(HERE, "..", "..", "engine", "src"))


def error_names(header, prefix):
    names = {}
    try:
        with open(os.path.join(ENGINE, header), encoding="utf-8", errors="replace") as handle:
            for line in handle:
                match = re.search(r"\{%s-(\d+)\}\s*(.*)" % prefix, line)
                if match:
                    names[int(match.group(1))] = match.group(2).strip()
    except OSError:
        pass
    return names


PARSE = error_names("parseerrors.h", "PE")
EXECUTION = error_names("executionerrors.h", "EE")


def decode(text):
    try:
        return base64.b64decode(text).decode("utf-8", "replace")
    except (ValueError, TypeError):
        return ""


def read_run(folder):
    """{stack: {...}} from the logs of one run."""
    stacks = {}
    index = {}
    for name in sorted(os.listdir(folder)):
        if not re.match(r"\d+\.txt$", name):
            continue
        stack = {"imported": False, "opened": False, "done": False, "exit": None, "left": [], "errors": []}
        with open(os.path.join(folder, name), encoding="utf-8", errors="replace") as handle:
            for line in handle:
                fields = line.rstrip("\n").split("\t")
                kind = fields[0]
                if kind == "IMPORTED":
                    stack["imported"] = True
                    stack["name"] = fields[1] if len(fields) > 1 else ""
                elif kind == "LEFT" and len(fields) >= 4:
                    stack["left"].append((fields[1], fields[2], decode(fields[3])))
                elif kind in ("ERR", "THROW") and len(fields) >= 3:
                    stack["errors"].append((decode(fields[2]), decode(fields[3]) if len(fields) > 3 else ""))
                elif kind == "OPENED":
                    stack["opened"] = True
                elif kind == "DONE":
                    stack["done"] = True
                elif kind == "EXIT":
                    stack["exit"] = fields[1] if len(fields) > 1 else ""
        stacks[name[:-4]] = stack
    return stacks


def parse_key(error):
    parts = error.split(",")
    try:
        number = int(parts[0])
    except ValueError:
        return error, ""
    return PARSE.get(number, "parse error %d" % number), ",".join(parts[3:]).lower()[:30]


def source_line(error, text):
    parts = error.split(",")
    try:
        line = int(parts[1])
    except (ValueError, IndexError):
        return ""
    lines = text.split("\n")
    return lines[line - 1].strip() if 0 < line <= len(lines) else ""


def summary(folder, limit):
    stacks = read_run(folder)
    imported = [s for s in stacks.values() if s["imported"]]
    print("stacks", len(stacks), "imported", len(imported),
          "finished", sum(s["done"] for s in stacks.values()),
          "timed out", sum(s["exit"] == "timeout" for s in stacks.values()))
    print("handlers left out", sum(len(s["left"]) for s in imported),
          "in", sum(1 for s in imported if s["left"]), "stacks")
    if any(s["opened"] for s in imported):
        print("errors while running", sum(len(s["errors"]) for s in imported),
              "in", sum(1 for s in imported if s["errors"]), "stacks;",
              "no error at all", sum(1 for s in imported if not s["errors"] and not s["left"]))

    groups = collections.defaultdict(lambda: {"stacks": set(), "count": 0, "examples": []})
    for name, stack in stacks.items():
        for handler, error, text in stack["left"]:
            group = groups[parse_key(error)]
            group["stacks"].add(name)
            group["count"] += 1
            if len(group["examples"]) < 3:
                group["examples"].append(source_line(error, text)[:110])
    print("\n== handlers left out: stacks, handlers, parse error")
    for key, group in sorted(groups.items(), key=lambda item: -len(item[1]["stacks"]))[:limit]:
        print(len(group["stacks"]), group["count"], key)
        for example in group["examples"]:
            print("      ", example)

    errors = collections.defaultdict(set)
    missing = collections.defaultdict(set)
    for name, stack in stacks.items():
        for error, source in stack["errors"]:
            first = error.split("\n")[0].split(",")
            try:
                number = int(first[0])
            except ValueError:
                continue
            errors[(EXECUTION.get(number, "error %d" % number), ",".join(first[3:]).lower()[:30])].add(name)
            for line in error.split("\n"):
                parts = line.split(",")
                if parts[0] == "573" and len(parts) > 3:
                    missing[parts[3].lower()].add(name)
                    break
    if errors:
        print("\n== errors while running: stacks, error")
        for key, names in sorted(errors.items(), key=lambda item: -len(item[1]))[:limit]:
            print(len(names), key)
        print("\n== handlers no object had: stacks, name")
        for key, names in sorted(missing.items(), key=lambda item: -len(item[1]))[:limit]:
            print(len(names), key)


def compare(first_folder, second_folder):
    first = read_run(first_folder)
    second = read_run(second_folder)
    both = [name for name in first if name in second and first[name]["imported"] and second[name]["imported"]]
    newly_left = []
    newly_saved = 0
    for name in both:
        before = collections.Counter(handler.lower() for handler, _, _ in first[name]["left"])
        after = collections.Counter(handler.lower() for handler, _, _ in second[name]["left"])
        for handler, count in (after - before).items():
            newly_left.append((name, handler, count))
        newly_saved += sum((before - after).values())
    count_first = sum(len(first[name]["left"]) for name in both)
    count_second = sum(len(second[name]["left"]) for name in both)
    print("stacks in both", len(both))
    print("handlers left out:", count_first, "then", count_second)
    print("stacks with a handler left out:", sum(1 for name in both if first[name]["left"]),
          "then", sum(1 for name in both if second[name]["left"]))
    print("newly compiling", newly_saved, "newly left out", sum(count for _, _, count in newly_left))
    for name, handler, count in newly_left:
        print("   newly left out:", name, handler, "x%d" % count if count > 1 else "")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("run")
    parser.add_argument("--compare", metavar="RUN")
    parser.add_argument("--limit", type=int, default=40)
    args = parser.parse_args()
    if args.compare:
        compare(args.run, args.compare)
    else:
        summary(args.run, args.limit)


if __name__ == "__main__":
    main()
